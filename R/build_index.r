# 03_build_index.R
# Join the cleaned tables and calculate baseline Single Mom Index measures by county.
# Inputs come from 02_clean.R; outputs go to output/ for charts (R, Illustrator) and maps (QGIS).
#
# Baseline measures
#   childcare_share_*      annual childcare price as a share of single-mother median income
#   hours_minwage_infant   hours of minimum-wage work needed each week to pay for infant care
#   pov_rate_single_mom    poverty rate of single-mother families with children under 18
#   share_single_mom       single-mother families with children as a share of all families
# Margins of error are carried through wherever the inputs have them (ACS values only;
# NDCP prices are medians without published margins of error).

library(dplyr)
library(tidyr)
library(here)
library(sf)
library(tidycensus) # moe_ratio(), moe_prop()

proc_dir <- here("data", "processed")
out_dir <- here("output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

acs <- readRDS(file.path(proc_dir, "acs5_2022_single_mom_county.rds"))
childcare <- readRDS(file.path(proc_dir, "childcare_2022.rds"))
minwage <- readRDS(file.path(proc_dir, "minwage_2022.rds"))

weeks_per_year <- 52
fulltime_hours <- 40

# The measures below need these childcare columns; stop early with a clear message if any is missing
needed <- c("price_center_infant", "price_center_toddler", "price_center_preschool", "price_home_infant")
missing_cols <- setdiff(needed, names(childcare))
if (length(missing_cols) > 0) {
    stop(
        "Missing childcare columns: ", paste(missing_cols, collapse = ", "),
        ". Check data/processed/ndcp_name_map.csv for what they were named."
    )
}

# ---- Join --------------------------------------------------------------------
index_base <- acs %>%
    left_join(select(childcare, GEOID, starts_with("price_")), by = "GEOID") %>%
    left_join(select(minwage, state, effective_minwage, no_state_minimum), by = "state")

# Join checks: how many counties found a match in each source?
join_report <- index_base %>%
    st_drop_geometry() %>%
    summarise(
        counties          = n(),
        missing_childcare = sum(is.na(price_center_infant)),
        missing_minwage   = sum(is.na(effective_minwage))
    )
print(join_report)

unmatched <- anti_join(st_drop_geometry(acs), childcare, by = "GEOID") %>% select(GEOID, county_label)
if (nrow(unmatched) > 0) {
    message(nrow(unmatched), " ACS counties have no childcare match (Connecticut's 2022 planning regions are expected):")
    print(head(unmatched, n = 20))
}

# ---- Baseline measures -------------------------------------------------------
index <- index_base %>%
    mutate(
        # Shorter names for the income measure used throughout
        income = med_income_single_mom_kids_under_18E,
        income_moe = med_income_single_mom_kids_under_18M,

        # Annual childcare prices (NDCP prices are weekly, full-time)
        annual_center_infant = price_center_infant * weeks_per_year,
        annual_center_toddler = price_center_toddler * weeks_per_year,
        annual_center_preschool = price_center_preschool * weeks_per_year,
        annual_home_infant = price_home_infant * weeks_per_year,

        # Childcare as a share of single-mother income (with children under 18)
        childcare_share_center_infant = annual_center_infant / income,
        childcare_share_center_infant_moe = moe_ratio(annual_center_infant, income, 0, income_moe),
        childcare_share_center_preschool = annual_center_preschool / income,
        childcare_share_home_infant = annual_home_infant / income,

        # Minimum wage: weekly hours of work needed to cover infant center care
        hours_minwage_infant = price_center_infant / effective_minwage,
        childcare_share_minwage_infant = annual_center_infant / (effective_minwage * fulltime_hours * weeks_per_year),

        # Poverty rate, single-mother families with children under 18
        pov_total_single_mom_kidsE = pov_below_single_mom_kids_under_18E + pov_above_single_mom_kids_under_18E,
        pov_total_single_mom_kidsM = sqrt(pov_below_single_mom_kids_under_18M^2 + pov_above_single_mom_kids_under_18M^2),
        pov_rate_single_mom = pov_below_single_mom_kids_under_18E / pov_total_single_mom_kidsE,
        pov_rate_single_mom_moe = moe_prop(
            pov_below_single_mom_kids_under_18E, pov_total_single_mom_kidsE,
            pov_below_single_mom_kids_under_18M, pov_total_single_mom_kidsM
        ),

        # How common single-mother families are
        share_single_mom = single_mom_kids_under_18E / families_totalE,
        share_single_mom_moe = moe_prop(
            single_mom_kids_under_18E, families_totalE,
            single_mom_kids_under_18M, families_totalM
        ),

        # Reliability, from the coefficient of variation (CV = (MOE / 1.645) / estimate)
        income_cv = (income_moe / 1.645) / income,
        pov_rate_cv = (pov_rate_single_mom_moe / 1.645) / pov_rate_single_mom,
        reliability = case_when(
            is.na(income) | pov_total_single_mom_kidsE < 50 ~ "low",
            income_cv > 0.40 | pov_rate_cv > 0.40 ~ "low",
            income_cv > 0.15 | pov_rate_cv > 0.15 ~ "medium",
            TRUE ~ "high"
        )
    )

# ---- Quick look ----------------------------------------------------------------
reliable <- index %>%
    st_drop_geometry() %>%
    filter(reliability != "low")

cat("\nCounties by reliability:\n")
print(count(st_drop_geometry(index), reliability))

cat("\nNational medians across counties (medium or high reliability):\n")
reliable %>%
    summarise(
        counties                      = n(),
        median_single_mom_income      = median(income, na.rm = TRUE),
        median_annual_center_infant   = median(annual_center_infant, na.rm = TRUE),
        median_share_center_infant    = median(childcare_share_center_infant, na.rm = TRUE),
        median_hours_minwage_infant   = median(hours_minwage_infant, na.rm = TRUE),
        median_pov_rate_single_mom    = median(pov_rate_single_mom, na.rm = TRUE)
    ) %>%
    print()

cat("\nHighest childcare burden (infant center care as share of single-mother income):\n")
reliable %>%
    slice_max(childcare_share_center_infant, n = 10) %>%
    select(county_label, childcare_share_center_infant, annual_center_infant, income) %>%
    print()

# State summary, weighting each county by its number of single-mother families
state_summary <- index %>%
    st_drop_geometry() %>%
    filter(reliability != "low") %>%
    group_by(state, state_name) %>%
    summarise(
        counties = n(),
        single_mom_families = sum(single_mom_kids_under_18E, na.rm = TRUE),
        childcare_share_center_infant = weighted.mean(childcare_share_center_infant, single_mom_kids_under_18E, na.rm = TRUE),
        pov_rate_single_mom = sum(pov_below_single_mom_kids_under_18E, na.rm = TRUE) /
            sum(pov_total_single_mom_kidsE, na.rm = TRUE),
        effective_minwage = first(effective_minwage),
        .groups = "drop"
    ) %>%
    arrange(desc(childcare_share_center_infant))

# ---- Save ----------------------------------------------------------------------
saveRDS(index, file.path(proc_dir, "index_county_2022.rds"))
write.csv(st_drop_geometry(index), file.path(out_dir, "index_county_2022.csv"), row.names = FALSE)
write.csv(state_summary, file.path(out_dir, "index_state_2022.csv"), row.names = FALSE)

# GeoPackage for QGIS: one file with county shapes and every measure
st_write(index, file.path(out_dir, "index_county_2022.gpkg"), delete_dsn = TRUE, quiet = TRUE)

message("Saved county and state outputs to ", out_dir)
