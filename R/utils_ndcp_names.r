# utils_ndcp_names.R
# Helper used by 02_clean.R: translate National Database of Childcare Prices (NDCP)
# variable names into clean snake_case. Names follow the NDCP Technical Guide (2022), Appendix D.
#
#   1. Identifier and ACS variables are renamed from an explicit lookup table.
#   2. Childcare price variables (MC..., MFCC...) are translated by rule.
#   3. Anything else gets plain snake_case and is reported, so nothing is renamed silently.
#
# Naming scheme: lowercase snake_case; f = female, m = male; ages in years unless "mo".
 
library(dplyr)
library(stringr)
 
# ---- 1. Lookup table for identifier and ACS variables ----------------------
# Left: name in the NDCP file. Right: clean name.
lookup <- c(
  # identifiers
  State_Name               = "state_name",
  State_Abbreviation       = "state_abbr",
  County_Name              = "county_name",
  County_FIPS_Code         = "county_fips",
  StudyYear                = "study_year",
 
  # unemployment rates
  UNR_16                   = "unemp_rate_16plus",
  FUNR_16                  = "unemp_rate_f_16plus",
  MUNR_16                  = "unemp_rate_m_16plus",
  UNR_20to64               = "unemp_rate_20_64",
  FUNR_20to64              = "unemp_rate_f_20_64",
  MUNR_20to64              = "unemp_rate_m_20_64",
 
  # labor force participation, ages 20–64
  FLFPR_20to64             = "lfpr_f_20_64",
  FLFPR_20to64_Under6      = "lfpr_f_20_64_kids_under6",
  FLFPR_20to64_6to17       = "lfpr_f_20_64_kids_6_17",
  FLFPR_20to64_Under6_6to17 = "lfpr_f_20_64_kids_under6_and_6_17",
  MLFPR_20to64             = "lfpr_m_20_64",
 
  # poverty
  PR_F                     = "poverty_rate_family",
  PR_P                     = "poverty_rate_person",
 
  # income and earnings
  MHI                      = "med_hh_income",
  MHI_2018                 = "med_hh_income_2018usd",
  ME                       = "med_earnings",
  ME_2018                  = "med_earnings_2018usd",
  FME                      = "med_earnings_f",
  FME_2018                 = "med_earnings_f_2018usd",
  MME                      = "med_earnings_m",
  MME_2018                 = "med_earnings_m_2018usd",
 
  # population and race/ethnicity (percent of population)
  TotalPop                 = "total_pop",
  OneRace                  = "pct_one_race",
  OneRace_W                = "pct_white",
  OneRace_B                = "pct_black",
  OneRace_I                = "pct_aian",
  OneRace_A                = "pct_asian",
  OneRace_H                = "pct_nhpi",
  OneRace_Other            = "pct_other_race",
  TwoRaces                 = "pct_two_plus_races",
  Hispanic                 = "pct_hispanic",
 
  # households with children, by who works
  Households               = "households",
  H_Under6_BothWork        = "hh_kids_under6_both_parents_work",
  H_Under6_FWork           = "hh_kids_under6_father_works",
  H_Under6_MWork           = "hh_kids_under6_mother_works",
  H_Under6_SingleM         = "hh_kids_under6_single_mother",
  H_6to17_BothWork         = "hh_kids_6_17_both_parents_work",
  H_6to17_FWork            = "hh_kids_6_17_father_works",
  H_6to17_MWork            = "hh_kids_6_17_mother_works",
  H_6to17_SingleM          = "hh_kids_6_17_single_mother",
 
  # employment by occupation group, ages 16+
  EMP_M                    = "emp_mgmt_sci_arts",
  MEMP_M                   = "emp_mgmt_sci_arts_m",
  FEMP_M                   = "emp_mgmt_sci_arts_f",
  EMP_Service              = "emp_service",
  MEMP_Service             = "emp_service_m",
  FEMP_Service             = "emp_service_f",
  EMP_Sales                = "emp_sales_office",
  MEMP_Sales               = "emp_sales_office_m",
  FEMP_Sales               = "emp_sales_office_f",
  EMP_N                    = "emp_natres_constr_maint",
  MEMP_N                   = "emp_natres_constr_maint_m",
  FEMP_N                   = "emp_natres_constr_maint_f",
  EMP_P                    = "emp_prod_transport",
  MEMP_P                   = "emp_prod_transport_m",
  FEMP_P                   = "emp_prod_transport_f"
)
# Match case-insensitively: the file mixes "FWork" and "Fwork", for example.
names(lookup) <- tolower(names(lookup))
 
# ---- 2. Rule-based translation for childcare price variables ----------------
# NDCP price names look like MCInfant, MFCCToddler, MCBto5, MC6to11, MC54toSA, MCSA,
# with optional suffixes such as _75 (75th percentile) or a flag marker.
#   MC   = median weekly full-time price, center-based care      -> "center"
#   MFCC = median weekly full-time price, family (home-based) care -> "home"
translate_price <- function(x) {
  m <- str_match(x, regex("^(MFCC|MC)(.+)$", ignore_case = TRUE))
  if (is.na(m[1, 1])) return(NA_character_)
 
  provider <- if (toupper(m[1, 2]) == "MFCC") "home" else "center"
  rest     <- m[1, 3]
 
  # pull off suffixes first
  pct  <- if (str_detect(rest, "_75$")) "_p75" else if (str_detect(rest, "_25$")) "_p25" else ""
  rest <- str_remove(rest, "_(75|25)$")
  flag <- if (str_detect(rest, regex("_?flag$", ignore_case = TRUE))) "_flag" else ""
  rest <- str_remove(rest, regex("_?flag$", ignore_case = TRUE))
 
  age <- case_when(
    str_detect(rest, regex("^infant$",    ignore_case = TRUE)) ~ "infant",
    str_detect(rest, regex("^toddler$",   ignore_case = TRUE)) ~ "toddler",
    str_detect(rest, regex("^preschool$", ignore_case = TRUE)) ~ "preschool",
    str_detect(rest, regex("^SA$",        ignore_case = TRUE)) ~ "school_age",
    str_detect(rest, regex("^Bto(\\d+)$", ignore_case = TRUE)) ~
      str_replace(rest, regex("^Bto(\\d+)$", ignore_case = TRUE), "0_\\1mo"),
    str_detect(rest, regex("^(\\d+)toSA$", ignore_case = TRUE)) ~
      str_replace(rest, regex("^(\\d+)toSA$", ignore_case = TRUE), "\\1mo_to_school_age"),
    str_detect(rest, "^\\d+to\\d+$") ~
      str_replace(rest, "^(\\d+)to(\\d+)$", "\\1_\\2mo"),
    TRUE ~ NA_character_
  )
  if (is.na(age)) return(NA_character_)
 
  paste0("price_", provider, "_", age, pct, flag)
}
 
 
snake_case <- function(x) {
  x %>%
    str_replace_all("([a-z0-9])([A-Z])", "\\1_\\2") %>%
    str_replace_all("[^A-Za-z0-9]+", "_") %>%
    str_to_lower() %>%
    str_remove_all("^_|_$")
}
 
# Returns a tibble: original name, clean name, and which rule produced it.
ndcp_name_map <- function(old_names) {
  from_lookup <- unname(lookup[tolower(old_names)])
  from_price  <- vapply(old_names, translate_price, character(1), USE.NAMES = FALSE)
 
  tibble(
    original = old_names,
    clean    = coalesce(from_lookup, from_price, snake_case(old_names)),
    method   = case_when(!is.na(from_lookup) ~ "lookup",
                         !is.na(from_price)  ~ "price rule",
                         TRUE                ~ "fallback")
  )
}
 
# Renames the columns of an NDCP data frame and checks the result.
clean_ndcp_names <- function(df) {
  name_map <- ndcp_name_map(names(df))
 
  fallbacks <- filter(name_map, method == "fallback")
  if (nrow(fallbacks) > 0) {
    message(nrow(fallbacks), " NDCP column(s) used the fallback rule; review these:")
    print(fallbacks, n = Inf)
  }
 
  dupes <- name_map %>% count(clean) %>% filter(n > 1)
  if (nrow(dupes) > 0) stop("Duplicate clean names: ", paste(dupes$clean, collapse = ", "))
 
  out <- setNames(df, name_map$clean)
  attr(out, "name_map") <- name_map     # kept so 02_clean.R can save it
  out
}