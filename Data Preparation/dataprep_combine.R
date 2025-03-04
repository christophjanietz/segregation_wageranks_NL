### Dashboard of sex segregation across wage ranks in Dutch organizations.
### Data preparation
### Project: Beyond Boardroom (9607)
### Author: Christoph Janietz (c.janietz@rug.nl)
### Last update: 04-03-2025

# Libraries and functions ------------------------------------------------------
library(dplyr)
library(readxl)

# Import spreadsheets ----------------------------------------------------------
sexseg <- read_excel("./sexseg.xls")
ethnicseg  <- read_excel("./ethnicseg.xls")

# Transform variable wgt into FALSE/TRUE ---------------------------------------
sexseg <- sexseg %>%
  mutate(wgt = wgt=="Yes")
ethnicseg <- ethnicseg %>%
  mutate(wgt = wgt=="Yes")

# Reorder factor levels in ethnicseg
ethnicseg <- ethnicseg %>%
  mutate(wstrn = factor(wstrn,
                        levels = c("Western","Non-Western")))

# Save datasets ----------------------------------------------------------------
save(sexseg, ethnicseg, file="./seg_org.RData")