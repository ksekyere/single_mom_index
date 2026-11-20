# 03_build_index.R
# Join the cleaned tables and calculate baseline Single Mom Index measures by county.
# Inputs come from 02_clean.R; outputs go to output/ for charts (R, Illustrator) and maps (QGIS).
#
# Baseline measures
#   childcare_share_*      annual childcare price as a share of single-mother median income
#   hours_minwage_infant   hours of minimum-wage work needed each week to pay for infant care
#   pov_rate_single_mom    poverty rate of single-mother families with children under 18
#   share_single_mom       single-mother families with children as a share of all families
#   rent_share_fmr2        HUD 2-bedroom Fair Market Rent as a share of single-mother median income
#   housing_wage_2br       hourly wage needed to afford that rent at 30% of income
#   childcare_rent_share   infant center care plus 2-bedroom rent as a share of income
#   (rent and tenure measures are calculated in utils_housing.R)
# Margins of error are carried through wherever the inputs have them (ACS values only;
# NDCP prices are medians without published margins of error).

library(dplyr)
library(tidyr)
library(here)
library(sf)
library(tidycensus)   # moe_ratio(), moe_prop()

source(here("R", "utils_housing.R"))

proc_dir <- here("data", "processed")
out_dir  <- here("output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

acs       <- readRDS(file.path(proc_dir, "acs5_2022_single_mom_county.rds"))
childcare <- readRDS(file.path(proc_dir, "childcare_2022.rds"))
minwage   <- readRDS(file.path(proc_dir, "minwage_2022.rds"))
fmr       <- readRDS(file.path(proc_dir, "fmr_fy2022.rds"))
acs_housing <- readRDS(file.path(proc_dir, "acs5_2022_housing_county.rds"))

weeks_per_year <- 52

# Reliability: a CV divides the standard error by the estimate, so small poverty rates get
# large CVs even when the margin of error is small. The poverty-rate CV therefore divides by
# at least this rate. Below it, the test works like a cap on the margin of error itself:
# about 2.5 percentage points for "high" and 6.6 points for "medium" (0.15 and 0.40 x 0.10 x 1.645).
pov_cv_floor <- 0.10
fulltime_hours <- 40

# The measures below need these childcare columns; stop early with a clear message if any is missing
needed <- c("price_center_infant", "price_center_toddler", "price_center_preschool", "price_home_infant")
missing_cols <- setdiff(needed, names(childcare))
if (length(missing_cols) > 0) {
  stop("Missing childcare columns: ", paste(missing_cols, collapse = ", "),
       ". Check data/processed/ndcp_name_map.csv for what they were named.")
}

# ---- Join --------------------------------------------------------------------
index_base <- acs |>
  left_join(select(childcare, GEOID, starts_with("price_")), by = "GEOID") |>
  left_join(select(minwage, state, effective_minwage, no_state_minimum), by = "state") |>
  left_join(select(fmr, GEOID, fmr_0:fmr_4, fmr_area, fmr_rows), by = "GEOID") |>
  left_join(acs_housing, by = "GEOID")

# Join checks: how many counties found a match in each source?
join_report <- index_base |>
  st_drop_geometry() |>
  summarise(
    counties          = n(),
    missing_childcare = sum(is.na(price_center_infant)),
    missing_minwage   = sum(is.na(effective_minwage)),
    missing_fmr       = sum(is.na(fmr_2)),
    missing_acs_rent  = sum(is.na(median_rent_2brE))
  )
print(join_report)

unmatched_fmr <- anti_join(st_drop_geometry(acs), fmr, by = "GEOID") |> select(GEOID, county_label)
if (nrow(unmatched_fmr) > 0) {
  message(nrow(unmatched_fmr), " ACS counties have no Fair Market Rent match:")
  print(as_tibble(unmatched_fmr), n = 20)
}

unmatched <- anti_join(st_drop_geometry(acs), childcare, by = "GEOID") |> select(GEOID, county_label)
if (nrow(unmatched) > 0) {
  message(nrow(unmatched), " ACS counties have no childcare match:")
  print(as_tibble(unmatched), n = 20)
}

# ---- Baseline measures -------------------------------------------------------
index <- index_base |>
  mutate(
    # Shorter names for the income measure used throughout
    # The ACS reports medians outside its range as codes, not values: 2,499 means "below $2,500"
    # and 250,001 means "$250,000 or more". Treat both as missing and flag them.
    income_code = case_when(
      med_income_single_mom_kids_under_18E <= 2499   ~ "below $2,500",
      med_income_single_mom_kids_under_18E >= 250001 ~ "$250,000 or more",
      TRUE ~ NA_character_
    ),
    income     = if_else(is.na(income_code), med_income_single_mom_kids_under_18E, NA_real_),
    income_moe = if_else(is.na(income_code), med_income_single_mom_kids_under_18M, NA_real_),

    # Annual childcare prices (NDCP prices are weekly, full-time)
    annual_center_infant    = price_center_infant    * weeks_per_year,
    annual_center_toddler   = price_center_toddler   * weeks_per_year,
    annual_center_preschool = price_center_preschool * weeks_per_year,
    annual_home_infant      = price_home_infant      * weeks_per_year,

    # Childcare as a share of single-mother income (with children under 18)
    childcare_share_center_infant     = annual_center_infant    / income,
    childcare_share_center_infant_moe = moe_ratio(annual_center_infant, income, 0, income_moe),
    childcare_share_center_preschool  = annual_center_preschool / income,
    childcare_share_home_infant       = annual_home_infant      / income,

    # Minimum wage: weekly hours of work needed to cover infant center care
    hours_minwage_infant = price_center_infant / effective_minwage,
    childcare_share_minwage_infant = annual_center_infant / (effective_minwage * fulltime_hours * weeks_per_year),

    # Poverty rate, single-mother families with children under 18
    pov_total_single_mom_kidsE = pov_below_single_mom_kids_under_18E + pov_above_single_mom_kids_under_18E,
    pov_total_single_mom_kidsM = sqrt(pov_below_single_mom_kids_under_18M^2 + pov_above_single_mom_kids_under_18M^2),
    pov_rate_single_mom     = pov_below_single_mom_kids_under_18E / pov_total_single_mom_kidsE,
    pov_rate_single_mom_moe = moe_prop(pov_below_single_mom_kids_under_18E, pov_total_single_mom_kidsE,
                                       pov_below_single_mom_kids_under_18M, pov_total_single_mom_kidsM),

    # How common single-mother families are
    share_single_mom     = single_mom_kids_under_18E / families_totalE,
    share_single_mom_moe = moe_prop(single_mom_kids_under_18E, families_totalE,
                                    single_mom_kids_under_18M, families_totalM),

    # Reliability, from the coefficient of variation (CV = (MOE / 1.645) / estimate)
    income_cv   = (income_moe / 1.645) / income,
    pov_rate_cv = (pov_rate_single_mom_moe / 1.645) / pmax(pov_rate_single_mom, pov_cv_floor),
    reliability = case_when(
      is.na(income) | pov_total_single_mom_kidsE < 50     ~ "low",
      is.na(income_cv) | is.na(pov_rate_cv)                 ~ "low",   # no margin of error to judge by
      income_cv > 0.40 | pov_rate_cv > 0.40                 ~ "low",
      income_cv > 0.15 | pov_rate_cv > 0.15                 ~ "medium",
      TRUE                                                  ~ "high"
    )
  ) |>
  add_housing_measures(weeks_per_year = weeks_per_year, fulltime_hours = fulltime_hours)

# ---- Quick look ----------------------------------------------------------------
reliable <- index |> st_drop_geometry() |> as_tibble() |> filter(reliability != "low")   # tibble, so the summaries print in full

cat("\nCounties by reliability:\n"); print(count(st_drop_geometry(index), reliability))

cat("\nNational medians across counties (medium or high reliability):\n")
reliable |>
  summarise(
    counties                      = n(),
    median_single_mom_income      = median(income, na.rm = TRUE),
    median_annual_center_infant   = median(annual_center_infant, na.rm = TRUE),
    median_share_center_infant    = median(childcare_share_center_infant, na.rm = TRUE),
    median_hours_minwage_infant   = median(hours_minwage_infant, na.rm = TRUE),
    median_pov_rate_single_mom    = median(pov_rate_single_mom, na.rm = TRUE),
    median_rent_fmr2_monthly      = median(fmr_2, na.rm = TRUE),
    median_rent_share_fmr2        = median(rent_share_fmr2, na.rm = TRUE),
    median_housing_wage_2br       = median(housing_wage_2br, na.rm = TRUE),
    median_childcare_rent_share   = median(childcare_rent_share, na.rm = TRUE),
    share_counties_rent_over_50pc = mean(rent_share_fmr2 > 0.5, na.rm = TRUE),
    share_counties_childcare_rent_over_100pc = mean(childcare_rent_share > 1, na.rm = TRUE)
  ) |>
  print(width = Inf)

cat("\nHighest childcare burden (infant center care as share of single-mother income):\n")
reliable |>
  slice_max(childcare_share_center_infant, n = 10) |>
  select(county_label, childcare_share_center_infant, annual_center_infant, income) |>
  print()

cat("\nHighest childcare-plus-rent burden (infant center care + 2-bedroom Fair Market Rent):\n")
reliable |>
  slice_max(childcare_rent_share, n = 10) |>
  select(county_label, childcare_rent_share, annual_center_infant, annual_rent_fmr2, income) |>
  print()

# State summary, weighting each county by its number of single-mother families
state_summary <- index |>
  st_drop_geometry() |>
  filter(reliability != "low") |>
  group_by(state, state_name) |>
  summarise(
    counties                   = n(),
    single_mom_families        = sum(single_mom_kids_under_18E, na.rm = TRUE),
    childcare_share_center_infant = weighted.mean(childcare_share_center_infant, single_mom_kids_under_18E, na.rm = TRUE),
    pov_rate_single_mom        = sum(pov_below_single_mom_kids_under_18E, na.rm = TRUE) /
                                 sum(pov_total_single_mom_kidsE, na.rm = TRUE),
    rent_share_fmr2            = weighted.mean(rent_share_fmr2, single_mom_kids_under_18E, na.rm = TRUE),
    childcare_rent_share       = weighted.mean(childcare_rent_share, single_mom_kids_under_18E, na.rm = TRUE),
    housing_wage_2br           = weighted.mean(housing_wage_2br, single_mom_kids_under_18E, na.rm = TRUE),
    renter_share_single_mom    = sum(renter_single_mom_kidsE, na.rm = TRUE) /
                                 sum(single_mom_households_kidsE, na.rm = TRUE),
    effective_minwage          = first(effective_minwage),
    .groups = "drop"
  ) |>
  arrange(desc(childcare_share_center_infant))

# ---- Save ----------------------------------------------------------------------
saveRDS(index, file.path(proc_dir, "index_county_2022.rds"))
write.csv(st_drop_geometry(index), file.path(out_dir, "index_county_2022.csv"), row.names = FALSE)
write.csv(state_summary,           file.path(out_dir, "index_state_2022.csv"),  row.names = FALSE)

# GeoPackage for QGIS: one file with county shapes and every measure
st_write(index, file.path(out_dir, "index_county_2022.gpkg"), delete_dsn = TRUE, quiet = TRUE)

message("Saved county and state outputs to ", out_dir)
