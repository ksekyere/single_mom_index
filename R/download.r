# 01_download.R
#' Download raw data for the Single Mom Index. Nothing is cleaned here; every
#' source is saved untouched in data/raw/ so the cleaning step can be rerun offline.
#'
# Keys (set once, never in this script):
#   Census: tidycensus::census_api_key("YOUR_KEY", install = TRUE)
#   FRED:   add FRED_API_KEY=YOUR_KEY to ~/.Renviron

library(dplyr)
library(purrr)
library(readxl)
library(here)
library(tidycensus)
library(fredr)

raw_dir <- here("data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# ---- Childcare prices (DOL National Database of Childcare Prices) ----------
download_file_once <- function(url, filename) {
    dest <- file.path(raw_dir, filename)
    if (!file.exists(dest)) {
        download.file(url,
            destfile = dest, mode = "wb", method = "libcurl",
            headers = c("User-Agent" = "Mozilla/5.0")
        )
    }
    dest
}

download_file_once(
    url      = "https://www.dol.gov/sites/dolgov/files/WB/NDCP2022.xlsx",
    filename = "ndcp_2008_2022.xlsx"
)

# ---- ACS 2018–2022 5-year: single-mother families, poverty, income ---------
single_mom_vars <- c(
    families_total                             = "B11003_001",
    single_mom_families                        = "B11003_015",
    single_mom_kids_under_18                   = "B11003_016",
    single_mom_kids_under_6_only               = "B11003_017",
    single_mom_kids_under_6_and_6_17           = "B11003_018",
    single_mom_kids_6_17_only                  = "B11003_019",
    single_mom_no_kids_under_18                = "B11003_020",
    pov_below_single_mom                       = "B17010_016",
    pov_below_single_mom_kids_under_18         = "B17010_017",
    pov_below_single_mom_kids_under_5_only     = "B17010_018",
    pov_below_single_mom_kids_under_5_and_5_17 = "B17010_019",
    pov_below_single_mom_kids_5_17_only        = "B17010_020",
    pov_below_single_mom_no_kids_under_18      = "B17010_021",
    pov_above_single_mom                       = "B17010_036",
    pov_above_single_mom_kids_under_18         = "B17010_037",
    pov_above_single_mom_kids_under_5_only     = "B17010_038",
    pov_above_single_mom_kids_under_5_and_5_17 = "B17010_039",
    pov_above_single_mom_kids_5_17_only        = "B17010_040",
    pov_above_single_mom_no_kids_under_18      = "B17010_041",
    med_income_single_mom                      = "B19126_009",
    med_income_single_mom_kids_under_18        = "B19126_010",
    med_income_single_mom_no_kids_under_18     = "B19126_011"
)

acs_file <- file.path(raw_dir, "acs5_2022_single_mom_county.rds")
if (!file.exists(acs_file)) {
    acs <- get_acs(
        geography = "county",
        variables = single_mom_vars,
        year      = 2022,
        survey    = "acs5",
        output    = "wide",
        geometry  = TRUE
    )
    saveRDS(acs, acs_file)
}

# ---- Minimum wage (FRED, from US Dept. of Labor) ----------------------------
minwage_file <- file.path(raw_dir, "fred_minwage_2022.rds")
if (!file.exists(minwage_file)) {
    states <- c(state.abb, "DC")

    state_mw <- map_dfr(states, \(st) {
        tryCatch(
            fredr(
                series_id = paste0("STTMINWG", st),
                observation_start = as.Date("2022-01-01")
            ) %>%
                mutate(state = st),
            error = function(e) NULL # states with no state minimum wage
        )
    })

    federal_mw <- fredr("STTMINWGFG", observation_start = as.Date("2022-01-01"))

    saveRDS(list(state = state_mw, federal = federal_mw, states = states), minwage_file)
}

message("Downloads complete: ", paste(list.files(raw_dir), collapse = ", "))
