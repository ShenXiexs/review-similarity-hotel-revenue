#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(haven)
  library(lubridate)
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
all_review_path <- file.path(root, "full-data/allTPreview.csv")
vector_path <- file.path(root, "../Data/review_vector_filtered0118.csv")
audit_path <- file.path(
  root, "outputs/core_simi_260501/csv",
  "routeAB_helpfulness_mediation_audit_260826.csv"
)

stopifnot(
  all(file.exists(canonical_paths)),
  file.exists(all_review_path),
  file.exists(vector_path)
)

panel <- as.data.table(read_dta(panel_path))
panel[, `:=`(
  HotelID = as.character(HotelID),
  Year = as.integer(Year),
  Mon = as.integer(Mon)
)]
panel[, month_start := as.IDate(sprintf("%04d-%02d-01", Year, Mon))]
panel[, month_end := as.IDate(ceiling_date(as.Date(month_start), "month") - days(1))]
panel_key <- unique(panel[, .(HotelID, Year, Mon, month_start, month_end)])
stopifnot(!anyDuplicated(panel_key, by = c("HotelID", "Year", "Mon")))

vector_header <- names(fread(vector_path, nrows = 0L, showProgress = FALSE))
date_col <- intersect(c("Review_Published_Date", "ReviewDate", "RatingDate"), vector_header)[1]
if (is.na(date_col)) stop("No review-date field in vector source.")

reviews <- fread(
  vector_path,
  select = c("HotelID", "ReviewID", date_col),
  colClasses = c(HotelID = "character", ReviewID = "character"),
  showProgress = TRUE
)
setnames(reviews, date_col, "RatingDate")
reviews[, RatingDate := as.IDate(RatingDate)]
reviews <- reviews[
  HotelID %chin% unique(panel$HotelID) &
    !is.na(ReviewID) & ReviewID != "" & !is.na(RatingDate)
]
setorder(reviews, ReviewID, HotelID, RatingDate)
reviews <- unique(reviews, by = "ReviewID")

help <- fread(
  all_review_path,
  select = c("location_id", "review_id", "review_helpful"),
  colClasses = c(location_id = "character", review_id = "character"),
  showProgress = TRUE
)
setnames(
  help,
  c("location_id", "review_id", "review_helpful"),
  c("HotelID", "ReviewID", "help_votes")
)
help[, help_votes := suppressWarnings(as.numeric(help_votes))]
help[help_votes < 0, help_votes := NA_real_]
help <- help[!is.na(ReviewID) & ReviewID != ""]
help <- help[, .(
  help_votes = if (all(is.na(help_votes))) NA_real_ else max(help_votes, na.rm = TRUE)
), by = .(HotelID, ReviewID)]

reviews <- merge(
  reviews, help,
  by = c("HotelID", "ReviewID"),
  all.x = TRUE,
  sort = FALSE
)
setorder(reviews, HotelID, RatingDate, ReviewID)
scrape_date_proxy <- max(reviews$RatingDate, na.rm = TRUE) + 1L

build_hotel <- function(h_reviews, h_panel) {
  h_panel[, `:=`(
    scope10_help_review_n = NA_real_,
    scope10_help_nonmissing_n = NA_real_,
    avg_helpfulness_scope10 = NA_real_,
    ln_avg_helpfulness_scope10 = NA_real_,
    scope10_help_zero_share = NA_real_,
    scope10_avg_review_age_days = NA_real_
  )]
  if (nrow(h_reviews) == 0L) return(h_panel)

  review_dates <- as.integer(h_reviews$RatingDate)
  for (i in seq_len(nrow(h_panel))) {
    before_idx <- which(review_dates < as.integer(h_panel$month_start[i]))
    month_idx <- which(
      review_dates >= as.integer(h_panel$month_start[i]) &
        review_dates <= as.integer(h_panel$month_end[i])
    )
    rows <- unique(c(tail(before_idx, 10L), month_idx))
    if (length(rows) == 0L) next

    votes <- h_reviews$help_votes[rows]
    valid <- !is.na(votes)
    avg_help <- if (any(valid)) mean(votes[valid]) else NA_real_
    h_panel[i, `:=`(
      scope10_help_review_n = length(rows),
      scope10_help_nonmissing_n = sum(valid),
      avg_helpfulness_scope10 = avg_help,
      ln_avg_helpfulness_scope10 = if (!is.na(avg_help)) log1p(avg_help) else NA_real_,
      scope10_help_zero_share = if (any(valid)) mean(votes[valid] == 0) else NA_real_,
      scope10_avg_review_age_days = mean(
        as.integer(scrape_date_proxy - h_reviews$RatingDate[rows])
      )
    )]
  }
  h_panel
}

hotel_ids <- sort(unique(panel_key$HotelID))
mediation_vars <- rbindlist(lapply(hotel_ids, function(hotel_id) {
  build_hotel(
    reviews[HotelID == hotel_id],
    copy(panel_key[HotelID == hotel_id])
  )
}))

mediation_vars[, c("month_start", "month_end") := NULL]

mediator_names <- c(
  "scope10_help_review_n", "scope10_help_nonmissing_n",
  "avg_helpfulness_scope10", "ln_avg_helpfulness_scope10",
  "scope10_help_zero_share", "scope10_avg_review_age_days",
  "scope10_count_difference"
)

update_canonical <- function(path) {
  target <- as.data.table(read_dta(path))
  original_n <- nrow(target)
  target[, `:=`(
    HotelID = as.character(HotelID),
    Year = as.integer(Year),
    Mon = as.integer(Mon)
  )]
  target[, (intersect(mediator_names, names(target))) := NULL]
  target <- merge(
    target, mediation_vars,
    by = c("HotelID", "Year", "Mon"),
    all.x = TRUE,
    sort = FALSE
  )
  setorder(target, HotelID, Year, Mon)
  stopifnot(nrow(target) == original_n)
  stopifnot(!anyDuplicated(target, by = c("HotelID", "Year", "Mon")))

  if ("recent_volumn_10" %in% names(target)) {
    target[, scope10_count_difference := scope10_help_review_n - recent_volumn_10]
  }

  for (v in intersect(mediator_names, names(target))) {
    x <- target[[v]]
    attr(x, "label") <- switch(v,
      scope10_help_review_n = "Reviews in ARS-aligned Scope-10 pool",
      scope10_help_nonmissing_n = "Reviews with observed helpful votes",
      avg_helpfulness_scope10 = "Average helpful votes in ARS-aligned Scope-10 pool",
      ln_avg_helpfulness_scope10 = "ln(1 + average helpful votes), Scope-10 pool",
      scope10_help_zero_share = "Share of Scope-10 reviews with zero helpful votes",
      scope10_avg_review_age_days = "Average review age at extraction proxy, days",
      scope10_count_difference = "Scope-10 helpfulness count minus existing recent volume"
    )
    target[[v]] <- x
  }

  tmp_path <- paste0(path, ".tmp")
  write_dta(target, tmp_path, version = 14)
  check <- as.data.table(read_dta(tmp_path, col_select = c("HotelID", "Year", "Mon")))
  stopifnot(nrow(check) == original_n)
  stopifnot(file.rename(tmp_path, path))
  target
}

updated <- lapply(canonical_paths, update_canonical)
panel_out <- updated[[1L]]

audit_vars <- intersect(mediator_names, names(panel_out))
audit <- rbindlist(lapply(audit_vars, function(v) {
  x <- panel_out[[v]]
  data.table(
    variable = v,
    N = length(x),
    nonmissing = sum(!is.na(x)),
    mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    median = median(x, na.rm = TRUE),
    max = max(x, na.rm = TRUE)
  )
}))

fwrite(audit, audit_path)

cat("Updated canonical datasets:\n", paste(canonical_paths, collapse = "\n"), "\n")
cat("Wrote:", audit_path, "\n")
cat("Rows:", nrow(panel_out), "Hotels:", uniqueN(panel_out$HotelID), "\n")
cat(
  "Focus100 rows with aligned helpfulness:",
  panel_out[cs_sample_focus100 == 1 & !is.na(ln_avg_helpfulness_scope10), .N],
  "\n"
)
