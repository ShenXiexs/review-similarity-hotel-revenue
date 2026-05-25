library(data.table)
library(haven)
library(lubridate)

RUN_ID <- "260509"
VECTOR_DIMS <- paste0("V", 0:199)

detect_project_dir <- function() {
  candidates <- unique(c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE),
    "/Users/samxie/Research/ReviewSimi_Sales/Code"
  ))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "README.md")) &&
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
  sim_sum <- sum(tcrossprod(mat)) - n
  sim_sum / (n * (n - 1))
}

row_softmax <- function(mat) {
  mat <- as.matrix(mat)
  storage.mode(mat) <- "double"
  row_max <- apply(mat, 1, max, na.rm = TRUE)
  shifted <- mat - row_max
  exp_mat <- exp(shifted)
  denom <- rowSums(exp_mat)
  exp_mat / denom
}

entropy <- function(p) {
  p <- p[is.finite(p) & p > 0]
  if (length(p) == 0) return(NA_real_)
  -sum(p * log(p))
}

safe_weighted_mean <- function(x, w) {
  keep <- is.finite(x) & is.finite(w) & w > 0
  if (!any(keep)) return(NA_real_)
  weighted.mean(x[keep], w[keep])
}

js_distance <- function(mat_input) {
  if (is.null(mat_input) || length(mat_input) == 0) return(NA_real_)
  mat <- as.matrix(mat_input)
  storage.mode(mat) <- "double"
  mat <- mat[stats::complete.cases(mat), , drop = FALSE]
  if (nrow(mat) < 2) return(NA_real_)
  probs <- row_softmax(mat)
  mean_prob <- colMeans(probs)
  js_div <- entropy(mean_prob) - mean(apply(probs, 1, entropy))
  js_div <- max(js_div, 0)
  sqrt(js_div)
}

build_roll_for_hotel <- function(h_reviews, h_panel) {
  h_reviews <- h_reviews[order(RatingDate, ReviewID)]
  h_dates <- as.integer(h_reviews$RatingDate)
  x <- as.matrix(h_reviews[, ..VECTOR_DIMS])
  out <- numeric(nrow(h_panel))
  out[] <- NA_real_

  for (i in seq_len(nrow(h_panel))) {
    days <- seq(h_panel$month_start[i], h_panel$month_end[i], by = "day")
    idx_by_day <- findInterval(as.integer(days), h_dates)
    idx_by_day <- idx_by_day[idx_by_day >= 2]
    if (length(idx_by_day) == 0) next

    idx_weight <- table(idx_by_day)
    vals <- numeric(length(idx_weight))
    weights <- as.numeric(idx_weight)
    idx_values <- as.integer(names(idx_weight))

    for (j in seq_along(idx_values)) {
      idx <- idx_values[j]
      rows <- max(1L, idx - 9L):idx
      vals[j] <- mean_pairwise_cosine(x[rows, , drop = FALSE])
    }
    out[i] <- safe_weighted_mean(vals, weights)
  }

  h_panel[, ars_roll_10 := out]
  h_panel
}

build_jsd_for_hotel <- function(h_reviews, h_panel) {
  h_reviews <- h_reviews[order(RatingDate, ReviewID)]
  h_dates <- as.integer(h_reviews$RatingDate)
  x <- as.matrix(h_reviews[, ..VECTOR_DIMS])
  out <- numeric(nrow(h_panel))
  out[] <- NA_real_

  for (i in seq_len(nrow(h_panel))) {
    before_idx <- which(h_dates < as.integer(h_panel$month_start[i]))
    before_idx <- tail(before_idx, 10L)
    month_idx <- which(
      h_dates >= as.integer(h_panel$month_start[i]) &
        h_dates <= as.integer(h_panel$month_end[i])
    )
    rows <- unique(c(before_idx, month_idx))
    if (length(rows) < 2) next
    out[i] <- js_distance(x[rows, , drop = FALSE])
  }

  h_panel[, ars_jsd_distance := out]
  h_panel
}

project_dir <- detect_project_dir()
base_dir <- normalizePath(file.path(project_dir, ".."), winslash = "/", mustWork = TRUE)
out_root <- file.path(project_dir, "outputs/core_simi_260501")
data_dir <- file.path(out_root, "data")
csv_dir <- file.path(out_root, "csv")
log_dir <- file.path(out_root, "logs")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

path_panel <- file.path(data_dir, "core_simi_panel_260501.dta")
path_filtered_vectors <- file.path(base_dir, "Data/review_vector_filtered0118.csv")
path_full_vectors <- file.path(base_dir, "1209new/TP_texas_data/reviews_texas_en_doc2vec200_joined.csv")
path_alt_only <- file.path(data_dir, "ars_robustness_260509.dta")
path_panel_alt <- file.path(data_dir, "core_simi_panel_260501_with_altars.dta")
path_audit <- file.path(csv_dir, "ars_robustness_audit_260509.csv")
path_log <- file.path(log_dir, "build_alt_ars_260509.log")

assert_inside_project(c(path_alt_only, path_panel_alt, path_audit, path_log), project_dir)

sink(path_log, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Build alternative ARS robustness variables:", as.character(Sys.time()), "\n")
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
if (is.na(date_col)) stop("Cannot find review date column in vector file.")
missing_dims <- setdiff(VECTOR_DIMS, header)
if (length(missing_dims) > 0) stop("Missing vector columns: ", paste(missing_dims, collapse = ", "))

select_cols <- c("HotelID", "ReviewID", VECTOR_DIMS, date_col)
cat("Reading review vectors with", length(select_cols), "columns...\n")
reviews <- fread(vector_path, select = select_cols, showProgress = TRUE)
setnames(reviews, date_col, "RatingDate")
reviews[, HotelID := as.character(HotelID)]
reviews[, ReviewID := as.character(ReviewID)]
reviews[, RatingDate := as.Date(RatingDate)]
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

hotel_ids <- intersect(unique(panel_key$HotelID), unique(reviews$HotelID))
cat("Hotels with vectors:", length(hotel_ids), "\n")

result_list <- vector("list", length(hotel_ids))
for (k in seq_along(hotel_ids)) {
  h <- hotel_ids[k]
  if (k %% 25 == 0 || k == 1L || k == length(hotel_ids)) {
    cat("Processing hotel", k, "of", length(hotel_ids), ":", h, "\n")
  }
  h_reviews <- reviews[HotelID == h]
  h_panel <- copy(panel_key[HotelID == h])
  h_panel <- build_roll_for_hotel(h_reviews, h_panel)
  h_panel <- build_jsd_for_hotel(h_reviews, h_panel)
  result_list[[k]] <- h_panel
}

alt_ars <- rbindlist(result_list, use.names = TRUE, fill = TRUE)
alt_ars[, ars_jsd_sim := -10 * ars_jsd_distance]
setorder(alt_ars, HotelID, Year, Mon)
alt_ars[, lag_ars_roll_10 := shift(ars_roll_10, 1L), by = HotelID]
alt_ars[, lag_ars_jsd_sim := shift(ars_jsd_sim, 1L), by = HotelID]

alt_keep <- alt_ars[, .(
  HotelID, Year, Mon, year_month,
  ars_roll_10, lag_ars_roll_10,
  ars_jsd_distance, ars_jsd_sim, lag_ars_jsd_sim
)]

if (anyDuplicated(alt_keep[, .(HotelID, Year, Mon)]) > 0) {
  stop("Alternative ARS output is not unique by HotelID-Year-Mon.")
}

alt_merge <- copy(alt_keep)
alt_merge[, year_month := NULL]

panel_alt <- merge(
  panel,
  alt_merge,
  by = c("HotelID", "Year", "Mon"),
  all.x = TRUE,
  sort = FALSE
)
setorder(panel_alt, HotelID, Year, Mon)
if (nrow(panel_alt) != nrow(panel)) stop("Merged panel row count changed.")

audit_vars <- c("sim_mean", "lag_sim_mean", "ars_roll_10", "lag_ars_roll_10", "ars_jsd_distance", "ars_jsd_sim", "lag_ars_jsd_sim")
audit <- rbindlist(lapply(audit_vars, function(v) {
  x <- panel_alt[[v]]
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

write_dta(alt_keep, path_alt_only, version = 14)
write_dta(panel_alt, path_panel_alt, version = 14)
fwrite(audit, path_audit)

cat("Wrote:", path_alt_only, "\n")
cat("Wrote:", path_panel_alt, "\n")
cat("Wrote:", path_audit, "\n")
cat("Done:", as.character(Sys.time()), "\n")
