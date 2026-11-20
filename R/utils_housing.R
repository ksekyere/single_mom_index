# utils_housing.R
# Helpers for the housing measures of the Single Mom Index.
#   clean_hud_fmr()         reads HUD's county-level Fair Market Rent file and returns one row per county
#   add_housing_measures()  adds rent burden, housing wage and childcare-plus-rent measures
# Used by 02_clean.R and 03_build_index.R.

library(dplyr)
library(stringr)
library(readxl)

# ---- HUD Fair Market Rents ------------------------------------------------------
# HUD's county-level file has one row per county, except in New England, where Fair Market
# Rents are set for towns. The 10-digit FIPS code is state (2) + county (3) + county
# subdivision (5); outside New England the last five digits are 99999. Towns are combined
# into a county value weighted by population, so every county has one row.
# ct_xwalk (from build_ct_crosswalk() in utils_connecticut.R) assigns Connecticut towns to the
# 2022 planning regions the ACS uses, weighted by each town's 2022 population.
clean_hud_fmr <- function(path, ct_xwalk = NULL) {
  raw <- read_excel(path, sheet = 1)
  names(raw) <- tolower(str_trim(names(raw)))

  pick <- function(pattern, required = TRUE) {
    hit <- grep(pattern, names(raw), value = TRUE)
    if (length(hit) == 0) {
      if (required) stop("HUD file: no column matching '", pattern, "'. Columns are: ",
                         paste(names(raw), collapse = ", "))
      return(NA_character_)
    }
    hit[1]
  }
  fips_col <- pick("^fips")
  pop_col  <- pick("^pop", required = FALSE)
  area_col <- pick("areaname|area_name", required = FALSE)
  fmr_cols <- vapply(0:4, \(b) pick(paste0("^fmr_?", b, "$")), character(1))

  # FIPS can arrive as a number (leading zero dropped) or as text
  fips_txt <- function(x) {
    if (is.numeric(x)) sprintf("%010.0f", x) else str_pad(str_trim(as.character(x)), 10, pad = "0")
  }

  rows <- tibble(
    fips10 = fips_txt(raw[[fips_col]]),
    pop    = if (is.na(pop_col)) NA_real_ else suppressWarnings(as.numeric(raw[[pop_col]])),
    area   = if (is.na(area_col)) NA_character_ else as.character(raw[[area_col]]),
    fmr_0  = suppressWarnings(as.numeric(raw[[fmr_cols[1]]])),
    fmr_1  = suppressWarnings(as.numeric(raw[[fmr_cols[2]]])),
    fmr_2  = suppressWarnings(as.numeric(raw[[fmr_cols[3]]])),
    fmr_3  = suppressWarnings(as.numeric(raw[[fmr_cols[4]]])),
    fmr_4  = suppressWarnings(as.numeric(raw[[fmr_cols[5]]]))
  ) |>
    mutate(GEOID = str_sub(fips10, 1, 5),
           pop   = coalesce(pop, 0))

  if (!is.null(ct_xwalk)) {
    ct_map <- ct_xwalk |> transmute(fips_key = paste0("09", cousub), region, pop_2022 = pop)
    rows <- rows |>
      mutate(fips_key = paste0(str_sub(fips10, 1, 2), str_sub(fips10, 6, 10))) |>
      left_join(ct_map, by = "fips_key") |>
      mutate(GEOID = coalesce(region, GEOID),
             pop   = if_else(is.na(region), pop, pop_2022)) |>
      select(-fips_key, -region, -pop_2022)
  }

  # Population-weighted mean; plain mean if no populations are given
  wmean <- function(x, w) if (sum(w[!is.na(x)]) > 0) weighted.mean(x, w, na.rm = TRUE) else mean(x, na.rm = TRUE)

  rows |>
    group_by(GEOID) |>
    summarise(
      fmr_rows  = n(),                                   # more than 1 = New England towns combined
      fmr_areas = n_distinct(area),
      fmr_area  = paste(sort(unique(na.omit(area))), collapse = "; "),
      across(fmr_0:fmr_4, \(x) wmean(x, pop)),
      .groups = "drop"
    ) |>
    split_valdez_cordova() |>
    mutate(state_code = str_sub(GEOID, 1, 2), .after = GEOID)
}

# Alaska's Valdez-Cordova Census Area (02261) was split in 2019 into Chugach (02063) and
# Copper River (02066). If a file still uses the old area, give both new areas its values.
split_valdez_cordova <- function(df) {
  if (!"02261" %in% df$GEOID || any(c("02063", "02066") %in% df$GEOID)) return(df)
  old <- df[df$GEOID == "02261", ]
  bind_rows(df[df$GEOID != "02261", ], mutate(old, GEOID = "02063"), mutate(old, GEOID = "02066"))
}

# ---- Housing measures -------------------------------------------------------------
# Expects these columns (made in 03_build_index.R):
#   income, income_moe               median income of single-mother families with children under 18
#   annual_center_infant             annual price of infant center care
#   effective_minwage                state effective minimum wage
#   fmr_2                            HUD Fair Market Rent, 2 bedrooms (monthly)
#   median_rent_2brE / _2brM         ACS median gross rent, 2 bedrooms (monthly) and its MOE
#   owner_single_mom_kidsE/M, renter_single_mom_kidsE/M   ACS B25115
# moe_ratio() and moe_prop() come from tidycensus.
add_housing_measures <- function(df, weeks_per_year = 52, fulltime_hours = 40, affordable_share = 0.30) {
  df |>
    mutate(
      # Rent at HUD's Fair Market Rent for a 2-bedroom unit
      annual_rent_fmr2    = fmr_2 * 12,
      rent_share_fmr2     = annual_rent_fmr2 / income,
      rent_share_fmr2_moe = moe_ratio(annual_rent_fmr2, income, 0, income_moe),

      # Housing wage: hourly pay needed for 2-bedroom rent to take no more than 30% of
      # full-time, full-year earnings (the National Low Income Housing Coalition's definition)
      housing_wage_2br = annual_rent_fmr2 / affordable_share / (fulltime_hours * weeks_per_year),
      housing_wage_to_minwage = housing_wage_2br / effective_minwage,

      # Weekly hours of minimum-wage work needed to pay the rent
      hours_minwage_rent = (annual_rent_fmr2 / weeks_per_year) / effective_minwage,

      # Cross-check: ACS median gross rent for 2-bedroom units (what renters actually pay)
      annual_rent_acs2     = median_rent_2brE * 12,
      rent_share_acs2      = annual_rent_acs2 / income,
      rent_share_acs2_moe  = moe_ratio(annual_rent_acs2, income, median_rent_2brM * 12, income_moe),

      # Childcare and rent together, and what is left of income after both
      childcare_rent_share     = (annual_center_infant + annual_rent_fmr2) / income,
      childcare_rent_share_moe = moe_ratio(annual_center_infant + annual_rent_fmr2, income, 0, income_moe),
      income_left_after_childcare_rent = income - annual_center_infant - annual_rent_fmr2,

      # How many single-mother households rent
      single_mom_households_kidsE = owner_single_mom_kidsE + renter_single_mom_kidsE,
      single_mom_households_kidsM = sqrt(owner_single_mom_kidsM^2 + renter_single_mom_kidsM^2),
      renter_share_single_mom     = renter_single_mom_kidsE / single_mom_households_kidsE,
      renter_share_single_mom_moe = moe_prop(renter_single_mom_kidsE, single_mom_households_kidsE,
                                             renter_single_mom_kidsM, single_mom_households_kidsM),

      # HUD's cost-burden thresholds
      rent_burden_fmr2 = case_when(
        is.na(rent_share_fmr2)  ~ NA_character_,
        rent_share_fmr2 > 0.50  ~ "severe (over 50%)",
        rent_share_fmr2 > 0.30  ~ "burdened (30-50%)",
        TRUE                    ~ "not burdened (30% or less)"
      )
    )
}
