library(data.table)
library(haven)
library(lubridate)

RUN_ID <- "260509"
SCOPES <- c(5L, 10L, 15L, 20L, 30L)
VECTOR_DIMS <- paste0("V", 0:199)
BATCH_SIZE <- 50L

detect_project_dir <- function() {
  candidates <- unique(c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE),
    "/Users/samxie/Research/ReviewSimi_Sales/Code"
  ))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "Paper_Results_260407.md")) &&
        dir.exists(file.path(candidate, "scripts")) &&
        dir.exists(file.path(candidate, "outputs"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Cannot locate project root.")
}

assert_inside_project <- function(paths, project_dir) {
  root <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  normalized <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  outside <- normalized[!startsWith(normalized, paste0(root, "/")) & normalized != root]
  if (length(outside) > 0) {
    stop(paste("Refusing to write outside project root:", paste(outside, collapse = ", ")))
  }
  invisible(TRUE)
}

mean_pairwise_cosine <- function(mat_input) {
  if (is.null(mat_input) || length(mat_input) == 0) return(NA_real_)
  mat <- as.matrix(mat_input)
  storage.mode(mat) <- "double"
  if (nrow(mat) < 2) return(NA_real_)
  norms <- sqrt(rowSums(mat * mat))
  keep <- is.finite(norms) & norms > 0
  mat <- mat[keep, , drop = FALSE]
  norms <- norms[keep]
  n <- nrow(mat)
  if (n < 2) return(NA_real_)
  mat <- mat / norms
  (sum(tcrossprod(mat)) - n) / (n * (n - 1))
}

empty_scope_row <- function(h_panel) {
  out <- copy(h_panel)
  for (scope in SCOPES) {
    out[, paste0("sim_mean_", scope) := NA_real_]
    out[, paste0("recent_volumn_", scope) := NA_real_]
    out[, paste0("recent_sd_", scope) := NA_real_]
    out[, paste0("recent_rating_", scope) := NA_real_]
  }
  out
}

build_scope_for_hotel <- function(h_reviews, h_panel) {
  h_panel <- empty_scope_row(h_panel)
  if (nrow(h_reviews) == 0) return(h_panel)

  setorder(h_reviews, RatingDate, ReviewID)
  h_dates <- as.integer(h_reviews$RatingDate)
  x <- as.matrix(h_reviews[, ..VECTOR_DIMS])
  storage.mode(x) <- "double"
  ratings <- as.numeric(h_reviews$ReviewRating)

  for (i in seq_len(nrow(h_panel))) {
    before_idx <- which(h_dates < as.integer(h_panel$month_start[i]))
    month_idx <- which(
      h_dates >= as.integer(h_panel$month_start[i]) &
        h_dates <= as.integer(h_panel$month_end[i])
    )

    for (scope in SCOPES) {
      rows <- unique(c(tail(before_idx, scope), month_idx))
      if (length(rows) == 0) next
      h_panel[i, paste0("recent_volumn_", scope) := length(rows)]
      h_panel[i, paste0("recent_rating_", scope) := mean(ratings[rows], na.rm = TRUE)]
      h_panel[i, paste0("recent_sd_", scope) := if (length(rows) > 1) sd(ratings[rows], na.rm = TRUE) else NA_real_]
      h_panel[i, paste0("sim_mean_", scope) := mean_pairwise_cosine(x[rows, , drop = FALSE])]
    }
  }
  h_panel
}

project_dir <- detect_project_dir()
base_dir <- normalizePath(file.path(project_dir, ".."), winslash = "/", mustWork = TRUE)
out_root <- file.path(project_dir, "outputs/core_simi_260501")
data_dir <- file.path(out_root, "data")
csv_dir <- file.path(out_root, "csv")
log_dir <- file.path(out_root, "logs")
checkpoint_dir <- file.path(out_root, "checkpoints/ars_scope_260509")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)

path_panel <- file.path(data_dir, "core_simi_panel_260501.dta")
path_filtered_vectors <- file.path(base_dir, "Data/review_vector_filtered0118.csv")
path_full_vectors <- file.path(base_dir, "1209new/TP_texas_data/reviews_texas_en_doc2vec200_joined.csv")
path_scope_only <- file.path(data_dir, "ars_scope_5_10_15_20_30_260509.dta")
path_panel_scope <- file.path(data_dir, "core_simi_panel_260501_with_scope_ars.dta")
path_audit <- file.path(csv_dir, "ars_scope_audit_260509.csv")
path_log <- file.path(log_dir, "build_scope_ars_260509.log")

assert_inside_project(c(path_scope_only, path_panel_scope, path_audit, path_log, checkpoint_dir), project_dir)

sink(path_log, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Build multi-scope ARS robustness variables:", as.character(Sys.time()), "\n")
cat("Project:", project_dir, "\n")

if (!file.exists(path_panel)) stop("Cannot find current panel: ", path_panel)
vector_path <- if (file.exists(path_filtered_vectors)) path_filtered_vectors else path_full_vectors
if (!file.exists(vector_path)) stop("Cannot find review vector CSV.")
cat("Vector source:", vector_path, "\n")

panel <- as.data.table(read_dta(path_panel))
panel[, HotelID := as.character(HotelID)]
panel[, Year := as.integer(Year)]
panel[, Mon := as.integer(Mon)]
panel[, month_start := as.Date(sprintf("%04d-%02d-01", Year, Mon))]
panel[, month_end := ceiling_date(month_start, "month") - days(1)]
panel_key <- unique(panel[, .(HotelID, Year, Mon, year_month, month_start, month_end)])
setorder(panel_key, HotelID, Year, Mon)

if (anyDuplicated(panel[, .(HotelID, Year, Mon)]) > 0) {
  stop("Current panel is not unique by HotelID-Year-Mon.")
}

header <- names(fread(vector_path, nrows = 0))
date_col <- intersect(c("Review_Published_Date", "ReviewDate", "RatingDate"), header)[1]
rating_col <- intersect(c("ReviewRating", "Review_Rating", "AvgRatingStarsThisUser"), header)[1]
if (is.na(date_col)) stop("Cannot find review date column in vector file.")
if (is.na(rating_col)) stop("Cannot find review rating column in vector file.")
missing_dims <- setdiff(VECTOR_DIMS, header)
if (length(missing_dims) > 0) stop("Missing vector columns: ", paste(missing_dims, collapse = ", "))

select_cols <- c("HotelID", "ReviewID", VECTOR_DIMS, date_col, rating_col)
cat("Reading review vectors with", length(select_cols), "columns...\n")
reviews <- fread(vector_path, select = select_cols, showProgress = TRUE)
setnames(reviews, date_col, "RatingDate")
setnames(reviews, rating_col, "ReviewRating")
reviews[, HotelID := as.character(HotelID)]
reviews[, ReviewID := as.character(ReviewID)]
reviews[, RatingDate := as.Date(RatingDate)]
reviews[, ReviewRating := as.numeric(ReviewRating)]
reviews <- reviews[
  HotelID %in% panel_key$HotelID &
    !is.na(RatingDate) &
    RatingDate <= max(panel_key$month_end, na.rm = TRUE)
]
reviews <- unique(reviews, by = "ReviewID")
setorder(reviews, HotelID, RatingDate, ReviewID)

cat("Panel rows:", nrow(panel), "\n")
cat("Panel hotels:", uniqueN(panel$HotelID), "\n")
cat("Review-vector rows after filtering:", nrow(reviews), "\n")
cat("Review-vector hotels after filtering:", uniqueN(reviews$HotelID), "\n")

hotel_ids <- sort(unique(panel_key$HotelID))
batches <- split(hotel_ids, ceiling(seq_along(hotel_ids) / BATCH_SIZE))

for (b in seq_along(batches)) {
  checkpoint_path <- file.path(checkpoint_dir, sprintf("scope_batch_%03d.rds", b))
  if (file.exists(checkpoint_path)) {
    cat("Skipping existing checkpoint:", checkpoint_path, "\n")
    next
  }

  ids <- batches[[b]]
  cat("Processing batch", b, "of", length(batches), "hotels", length(ids), "\n")
  batch_result <- vector("list", length(ids))
  for (k in seq_along(ids)) {
    h <- ids[k]
    h_reviews <- reviews[HotelID == h]
    h_panel <- copy(panel_key[HotelID == h])
    batch_result[[k]] <- build_scope_for_hotel(h_reviews, h_panel)
  }
  batch_dt <- rbindlist(batch_result, use.names = TRUE, fill = TRUE)
  saveRDS(batch_dt, checkpoint_path)
  rm(batch_result, batch_dt)
  gc()
}

checkpoint_files <- list.files(checkpoint_dir, pattern = "^scope_batch_\\d+\\.rds$", full.names = TRUE)
if (length(checkpoint_files) != length(batches)) {
  stop("Missing checkpoint files. Expected ", length(batches), ", found ", length(checkpoint_files))
}

cat("Combining checkpoints...\n")
scope_ars <- rbindlist(lapply(sort(checkpoint_files), readRDS), use.names = TRUE, fill = TRUE)
setorder(scope_ars, HotelID, Year, Mon)

for (scope in SCOPES) {
  scope_ars[, paste0("ln_recent_volumn_", scope) := fifelse(
    get(paste0("recent_volumn_", scope)) > 0,
    log(get(paste0("recent_volumn_", scope))),
    NA_real_
  )]
  scope_ars[, paste0("lag_sim_mean_", scope) := shift(get(paste0("sim_mean_", scope)), 1L), by = HotelID]
}

scope_keep_cols <- c(
  "HotelID", "Year", "Mon", "year_month",
  unlist(lapply(SCOPES, function(scope) {
    c(
      paste0("sim_mean_", scope),
      paste0("lag_sim_mean_", scope),
      paste0("recent_volumn_", scope),
      paste0("ln_recent_volumn_", scope),
      paste0("recent_sd_", scope),
      paste0("recent_rating_", scope)
    )
  }))
)
scope_keep <- scope_ars[, ..scope_keep_cols]

if (anyDuplicated(scope_keep[, .(HotelID, Year, Mon)]) > 0) {
  stop("Scope ARS output is not unique by HotelID-Year-Mon.")
}

scope_merge <- copy(scope_keep)
scope_merge[, year_month := NULL]
panel_scope <- merge(panel, scope_merge, by = c("HotelID", "Year", "Mon"), all.x = TRUE, sort = FALSE)
setorder(panel_scope, HotelID, Year, Mon)
if (nrow(panel_scope) != nrow(panel)) stop("Merged panel row count changed.")

audit_vars <- unlist(lapply(SCOPES, function(scope) {
  c(paste0("sim_mean_", scope), paste0("recent_volumn_", scope), paste0("recent_sd_", scope))
}))
audit <- rbindlist(lapply(audit_vars, function(v) {
  x <- panel_scope[[v]]
  data.table(
    variable = v,
    n_total = length(x),
    n_nonmissing = sum(!is.na(x)),
    missing_rate = mean(is.na(x)),
    mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    min = suppressWarnings(min(x, na.rm = TRUE)),
    median = median(x, na.rm = TRUE),
    max = suppressWarnings(max(x, na.rm = TRUE))
  )
}))

write_dta(scope_keep, path_scope_only, version = 14)
write_dta(panel_scope, path_panel_scope, version = 14)
fwrite(audit, path_audit)

cat("Wrote:", path_scope_only, "\n")
cat("Wrote:", path_panel_scope, "\n")
cat("Wrote:", path_audit, "\n")
cat("Done:", as.character(Sys.time()), "\n")
