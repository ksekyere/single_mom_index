# utils_connecticut.R
# In 2022 the Census Bureau replaced Connecticut's eight counties with nine planning regions as
# county-equivalents, so the 2018-2022 ACS uses planning regions while HUD's FY2022 Fair Market
# Rents and the 2022 childcare prices still use the old counties. Towns (county subdivisions)
# kept their 5-digit codes through the change, so they link old counties to planning regions.
#   build_ct_crosswalk()   one row per town: old county, planning region, 2022 population
#   remap_ct_to_regions()  turns old-county rows of any county table into planning-region rows,
#                          weighting each old county's values by the population of its towns
#                          that fall in each region

library(dplyr)
library(stringr)

build_ct_crosswalk <- function(towns_2021, towns_2022) {
  old <- towns_2021 |>
    transmute(cousub = str_sub(GEOID, 6, 10), old_county = str_sub(GEOID, 1, 5))
  new <- towns_2022 |>
    transmute(cousub = str_sub(GEOID, 6, 10), region = str_sub(GEOID, 1, 5),
              town = NAME, pop = popE)
  inner_join(new, old, by = "cousub") |>
    filter(cousub != "00000", !is.na(pop))          # "county subdivisions not defined"
}

remap_ct_to_regions <- function(df, xwalk) {
  is_ct <- str_sub(df$GEOID, 1, 2) == "09"
  if (!any(is_ct)) return(df)
  ct <- df[is_ct, ]
  num_cols   <- names(ct)[vapply(ct, is.numeric, logical(1))]
  other_cols <- setdiff(names(ct), c("GEOID", num_cols))

  wmean <- function(x, w) if (all(is.na(x))) NA_real_ else weighted.mean(x, w, na.rm = TRUE)

  regions <- xwalk |>
    inner_join(ct, by = c(old_county = "GEOID")) |>
    group_by(GEOID = region) |>
    summarise(
      across(all_of(num_cols), \(x) wmean(x, pop)),
      across(all_of(other_cols), first),
      ct_old_counties = paste(sort(unique(old_county)), collapse = "; "),
      .groups = "drop"
    )
  if ("state_code" %in% names(regions)) regions$state_code <- "09"
  if ("county_name" %in% names(regions)) regions$county_name <- NA_character_

  bind_rows(df[!is_ct, ], regions)
}
