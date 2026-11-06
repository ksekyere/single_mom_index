library(tidycensus)
library(fredr)

census_key <- "a771cee8c94a84b81597dca0986cff29ba940074"

census_api_key(census_key, install = TRUE, overwrite = TRUE)
readRenviron("~/.Renviron")


fred_key <- "b637dcae50952168338a1448ad53db79"
fredr_set_key(fred_key)


library(ggplot2)

library(ggplot2)

index %>%
    filter(!state %in% c("AK", "HI", "PR")) %>%
    ggplot() +
    geom_sf(aes(fill = childcare_share_center_infant), color = NA) +
    scale_fill_viridis_c(labels = scales::percent, name = "Infant care\nshare of income") +
    theme_void()
