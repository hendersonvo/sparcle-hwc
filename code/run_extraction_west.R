
library(tidyverse)
library(janitor)
library(here)
library(terra)
library(amt)

ele_west_reg <- readRDS(here("outputs", "ele_west_reg.rds"))

extract_evi <- readRDS(here("outputs", "extract_evi.rds"))
extract_world_pop <- readRDS(here("outputs", "extract_world_pop.rds"))
extract_static <- readRDS(here("outputs", "extract_static.rds"))
extract_lc_dist <- readRDS(here("outputs", "extract_lc_dist.rds"))
extract_linear <- readRDS(here("outputs", "extract_linear.rds"))

gee_folder <- here("data", "500m_data")
evi_folder <- here("data", "500m_data", "EVI data")
wet_months <- c(1:4, 11:12)
dry_months <- c(5:10)

world_pop <- rast(here("data", "500m_data", "worldPop_comb_img_500m.tif"))
world_pop_list <- split(world_pop, 1:nlyr(world_pop))

lc_types <- c("cropland", "grassland", "shrubland", "tree_cover", "urban", "water_rivers")
lc_dist_folder <- here("data", "ESACCI_LCCS", "lc_dist_2")

linear_folder <- here("data", "Linear_features")
linear_types <- c("hydrorivers", "kaza_vet_fences", "roads")

run_batched_pipeline <- function(reg_data, label) {
  n_total <- nrow(reg_data)
  batch_size <- 50000
  n_batches <- ceiling(n_total / batch_size)
  pipeline_dir <- here("data", paste0("batch_output_", label, "_", n_total))
  dir.create(pipeline_dir, showWarnings = FALSE)
  
  failed_batches <- c()
  for (i in seq_len(n_batches)) {
    out_path <- file.path(pipeline_dir, paste0("batch_", sprintf("%04d", i), ".rds"))
    if (file.exists(out_path)) {
      cat("Batch", i, "of", n_batches, "exists, skipping.\n")
      next
    }
    
    start_row <- (i - 1) * batch_size + 1
    end_row <- min(i * batch_size, n_total)
    batch <- reg_data[start_row:end_row, ]
    
    result <- tryCatch({
      batch |> extract_evi() |> extract_world_pop() |> extract_static() |> extract_lc_dist() |> extract_linear()
    }, error = function(e) {
      cat("BATCH", i, "FAILED:", conditionMessage(e), "\n")
      failed_batches <<- c(failed_batches, i)
      NULL
    })
    
    if (!is.null(result)) {
      saveRDS(result, out_path)
      cat("Batch", i, "of", n_batches, "done.\n")
    }
    rm(batch, result)
    gc()
  }
  cat("\nFailed batches:", paste(failed_batches, collapse = ", "), "\n")
  
  pipeline_files <- list.files(pipeline_dir, pattern = "batch_.*\\.rds", full.names = TRUE)
  combined <- map_dfr(pipeline_files, readRDS)
  stopifnot(nrow(combined) == n_total)
  combined
}

ele_trk_extract_west <- run_batched_pipeline(ele_west_reg, "west_hr6")
saveRDS(ele_trk_extract_west, here("outputs", "ele_trk_extract_west.rds"))

cat("\n=== WEST EXTRACTION COMPLETE ===\n")
cat("Final row count:", nrow(ele_trk_extract_west), "\n")

