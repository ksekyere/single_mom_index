# 02_clean.R
# Clean the raw downloads from 01_download.R into tidy, joinable tables.
# Every table leaves this script with the same keys:
#   GEOID       5-digit county FIPS code, as text with leading zeros ("01001")
#   state_code  2-digit state FIPS code ("01")
#   state       2-letter state abbreviation ("AL")
# No index measures are calculated here; that happens in 03_build_index.R.

library(dplyr)
library(stringr)
library(readxl)
library(here)
library(tidycensus) # for the fips_codes lookup table
library(sf)

source(here("R", "utils_ndcp_names.r"))


raw_dir <- here("data", "raw")
proc_dir <- here("data", "processed")
dir.create(proc_dir, recursive = TRUE, showWarnings = FALSE)

target_year <- 2022 # matches the 2018–2022 ACS and the last NDCP year

# State FIPS code <-> abbreviation, from tidycensus
state_lookup <- fips_codes %>%
    distinct(state_code, state, state_name)

# ---- Childcare prices --------------------------------------------------------
ndcp_path <- file.path(raw_dir, "ndcp_2008_2022.xlsx")
excel_sheets(ndcp_path) # check this once; change `sheet` below if the data is not on tab 1

childcare_raw <- read_excel(ndcp_path, sheet = 1, na = c("", "NA", "N/A", "."))

childcare_all <- clean_ndcp_names(childcare_raw)
write.csv(attr(childcare_all, "name_map"), file.path(proc_dir, "ndcp_name_map.csv"), row.names = FALSE)

childcare <- childcare_all %>%
    mutate(
        GEOID      = str_pad(as.character(county_fips), 5, pad = "0"),
        state_code = str_sub(GEOID, 1, 2),
        study_year = as.integer(study_year),
        across(starts_with("price_") & !ends_with("_flag"), \(x) suppressWarnings(as.numeric(x)))
    ) %>%
    filter(study_year == target_year) %>%
    select(GEOID, state_code, state_abbr, county_name, study_year, starts_with("price_"))

# Each county should appear once for the study year
dup_counties <- childcare %>%
    count(GEOID) %>%
    filter(n > 1)
if (nrow(dup_counties) > 0) warning(nrow(dup_counties), " counties appear more than once in the childcare data")

saveRDS(childcare, file.path(proc_dir, "childcare_2022.rds"))

# ---- ACS ---------------------------------------------------------------------
acs_raw <- readRDS(file.path(raw_dir, "acs5_2022_single_mom_county.rds"))

acs <- acs_raw %>%
    mutate(state_code = str_sub(GEOID, 1, 2)) %>%
    left_join(state_lookup, by = "state_code") %>%
    rename(county_label = NAME) %>%
    relocate(GEOID, state_code, state, state_name, county_label)

saveRDS(acs, file.path(proc_dir, "acs5_2022_single_mom_county.rds"))

# ---- Minimum wage ------------------------------------------------------------
mw <- readRDS(file.path(raw_dir, "fred_minwage_2022.rds"))

federal_2022 <- mw$federal %>%
    filter(format(date, "%Y") == as.character(target_year)) %>%
    pull(value)

minwage <- tibble(state = mw$states) %>%
    left_join(
        mw$state %>%
            filter(format(date, "%Y") == as.character(target_year)) %>%
            select(state, state_minwage = value),
        by = "state"
    ) %>%
    mutate(
        federal_minwage   = federal_2022,
        # States with no minimum, or one below the federal rate, fall back to $7.25
        effective_minwage = pmax(coalesce(state_minwage, 0), federal_minwage),
        no_state_minimum  = is.na(state_minwage) | state_minwage == 0
    ) %>%
    left_join(state_lookup, by = "state")

saveRDS(minwage, file.path(proc_dir, "minwage_2022.rds"))

message(
    "Cleaned: ", nrow(childcare), " childcare counties, ",
    nrow(acs), " ACS counties, ", nrow(minwage), " states"
)
