library(data.table)
library(haven)
library(syuzhet)

RUN_ID <- "260606"
BASE_PANEL <- "core_simi_panel_260501_with_mr_text_sentiment_260526.dta"

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

parse_idate <- function(x) {
  x <- as.character(x)
  x[x == ""] <- NA_character_
  out <- suppressWarnings(as.IDate(x, format = "%Y-%m-%d"))
  miss <- is.na(out) & !is.na(x)
  if (any(miss)) out[miss] <- suppressWarnings(as.IDate(x[miss], format = "%Y/%m/%d"))
  miss <- is.na(out) & !is.na(x)
  if (any(miss)) out[miss] <- suppressWarnings(as.IDate(substr(x[miss], 1, 10), format = "%Y-%m-%d"))
  miss <- is.na(out) & !is.na(x)
  if (any(miss)) out[miss] <- suppressWarnings(as.IDate(substr(x[miss], 1, 10), format = "%Y/%m/%d"))
  out
}

text_words <- function(x) {
  x <- as.character(x)
  out <- integer(length(x))
  idx <- which(!is.na(x) & nzchar(trimws(x)))
  if (length(idx) > 0) {
    hits <- gregexpr("\\S+", x[idx], perl = TRUE)
    out[idx] <- as.integer(lengths(regmatches(x[idx], hits)))
  }
  out
}

window_sent_summary <- function(dt, rows) {
  out <- list(
    review_count = NA_real_,
    sent_text_review_count = NA_real_,
    sent_any_text = NA_real_,
    sent_avg_bing = NA_real_,
    sent_pos_share_bing = NA_real_,
    sent_neg_share_bing = NA_real_,
    sent_net_pos_bing = NA_real_
  )
  if (length(rows) == 0L) return(out)

  text_rows <- rows[dt$has_text[rows] == 1L]
  text_n <- length(text_rows)
  out$review_count <- length(rows)
  out$sent_text_review_count <- text_n
  out$sent_any_text <- as.integer(text_n > 0L)
  if (text_n == 0L) {
    out$sent_avg_bing <- 0
    out$sent_pos_share_bing <- 0
    out$sent_neg_share_bing <- 0
    out$sent_net_pos_bing <- 0
    return(out)
  }

  out$sent_avg_bing <- mean(dt$sent_bing[text_rows], na.rm = TRUE)
  out$sent_pos_share_bing <- mean(dt$sent_positive_bing[text_rows], na.rm = TRUE)
  out$sent_neg_share_bing <- mean(dt$sent_negative_bing[text_rows], na.rm = TRUE)
  out$sent_net_pos_bing <- out$sent_pos_share_bing - out$sent_neg_share_bing
  out
}

build_for_hotel <- function(h_reviews, h_panel) {
  h_panel[, `:=`(
    sent_review_count_10 = NA_real_,
    sent_text_review_count_10 = NA_real_,
    sent_any_text_10 = NA_real_,
    sent_avg_bing_10 = NA_real_,
    sent_pos_share_bing_10 = NA_real_,
    sent_neg_share_bing_10 = NA_real_,
    sent_net_pos_bing_10 = NA_real_,
    ln_sent_text_review_count_10 = NA_real_,
    prevvis_review_count = NA_real_,
    prevvis_recent_rating = NA_real_,
    prevvis_recent_sd = NA_real_,
    prevvis_sent_review_count = NA_real_,
    prevvis_sent_text_review_count = NA_real_,
    prevvis_sent_any_text = NA_real_,
    prevvis_sent_avg_bing = NA_real_,
    prevvis_sent_pos_share_bing = NA_real_,
    prevvis_sent_neg_share_bing = NA_real_,
    prevvis_sent_net_pos_bing = NA_real_,
    ln_prevvis_sent_text_n = NA_real_,
    prevvis_gap_months = NA_real_,
    prevvis_source_year = NA_real_,
    prevvis_source_mon = NA_real_
  )]
  if (nrow(h_reviews) == 0L) return(h_panel)

  setorder(h_reviews, review_date, ReviewID)
  review_dates <- as.integer(h_reviews$review_date)
  review_month_id <- h_reviews$review_year * 12L + h_reviews$review_mon
  ratings <- h_reviews$review_rating_num

  for (i in seq_len(nrow(h_panel))) {
    current_month_id <- h_panel$Year[i] * 12L + h_panel$Mon[i]
    before_idx <- which(review_dates < as.integer(h_panel$month_start[i]))
    month_idx <- which(
      review_dates >= as.integer(h_panel$month_start[i]) &
        review_dates <= as.integer(h_panel$month_end[i])
    )
    scope_rows <- unique(c(tail(before_idx, 10L), month_idx))
    sent_scope <- window_sent_summary(h_reviews, scope_rows)
    h_panel[i, `:=`(
      sent_review_count_10 = sent_scope$review_count,
      sent_text_review_count_10 = sent_scope$sent_text_review_count,
      sent_any_text_10 = sent_scope$sent_any_text,
      sent_avg_bing_10 = sent_scope$sent_avg_bing,
      sent_pos_share_bing_10 = sent_scope$sent_pos_share_bing,
      sent_neg_share_bing_10 = sent_scope$sent_neg_share_bing,
      sent_net_pos_bing_10 = sent_scope$sent_net_pos_bing,
      ln_sent_text_review_count_10 = if (!is.na(sent_scope$sent_text_review_count)) log(sent_scope$sent_text_review_count + 1) else NA_real_
    )]

    prev_months <- review_month_id[review_month_id < current_month_id]
    if (length(prev_months) == 0L) next
    prev_month_id <- max(prev_months, na.rm = TRUE)
    prev_rows <- which(review_month_id == prev_month_id)
    prev_sent <- window_sent_summary(h_reviews, prev_rows)
    prev_year <- h_reviews$review_year[prev_rows[1]]
    prev_mon <- h_reviews$review_mon[prev_rows[1]]
    prev_gap <- current_month_id - prev_month_id
    h_panel[i, `:=`(
      prevvis_review_count = length(prev_rows),
      prevvis_recent_rating = mean(ratings[prev_rows], na.rm = TRUE),
      prevvis_recent_sd = if (length(prev_rows) > 1L) sd(ratings[prev_rows], na.rm = TRUE) else NA_real_,
      prevvis_sent_review_count = prev_sent$review_count,
      prevvis_sent_text_review_count = prev_sent$sent_text_review_count,
      prevvis_sent_any_text = prev_sent$sent_any_text,
      prevvis_sent_avg_bing = prev_sent$sent_avg_bing,
      prevvis_sent_pos_share_bing = prev_sent$sent_pos_share_bing,
      prevvis_sent_neg_share_bing = prev_sent$sent_neg_share_bing,
      prevvis_sent_net_pos_bing = prev_sent$sent_net_pos_bing,
      ln_prevvis_sent_text_n = if (!is.na(prev_sent$sent_text_review_count)) log(prev_sent$sent_text_review_count + 1) else NA_real_,
      prevvis_gap_months = prev_gap,
      prevvis_source_year = prev_year,
      prevvis_source_mon = prev_mon
    )]
  }

  h_panel
}

project_dir <- detect_project_dir()
out_root <- file.path(project_dir, "outputs/core_simi_260501")
data_dir <- file.path(out_root, "data")
csv_dir <- file.path(out_root, "csv")
log_dir <- file.path(out_root, "logs")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

path_tp <- file.path(project_dir, "full-data/tp_data_new.csv")
path_panel <- file.path(data_dir, BASE_PANEL)
path_scope10 <- file.path(data_dir, sprintf("review_environment_scope10_%s.dta", RUN_ID))
path_panel_out <- path_panel
path_audit <- file.path(csv_dir, sprintf("review_environment_scope10_audit_%s.csv", RUN_ID))
path_log <- file.path(log_dir, sprintf("build_review_environment_scope10_%s.log", RUN_ID))

assert_inside_project(c(path_scope10, path_panel_out, path_audit, path_log), project_dir)

sink(path_log, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Build aligned review-environment variables:", as.character(Sys.time()), "\n")
cat("Project:", project_dir, "\n")
cat("Review source:", path_tp, "\n")
cat("Panel source:", path_panel, "\n")

for (p in c(path_tp, path_panel)) {
  if (!file.exists(p)) stop("Missing required input: ", p)
}

panel <- as.data.table(read_dta(path_panel))
panel[, HotelID := as.character(HotelID)]
panel[, Year := as.integer(Year)]
panel[, Mon := as.integer(Mon)]
if (!"year_month" %in% names(panel)) {
  panel[, year_month := sprintf("%04d-%02d", Year, Mon)]
}
panel[, month_start := as.IDate(sprintf("%04d-%02d-01", Year, Mon))]
panel[, month_end := as.IDate(format(as.Date(month_start) + 31, "%Y-%m-01")) - 1L]

panel_key <- unique(panel[, .(HotelID, Year, Mon, year_month, month_start, month_end)])
if (anyDuplicated(panel_key, by = c("HotelID", "Year", "Mon")) > 0) {
  stop("Panel key is not unique by HotelID-Year-Mon.")
}
panel[, c("month_start", "month_end") := NULL]

tp_header <- names(fread(path_tp, nrows = 0, showProgress = FALSE))
tp_cols <- intersect(c("HotelID", "ReviewID", "review_date", "review_rating", "review_text", "year", "month"), tp_header)
missing_tp <- setdiff(c("HotelID", "ReviewID", "review_text"), tp_cols)
if (length(missing_tp) > 0) stop("tp_data_new is missing: ", paste(missing_tp, collapse = ", "))

reviews <- fread(
  path_tp,
  select = tp_cols,
  showProgress = TRUE,
  colClasses = c(HotelID = "character", ReviewID = "character", review_text = "character")
)
if ("year" %in% names(reviews)) setnames(reviews, "year", "review_year")
if ("month" %in% names(reviews)) setnames(reviews, "month", "review_mon")

reviews[, HotelID := as.character(HotelID)]
reviews[, ReviewID := as.character(ReviewID)]
reviews[, review_date := if ("review_date" %in% names(reviews)) parse_idate(review_date) else as.IDate(NA)]
if (!"review_year" %in% names(reviews)) reviews[, review_year := as.integer(format(review_date, "%Y"))]
if (!"review_mon" %in% names(reviews)) reviews[, review_mon := as.integer(format(review_date, "%m"))]
reviews[, review_year := as.integer(review_year)]
reviews[, review_mon := as.integer(review_mon)]
reviews[is.na(review_date) & !is.na(review_year) & !is.na(review_mon), review_date := as.IDate(sprintf("%04d-%02d-15", review_year, review_mon))]
reviews <- reviews[
  HotelID %in% panel_key$HotelID &
    !is.na(HotelID) & HotelID != "" &
    !is.na(ReviewID) & ReviewID != "" &
    !is.na(review_date)
]
setorder(reviews, ReviewID, HotelID)
dup_n <- reviews[, .N, by = ReviewID][N > 1L, .N]
reviews <- unique(reviews, by = "ReviewID")
setorder(reviews, HotelID, review_date, ReviewID)

reviews[, review_text_clean := as.character(review_text)]
reviews[is.na(review_text_clean), review_text_clean := ""]
reviews[, review_text_words := text_words(review_text_clean)]
reviews[, has_text := as.integer(review_text_words > 0L)]
reviews[, review_rating_num := suppressWarnings(as.numeric(review_rating))]

text_idx <- which(reviews$has_text == 1L)
reviews[, sent_bing := as.numeric(NA)]
if (length(text_idx) > 0L) {
  cat("Scoring Bing sentiment for", length(text_idx), "review texts...\n")
  reviews[text_idx, sent_bing := get_sentiment(review_text_clean[text_idx], method = "bing")]
}
reviews[, sent_positive_bing := as.integer(sent_bing > 0)]
reviews[, sent_negative_bing := as.integer(sent_bing < 0)]

cat("Panel rows:", nrow(panel), "\n")
cat("Panel hotels:", uniqueN(panel$HotelID), "\n")
cat("Review rows after ReviewID dedup:", nrow(reviews), "\n")
cat("Review rows with text:", sum(reviews$has_text, na.rm = TRUE), "\n")
cat("Duplicate ReviewIDs removed:", dup_n, "\n")

hotel_ids <- sort(unique(panel_key$HotelID))
result_list <- vector("list", length(hotel_ids))
for (k in seq_along(hotel_ids)) {
  h <- hotel_ids[k]
  if (k %% 100L == 0L) cat("Processing hotel", k, "of", length(hotel_ids), "\n")
  h_reviews <- reviews[HotelID == h]
  h_panel <- copy(panel_key[HotelID == h])
  result_list[[k]] <- build_for_hotel(h_reviews, h_panel)
}

scope10_env <- rbindlist(result_list, use.names = TRUE, fill = TRUE)
setorder(scope10_env, HotelID, Year, Mon)

merge_cols <- setdiff(names(scope10_env), c("HotelID", "Year", "Mon", "year_month", "month_start", "month_end"))
drop_existing <- intersect(merge_cols, names(panel))
if (length(drop_existing) > 0L) {
  panel[, (drop_existing) := NULL]
}
scope10_merge <- scope10_env[, !c("month_start", "month_end")]
panel_out <- merge(panel, scope10_merge, by = c("HotelID", "Year", "Mon", "year_month"), all.x = TRUE, sort = FALSE)
setorder(panel_out, HotelID, Year, Mon)
if (nrow(panel_out) != nrow(panel)) stop("Merged panel row count changed.")

audit_vars <- c(
  "sent_review_count_10", "sent_text_review_count_10", "sent_any_text_10",
  "sent_avg_bing_10", "sent_neg_share_bing_10", "sent_net_pos_bing_10",
  "prevvis_review_count", "prevvis_recent_rating", "prevvis_recent_sd",
  "prevvis_sent_text_review_count", "prevvis_sent_any_text",
  "prevvis_sent_avg_bing", "prevvis_sent_neg_share_bing", "prevvis_sent_net_pos_bing",
  "prevvis_gap_months"
)
audit <- rbindlist(lapply(audit_vars, function(v) {
  x <- panel_out[[v]]
  data.table(
    variable = v,
    n_total = length(x),
    n_nonmissing = sum(!is.na(x)),
    missing_rate = mean(is.na(x)),
    mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    min = suppressWarnings(min(x, na.rm = TRUE)),
    median = suppressWarnings(median(x, na.rm = TRUE)),
    max = suppressWarnings(max(x, na.rm = TRUE))
  )
}))

write_dta(scope10_merge, path_scope10, version = 14)
write_dta(panel_out, path_panel_out, version = 14)
fwrite(audit, path_audit)

cat("Wrote:", path_scope10, "\n")
cat("Updated:", path_panel_out, "\n")
cat("Wrote:", path_audit, "\n")
