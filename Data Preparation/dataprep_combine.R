### Dashboard of sex segregation across wage ranks in Dutch organizations.
### Data preparation
### Project: Beyond Boardroom (9607)
### Author: Christoph Janietz (c.janietz@rug.nl)
### Last update: 17-01-2025

# Libraries and functions ------------------------------------------------------
library(dplyr)
library(readxl)

# Import spreadsheets ----------------------------------------------------------
withind <- read_excel("./withind.xls")
withinq <- read_excel("./withinq.xls")

# Transform variable wgt into FALSE/TRUE ---------------------------------------
withind <- withind %>%
  mutate(wgt = wgt=="Yes")
withinq <- withinq %>%
  mutate(wgt = wgt=="Yes")

# Save datasets ----------------------------------------------------------------
save(withind, withinq, file="./sexseg_org.RData")