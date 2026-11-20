# The Single Mom Index

How well do US counties support single mothers raising children?

The Single Mom Index combines public data on childcare prices, rents, earnings, poverty and state policy to show, county by county, how hard it is for a single mother to support a family. This repository contains the code that downloads the data, cleans it, and calculates the baseline measures.

> **Status:** work in progress. The current version calculates baseline childcare, poverty and housing measures for 2022. Cost of living and additional state policies are planned (see [Roadmap](#roadmap)).

---

## Baseline measures

All measures are calculated for each US county for 2022.

| Measure | Column | Definition |
|---|---|---|
| Infant childcare burden | `childcare_share_center_infant` | Annual price of full-time infant center care as a share of median income for single-mother families with children under 18. `1.0` means 100% of income. |
| Preschool childcare burden | `childcare_share_center_preschool` | Same, for preschool-age center care. |
| Home-based infant care burden | `childcare_share_home_infant` | Same, for infant care in a family childcare home. |
| Minimum-wage hours for infant care | `hours_minwage_infant` | Hours of work per week at the state's effective minimum wage needed to pay for full-time infant center care. |
| Minimum-wage childcare burden | `childcare_share_minwage_infant` | Annual infant center care as a share of full-time, full-year minimum-wage earnings (40 hours × 52 weeks). |
| Single-mother poverty rate | `pov_rate_single_mom` | Share of single-mother families with related children under 18 below the poverty line. |
| Prevalence | `share_single_mom` | Single-mother families with own children under 18 as a share of all families. |

### Housing measures

| Measure | Column | Definition |
|---|---|---|
| Rent burden | `rent_share_fmr2` | Annual HUD Fair Market Rent for a 2-bedroom unit as a share of median income for single-mother families with children under 18. |
| Rent burden category | `rent_burden_fmr2` | HUD's thresholds: not burdened (30% of income or less), burdened (30–50%), severe (over 50%). |
| Housing wage | `housing_wage_2br` | Hourly wage needed for 2-bedroom Fair Market Rent to take no more than 30% of full-time, full-year earnings (the National Low Income Housing Coalition's definition). |
| Housing wage vs. minimum wage | `housing_wage_to_minwage` | Housing wage divided by the state's effective minimum wage. |
| Minimum-wage hours for rent | `hours_minwage_rent` | Hours of work per week at the effective minimum wage needed to pay 2-bedroom Fair Market Rent. |
| Rent burden, ACS rents | `rent_share_acs2` | Same as rent burden, using the ACS median gross rent for 2-bedroom units (what current renters pay) instead of Fair Market Rent. A cross-check. |
| Childcare plus rent | `childcare_rent_share` | Infant center care plus 2-bedroom Fair Market Rent, as a share of single-mother median income. Above `1.0` means the two together cost more than the typical single mother earns. |
| Income left after childcare and rent | `income_left_after_childcare_rent` | Single-mother median income minus both costs, in dollars a year. Negative means a shortfall. |
| Renter share | `renter_share_single_mom` | Share of female-householder households with own children under 18 that rent their home. |

The 2-bedroom unit is the standard size for a parent with one or two children under HUD's occupancy guidelines, and the size most affordability studies use. Fair Market Rents for every unit size (`fmr_0` to `fmr_4`, studio to 4 bedrooms) are kept in the output for other comparisons.

Columns ending in `_moe` are 90% margins of error. They are calculated for measures built from ACS estimates; childcare prices are published as medians without margins of error.

### Reliability

Many counties have few single-mother families, so their estimates are noisy. Each county gets a `reliability` flag based on the coefficient of variation (CV = (MOE ÷ 1.645) ÷ estimate) of the income and poverty estimates. Dividing the 90% margin of error by 1.645 gives the standard error; dividing by the estimate makes it relative to the estimate's size.

Because a CV divides by the estimate, a small poverty rate gets a large CV even when its margin of error is small. The poverty-rate CV therefore divides by the rate or 10%, whichever is larger. For rates under 10%, this works like a cap on the margin of error itself: about 2.5 percentage points for `high` and 6.6 points for `medium`. It also keeps counties with a 0% poverty rate from getting an undefined CV.

| Flag | Rule |
|---|---|
| `high` | CV of 15% or less for both income and poverty rate |
| `medium` | CV above 15% and up to 40% for either |
| `low` | CV above 40% for either, income missing, no margin of error published, or fewer than 50 single-mother families with children |

The ACS reports medians it cannot estimate within its range as codes rather than values: an income of 2,499 means "below $2,500" and 250,001 means "$250,000 or more". These are treated as missing (the code is kept in `income_code`), so those counties are rated `low`.

Summaries and maps should treat `low` counties with caution (for example, hatch or gray them out). State summaries exclude them.

---

## Data sources

| Data | Source | Years | Geography |
|---|---|---|---|
| Childcare prices | US Department of Labor, Women's Bureau, [National Database of Childcare Prices](https://www.dol.gov/agencies/wb/topics/childcare) | 2008–2022 (2022 used) | County |
| Single-mother families (B11003) | US Census Bureau, American Community Survey, via [tidycensus](https://walker-data.com/tidycensus/) | 2018–2022 5-year | County |
| Poverty status of families (B17010) | American Community Survey | 2018–2022 5-year | County |
| Median family income by family type (B19126) | American Community Survey | 2018–2022 5-year | County |
| County boundaries | US Census Bureau cartographic boundary files, via tidycensus | 2022 | County |
| Fair Market Rents | US Department of Housing and Urban Development, [FY2022 Fair Market Rents](https://www.huduser.gov/portal/datasets/fmr.html), county-level file (revised April 2022) | FY2022 (October 2021 to September 2022) | County; towns in New England |
| Median gross rent by bedrooms (B25031, B25064) | American Community Survey | 2018–2022 5-year | County |
| Tenure by household type (B25115) | American Community Survey | 2018–2022 5-year | County |
| State minimum wage | US Department of Labor, via [FRED](https://fred.stlouisfed.org/series/STTMINWGFG) (series `STTMINWG` + state code) | 2022 | State |

The 2022 study year lines up the most recent childcare price data with the 2018–2022 ACS 5-year estimates. ACS income figures are in 2022 inflation-adjusted dollars.

### ACS variables used

| Name in code | ACS variable | Description |
|---|---|---|
| `families_total` | B11003_001 | All families |
| `single_mom_families` | B11003_015 | Female householder, no spouse present |
| `single_mom_kids_under_18` | B11003_016 | …with own children under 18 |
| `single_mom_kids_under_6_only` | B11003_017 | …under 6 only |
| `single_mom_kids_under_6_and_6_17` | B11003_018 | …under 6 and 6 to 17 |
| `single_mom_kids_6_17_only` | B11003_019 | …6 to 17 only |
| `single_mom_no_kids_under_18` | B11003_020 | …no own children under 18 |
| `pov_below_single_mom…` | B17010_016 to _021 | Single-mother families below poverty, by age of related children |
| `pov_above_single_mom…` | B17010_036 to _041 | Single-mother families at or above poverty, by age of related children |
| `med_income_single_mom` | B19126_009 | Median family income, female householder, no spouse present |
| `med_income_single_mom_kids_under_18` | B19126_010 | …with own children under 18 |
| `med_income_single_mom_no_kids_under_18` | B19126_011 | …no own children under 18 |
| `median_rent_all` | B25064_001 | Median gross rent, all renter-occupied units |
| `median_rent_2br` | B25031_004 | Median gross rent, 2 bedrooms |
| `median_rent_3br` | B25031_005 | Median gross rent, 3 bedrooms |
| `owner_single_mom_kids` | B25115_012 | Owner occupied, female householder (no spouse present) with own children under 18 |
| `renter_single_mom_kids` | B25115_025 | Renter occupied, female householder (no spouse present) with own children under 18 |

Gross rent is contract rent plus utilities and fuels paid by the renter.

---

## Repository structure

```
single_mom_index/
├── README.md
├── R/
│   ├── 01_download.R        # downloads raw data (skips anything already saved)
│   ├── 02_clean.R           # cleans names, builds join keys, saves tidy tables
│   ├── utils_ndcp_names.R   # helper: renames childcare price variables
│   ├── utils_housing.R      # helpers: cleans HUD Fair Market Rents, calculates housing measures
│   ├── utils_connecticut.R  # helpers: links Connecticut's old counties to its 2022 planning regions
│   └── 03_build_index.R     # joins sources, calculates measures, saves outputs
├── data/
│   ├── raw/                 # untouched downloads (not tracked in git)
│   └── processed/           # cleaned tables (not tracked in git)
└── output/
    ├── index_county_2022.csv
    ├── index_state_2022.csv
    └── index_county_2022.gpkg   # county shapes + all measures, for QGIS
```

The `data/` and `output/` folders are created by the scripts if they don't exist.

---

## How to reproduce

### 1. Requirements

- R 4.1 or later (the scripts use the native pipe `|>` and `\(x)` function shorthand)
- These packages:

```r
install.packages(c(
  "dplyr", "tidyr", "purrr", "stringr", "tibble",
  "readxl", "here", "sf",
  "tidycensus", "fredr"
))
```

`sf` relies on system geospatial libraries. On macOS and Windows, the CRAN binary includes them. On Linux, see the [sf installation notes](https://r-spatial.github.io/sf/#installing).

### 2. API keys (free, one-time setup)

Two sources need a free API key. Keys are stored in your personal `.Renviron` file, never in the code.

**Census API** — request a key at [api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html), click the activation link in the email, then run once:

```r
tidycensus::census_api_key("YOUR_CENSUS_KEY", install = TRUE)
```

**FRED API** — request a key at [fred.stlouisfed.org](https://fred.stlouisfed.org/docs/api/api_key.html), then add this line to `~/.Renviron` (open it with `usethis::edit_r_environ()` or any text editor):

```
FRED_API_KEY=YOUR_FRED_KEY
```

Restart R afterward (or run `readRenviron("~/.Renviron")`) so the keys load.

### 3. Run the scripts in order

Open the project folder as your working directory (in VS Code: File → Open Folder; in RStudio: open the folder as a project). Paths are built with the [`here`](https://here.r-lib.org/) package, which finds the project root through the `.git` folder or a `.here` file. If `here::here()` doesn't print the project folder, run `here::set_here()` from inside it once.

```r
source("R/01_download.R")      # a few minutes; county shapes are the largest download
source("R/02_clean.R")
source("R/03_build_index.R")
```

Each download is saved to `data/raw/` and skipped on later runs. Delete a file there to download it fresh.

### 4. Outputs

| File | Contents |
|---|---|
| `output/index_county_2022.csv` | One row per county, all measures, margins of error and reliability flag |
| `output/index_state_2022.csv` | State summary, excluding low-reliability counties; county values weighted by number of single-mother families |
| `output/index_county_2022.gpkg` | The county table with boundaries, ready to open in QGIS or other GIS software |
| `data/processed/ndcp_name_map.csv` | Original and cleaned names of every childcare price variable |
| `data/processed/fmr_fy2022.rds` | Fair Market Rents, one row per county (`fmr_rows` above 1 marks New England towns combined) |

---

## Known issues

- **Connecticut.** In 2022 the Census Bureau replaced Connecticut's eight counties with nine planning regions, which the 2018–2022 ACS uses. The childcare prices and HUD's Fair Market Rents still use the old counties. Towns kept their census codes through the change, so `utils_connecticut.R` links each town to its old county (2017–2021 ACS) and its planning region (2018–2022 ACS). Fair Market Rents, which HUD sets by town, are assigned to planning regions directly. Childcare prices are moved from old counties to planning regions, weighting each old county by the 2022 population of its towns in that region. Where the childcare data has no 2022 prices for Connecticut, the measures stay blank. The crosswalk is saved as `data/processed/ct_town_crosswalk.rds`.
- **Alaska.** The Valdez-Cordova Census Area was split into Chugach and Copper River in 2019. If the Fair Market Rent file still uses the old area, both new areas get its rent.
- **Childcare price coverage.** Some counties have no childcare price data, and some state-reported prices are estimated. See the NDCP technical guide for how prices were collected and imputed.
- **Childcare prices are medians.** The burden measures describe a typical price against a typical income. Many families pay less through relatives, subsidies or informal care.
- **Fair Market Rents are not what families pay.** They are HUD's estimate of the 40th percentile gross rent for a standard-quality unit that a mover would find, used to set housing voucher payments. Current tenants may pay less, and many single mothers live with relatives or share housing. `rent_share_acs2` (median rent current renters pay) is included as a check.
- **Fair Market Rents cover metro areas, not single counties.** All counties in a metropolitan area share one Fair Market Rent, so differences within a metro area are not visible. HUD's Small Area Fair Market Rents (by ZIP code) could show them in a later version.
- **New England towns.** In Connecticut, Maine, Massachusetts, New Hampshire, Rhode Island and Vermont, HUD sets Fair Market Rents for towns. They are combined into a county value, weighted by each town's 2017 population.
- **Income and rent cover different households.** ACS rents describe all renters in a county, not only single mothers; the income is for single-mother families with children under 18.
- **Minimum wage is state-level.** City and county minimum wages (often higher) are not yet included.
- **Download blocks.** Government sites occasionally block scripted downloads. If `01_download.R` fails on the childcare file, download it in a browser from the DOL page linked above and save it as `data/raw/ndcp_2008_2022.xlsx`; the script will use your copy. The same applies to the HUD file: save `FY22_FMRs_revised.xlsx` as `data/raw/hud_fmr_fy2022.xlsx`.

---

## Roadmap

- ~~Housing: HUD Fair Market Rents as a share of single-mother income~~ (added)
- Housing: Small Area Fair Market Rents
- Cost of living: Self-Sufficiency Standard or living wage estimates
- State policy: paid family leave, state EITC and child tax credits, Medicaid expansion
- Local minimum wages
- A combined 0 to 100 index score with published weights and a sensitivity analysis

---

## About

Created by **Your Name**, an information designer and former quantitative social researcher. See the project write-up at [yourname.com](https://yourname.com).

Questions or corrections are welcome; please open an issue.

### License

Code: MIT License (see `LICENSE`). Underlying data belongs to its original publishers; see each source's terms.
