# The Single Mom Index

How well do US counties support single mothers raising children?

The Single Mom Index combines public data on childcare prices, earnings, poverty and state policy to show, county by county, how hard it is for a single mother to support a family. This repository contains the code that downloads the data, cleans it, and calculates the baseline measures.

> **Status:** work in progress. The current version calculates baseline measures for 2022. Housing costs, cost of living and additional state policies are planned (see [Roadmap](#roadmap)).

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

Columns ending in `_moe` are 90% margins of error. They are calculated for measures built from ACS estimates; childcare prices are published as medians without margins of error.

### Reliability

Many counties have few single-mother families, so their estimates are noisy. Each county gets a `reliability` flag based on the coefficient of variation (CV = (MOE ÷ 1.645) ÷ estimate) of the income and poverty estimates:

| Flag | Rule |
|---|---|
| `high` | CV of 15% or less for both income and poverty rate |
| `medium` | CV above 15% and up to 40% for either |
| `low` | CV above 40% for either, income missing, or fewer than 50 single-mother families with children |

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

---

## Repository structure

```
single_mom_index/
├── README.md
├── R/
│   ├── 01_download.R        # downloads raw data (skips anything already saved)
│   ├── 02_clean.R           # cleans names, builds join keys, saves tidy tables
│   ├── utils_ndcp_names.R   # helper: renames childcare price variables
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

---

## Known issues

- **Connecticut.** In 2022 the Census Bureau replaced Connecticut's eight counties with nine planning regions. The childcare data still uses the old counties, so Connecticut does not join and has no childcare measures in this version.
- **Childcare price coverage.** Some counties have no childcare price data, and some state-reported prices are estimated. See the NDCP technical guide for how prices were collected and imputed.
- **Childcare prices are medians.** The burden measures describe a typical price against a typical income. Many families pay less through relatives, subsidies or informal care.
- **Minimum wage is state-level.** City and county minimum wages (often higher) are not yet included.
- **Download blocks.** Government sites occasionally block scripted downloads. If `01_download.R` fails on the childcare file, download it in a browser from the DOL page linked above and save it as `data/raw/ndcp_2008_2022.xlsx`; the script will use your copy.

---

## Roadmap

- Housing: HUD Fair Market Rents as a share of single-mother income
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
