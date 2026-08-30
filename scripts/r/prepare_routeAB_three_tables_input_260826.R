#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(haven)
})

root <- "/Users/samxie/Research/ReviewSimi_Sales/Code"
panel_path <- file.path(
  root, "outputs/core_simi_260501/data",
  "routeAB_heterogeneity_final_260715.dta"
)
canonical_paths <- c(
  panel_path,
  file.path(
    root, "outputs/core_simi_260501/data",
    "routeAB_heterogeneity_final_260715_before_scope10mr_260717.dta"
  )
)
review_path <- file.path(root, "full-data/tp_data_new.csv")
stopifnot(all(file.exists(canonical_paths)), file.exists(review_path))

panel <- as.data.table(read_dta(panel_path))
panel[, HotelID := as.character(HotelID)]
panel[, panel_ym := as.integer(Year) * 12L + as.integer(Mon)]

reviews <- fread(
  review_path,
  select = c("HotelID", "ReviewID", "review_date", "help_votes"),
  colClasses = c(HotelID = "character", ReviewID = "character"),
  showProgress = TRUE
)
reviews <- reviews[HotelID %chin% unique(panel$HotelID)]
reviews[, review_date := as.IDate(review_date)]
reviews[, help_votes := suppressWarnings(as.numeric(help_votes))]
reviews[help_votes < 0, help_votes := NA_real_]
reviews <- reviews[!is.na(review_date) & !is.na(help_votes)]
reviews[, help_ym := as.integer(format(review_date, "%Y")) * 12L +
  as.integer(format(review_date, "%m"))]

help_month <- reviews[, .(
  help_sum = sum(help_votes),
  help_n = .N
), by = .(HotelID, help_ym)]
setorder(help_month, HotelID, help_ym)
help_month[, `:=`(
  help_cum_sum = cumsum(help_sum),
  help_cum_n = cumsum(help_n)
), by = HotelID]

panel_keys <- unique(panel[, .(HotelID, panel_ym)])
panel_keys[, cutoff_ym := panel_ym - 1L]
help_map <- help_month[
  panel_keys,
  on = .(HotelID, help_ym <= cutoff_ym),
  mult = "last",
  .(
    HotelID = i.HotelID,
    panel_ym = i.panel_ym,
    lag_helpful_review_n = help_cum_n,
    lag_avg_helpfulness_acc = help_cum_sum / help_cum_n
  )
]

legacy_names <- c("lag_helpful_review_n", "lag_avg_helpfulness_acc")

update_canonical <- function(path) {
  target <- as.data.table(read_dta(path))
  original_n <- nrow(target)
  target[, `:=`(
    HotelID = as.character(HotelID),
    Year = as.integer(Year),
    Mon = as.integer(Mon),
    panel_ym = as.integer(Year) * 12L + as.integer(Mon)
  )]
  target[, (intersect(legacy_names, names(target))) := NULL]
  target <- merge(
    target, help_map,
    by = c("HotelID", "panel_ym"),
    all.x = TRUE,
    sort = FALSE
  )
  target[, panel_ym := NULL]
  setorder(target, HotelID, Year, Mon)
  stopifnot(nrow(target) == original_n)
  stopifnot(!anyDuplicated(target, by = c("HotelID", "Year", "Mon")))

  attr(target$lag_helpful_review_n, "label") <-
    "LEGACY TP source: reviews underlying lagged helpfulness"
  attr(target$lag_avg_helpfulness_acc, "label") <-
    "LEGACY TP source: lagged accumulated mean helpful votes"

  tmp_path <- paste0(path, ".tmp")
  write_dta(target, tmp_path, version = 14)
  check <- as.data.table(read_dta(tmp_path, col_select = c("HotelID", "Year", "Mon")))
  stopifnot(nrow(check) == original_n)
  stopifnot(file.rename(tmp_path, path))
  target
}

updated <- lapply(canonical_paths, update_canonical)
panel_out <- updated[[1L]]
cat("Updated canonical datasets:\n", paste(canonical_paths, collapse = "\n"), "\n")
cat("Rows:", nrow(panel_out), "Hotels:", uniqueN(panel_out$HotelID), "\n")
cat(
  "Focus100 rows with legacy helpfulness:",
  panel_out[cs_sample_focus100 == 1 & !is.na(lag_avg_helpfulness_acc), .N],
  "\n"
)
