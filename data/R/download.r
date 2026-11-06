library(dplyr)
library(readxl)
library(here)

url_childcare <- "https://www.dol.gov/sites/dolgov/files/WB/NDCP2022.xlsx"
childcare_filename <- "ndcp_2008_2022.xlsx"

url_poverty_status <- "https://api.censusreporter.org/1.0/data/download/acs2024_1yr?table_ids=B17010&geo_ids=01000US,040|01000US&format=xlsx"
poverty_status_filename <- "acs2024_1yr_B17010_04000US28"


url_family_income <- "https://api.censusreporter.org/1.0/data/download/acs2024_1yr?table_ids=B19126&geo_ids=01000US,040|01000US&format=xlsx"
family_income_filename = 'acs2024_1yr_B19126_04000US28'


download_spreadsheet <- function(url, filename) {
    dest <- here("data", "raw", filename)
    if (!file.exists(dest)) {
        download.file(url, destfile = dest, mode = "wb")
    }

    return(read_excel(dest))
}

childcare <- read_excel(dest)


childcare <- download_spreadsheet(filename = childcare_filename)
poverty_status <- download_spreadsheet(url_poverty_status, poverty_status_filename)


