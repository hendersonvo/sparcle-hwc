library(tidyverse)
library(amt)
library(terra)
library(here)
select <- dplyr::select

dir.create(here("outputs", "etosha_1h_chunks"), showWarnings = FALSE)

for (i in unique(ele_etosha_reg$id)) {
  f <- here("outputs", "etosha_1h_chunks", paste0(i, ".rds"))
  if (file.exists(f)) next
  cat(format(Sys.time(), "%H:%M"), i, "\n")
  
  ele_etosha_reg |>
    filter(id == i) |>
    extract_evi() |>
    extract_world_pop() |>
    extract_static() |>
    extract_lc_dist() |>
    extract_linear() |>
    select(-terrain_list, -linear_list) |>
    saveRDS(f)
}

cat("DONE", format(Sys.time()), "\n")