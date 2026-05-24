library(data.table)
library(haven)

RUN_ID <- "260524"

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

has_arg <- function(flag) flag %in% commandArgs(trailingOnly = TRUE)

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

text_chars <- function(x) {
  x <- as.character(x)
  out <- integer(length(x))
  idx <- which(!is.na(x) & nzchar(x))
  if (length(idx) > 0) {
    val <- suppressWarnings(nchar(x[idx], type = "chars", allowNA = TRUE))
    val[is.na(val)] <- 0L
    out[idx] <- as.integer(val)
  }
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

zfill_na <- function(dt, vars, value = 0) {
  for (v in vars) {
    if (v %in% names(dt)) set(dt, which(is.na(dt[[v]])), v, value)
  }
  invisible(dt)
}

project_dir <- detect_project_dir()
sample_mode <- has_arg("--sample")
sample_tag <- if (sample_mode) "_sample1000" else ""

out_root <- file.path(project_dir, "outputs/core_simi_260501")
data_dir <- file.path(out_root, "data")
csv_dir <- file.path(out_root, "csv")
log_dir <- file.path(out_root, "logs")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

full_data_dir <- file.path(project_dir, "full-data")
path_alltp <- file.path(full_data_dir, if (sample_mode) "allTPreview_sample1000.csv" else "allTPreview.csv")
path_tp <- file.path(full_data_dir, if (sample_mode) "tp_data_new_sample1000.csv" else "tp_data_new.csv")
path_panel <- file.path(data_dir, "core_simi_panel_260501.dta")

path_mr_monthly <- file.path(data_dir, sprintf("management_response_monthly%s_%s.dta", sample_tag, RUN_ID))
path_panel_mr <- file.path(data_dir, sprintf("core_simi_panel_260501_with_mr%s_%s.dta", sample_tag, RUN_ID))
path_audit <- file.path(csv_dir, sprintf("management_response_audit%s_%s.csv", sample_tag, RUN_ID))
path_log <- file.path(log_dir, sprintf("build_management_response_panel%s_%s.log", sample_tag, RUN_ID))

assert_inside_project(c(path_mr_monthly, path_panel_mr, path_audit, path_log), project_dir)

sink(path_log, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Build management-response panel:", as.character(Sys.time()), "\n")
cat("Project:", project_dir, "\n")
cat("Sample mode:", sample_mode, "\n")
cat("Response source:", path_alltp, "\n")
cat("Review-key source:", path_tp, "\n")
cat("Core panel:", path_panel, "\n")

for (p in c(path_alltp, path_tp, path_panel)) {
  if (!file.exists(p)) stop("Missing required input: ", p)
}

panel <- as.data.table(read_dta(path_panel))
panel[, HotelID := as.character(HotelID)]
panel[, Year := as.integer(Year)]
panel[, Mon := as.integer(Mon)]
if (!"year_month" %in% names(panel)) {
  panel[, year_month := sprintf("%04d-%02d", Year, Mon)]
}
panel_key <- unique(panel[, .(HotelID, Year, Mon, year_month)])
setorder(panel_key, HotelID, Year, Mon)
if (anyDuplicated(panel_key, by = c("HotelID", "Year", "Mon")) > 0) {
  stop("Panel key is not unique by HotelID-Year-Mon.")
}

cat("Reading review key columns...\n")
tp_header <- names(fread(path_tp, nrows = 0, showProgress = FALSE))
tp_cols <- intersect(c("HotelID", "ReviewID", "review_date", "year", "month"), tp_header)
missing_tp <- setdiff(c("HotelID", "ReviewID"), tp_cols)
if (length(missing_tp) > 0) stop("tp_data_new is missing: ", paste(missing_tp, collapse = ", "))
review_key <- fread(path_tp, select = tp_cols, showProgress = TRUE, colClasses = c(ReviewID = "character", HotelID = "character"))
if ("year" %in% names(review_key)) setnames(review_key, "year", "review_year")
if ("month" %in% names(review_key)) setnames(review_key, "month", "review_mon")
review_key[, ReviewID := as.character(ReviewID)]
review_key[, HotelID := as.character(HotelID)]
if ("review_date" %in% names(review_key)) {
  review_key[, review_date_parsed := parse_idate(review_date)]
} else {
  review_key[, review_date_parsed := as.IDate(NA)]
}
if (!"review_year" %in% names(review_key)) {
  review_key[, review_year := as.integer(format(review_date_parsed, "%Y"))]
}
if (!"review_mon" %in% names(review_key)) {
  review_key[, review_mon := as.integer(format(review_date_parsed, "%m"))]
}
review_key[, review_year := as.integer(review_year)]
review_key[, review_mon := as.integer(review_mon)]
review_key <- review_key[!is.na(ReviewID) & ReviewID != "" & !is.na(HotelID) & HotelID != ""]
setorder(review_key, ReviewID, HotelID)
review_key_dups <- review_key[, .N, by = ReviewID][N > 1L, .N]
review_key <- unique(review_key, by = "ReviewID")

cat("Reading response columns...\n")
response_header <- names(fread(path_alltp, nrows = 0, showProgress = FALSE))
response_cols <- c(
  "review_id", "location_id", "geo_id", "review_published_date",
  "review_response_id", "review_response_date", "review_response_language",
  "review_response_text", "review_response_author", "review_response_author_connection"
)
response_cols <- intersect(response_cols, response_header)
if (!"review_id" %in% response_cols) stop("allTPreview is missing review_id.")
response_dt <- fread(path_alltp, select = response_cols, showProgress = TRUE, colClasses = c(review_id = "character"))
setnames(response_dt, "review_id", "ReviewID")
response_dt[, ReviewID := as.character(ReviewID)]
response_dt[, response_date := parse_idate(review_response_date)]
response_dt[, response_text_chars := text_chars(review_response_text)]
response_dt[, response_text_words := text_words(review_response_text)]
response_dt[, has_response_raw := as.integer(
  (!is.na(review_response_id) & as.character(review_response_id) != "") |
    (!is.na(review_response_text) & nzchar(trimws(as.character(review_response_text)))) |
    (!is.na(review_response_author) & nzchar(trimws(as.character(review_response_author))))
)]
response_dt[, has_response_dated := as.integer(has_response_raw == 1L & !is.na(response_date))]
response_raw_n <- nrow(response_dt)
response_duplicate_ids <- response_dt[!is.na(ReviewID) & ReviewID != "", .N, by = ReviewID][N > 1L, .N]
setorder(response_dt, ReviewID, -has_response_dated, -has_response_raw, -response_text_chars)
response_dt <- unique(response_dt[!is.na(ReviewID) & ReviewID != ""], by = "ReviewID")

response_keep <- c(
  "ReviewID", "response_date", "has_response_raw", "has_response_dated",
  "response_text_chars", "response_text_words", "review_response_id",
  "review_response_author", "review_response_author_connection"
)
response_dt <- response_dt[, ..response_keep]

cat("Joining review keys to response fields...\n")
review_response <- merge(review_key, response_dt, by = "ReviewID", all.x = TRUE, sort = FALSE)
for (v in c("has_response_raw", "has_response_dated", "response_text_chars", "response_text_words")) {
  if (!v %in% names(review_response)) review_response[, (v) := 0L]
}
zfill_na(review_response, c("has_response_raw", "has_response_dated", "response_text_chars", "response_text_words"), 0L)

review_counts <- review_response[
  !is.na(review_year) & !is.na(review_mon),
  .(mr_review_count = .N),
  by = .(HotelID, Year = review_year, Mon = review_mon)
]

response_counts <- review_response[
  has_response_dated == 1L & !is.na(response_date),
  .(
    mr_count = .N,
    mr_text_chars = sum(response_text_chars, na.rm = TRUE),
    mr_text_words = sum(response_text_words, na.rm = TRUE),
    mr_authors = uniqueN(review_response_author[!is.na(review_response_author) & review_response_author != ""]),
    mr_connections = uniqueN(review_response_author_connection[!is.na(review_response_author_connection) & review_response_author_connection != ""])
  ),
  by = .(
    HotelID,
    Year = as.integer(format(response_date, "%Y")),
    Mon = as.integer(format(response_date, "%m"))
  )
]

mr_monthly <- merge(panel_key, review_counts, by = c("HotelID", "Year", "Mon"), all.x = TRUE, sort = FALSE)
mr_monthly <- merge(mr_monthly, response_counts, by = c("HotelID", "Year", "Mon"), all.x = TRUE, sort = FALSE)
zfill_na(
  mr_monthly,
  c("mr_review_count", "mr_count", "mr_text_chars", "mr_text_words", "mr_authors", "mr_connections"),
  0L
)
mr_monthly[, mr_any := as.integer(mr_count > 0)]
mr_monthly[, mr_rate := fifelse(mr_review_count > 0, mr_count / mr_review_count, 0)]
mr_monthly[, mr_avg_text_chars := fifelse(mr_count > 0, mr_text_chars / mr_count, 0)]
mr_monthly[, mr_avg_text_words := fifelse(mr_count > 0, mr_text_words / mr_count, 0)]

setorder(mr_monthly, HotelID, Year, Mon)
lag_vars <- c("mr_any", "mr_count", "mr_rate", "mr_text_chars", "mr_text_words", "mr_avg_text_chars", "mr_avg_text_words")
for (v in lag_vars) {
  mr_monthly[, paste0("lag_", v) := shift(get(v), 1L, type = "lag"), by = HotelID]
}

panel_mr <- merge(panel, mr_monthly, by = c("HotelID", "Year", "Mon", "year_month"), all.x = TRUE, sort = FALSE)
setorder(panel_mr, HotelID, Year, Mon)
if (anyDuplicated(panel_mr, by = c("HotelID", "Year", "Mon")) > 0) {
  stop("Enhanced panel is not unique by HotelID-Year-Mon.")
}

cat("Writing monthly MR data:", path_mr_monthly, "\n")
write_dta(as.data.frame(mr_monthly), path_mr_monthly)
cat("Writing enhanced panel:", path_panel_mr, "\n")
write_dta(as.data.frame(panel_mr), path_panel_mr)

audit <- data.table(
  metric = c(
    "sample_mode",
    "core_panel_rows",
    "core_panel_hotels",
    "review_key_rows_after_dedup",
    "review_key_duplicate_review_ids",
    "response_rows_raw",
    "response_duplicate_review_ids",
    "response_rows_after_dedup",
    "response_reviews_raw",
    "response_reviews_dated",
    "key_reviews_with_any_response",
    "key_reviews_with_dated_response",
    "key_response_no_date",
    "mr_monthly_rows",
    "mr_monthly_rows_any_response",
    "mr_monthly_mean_rate",
    "enhanced_panel_rows",
    "enhanced_panel_hotels"
  ),
  value = as.character(c(
    sample_mode,
    nrow(panel),
    uniqueN(panel$HotelID),
    nrow(review_key),
    review_key_dups,
    response_raw_n,
    response_duplicate_ids,
    nrow(response_dt),
    sum(response_dt$has_response_raw == 1L, na.rm = TRUE),
    sum(response_dt$has_response_dated == 1L, na.rm = TRUE),
    sum(review_response$has_response_raw == 1L, na.rm = TRUE),
    sum(review_response$has_response_dated == 1L, na.rm = TRUE),
    sum(review_response$has_response_raw == 1L & review_response$has_response_dated == 0L, na.rm = TRUE),
    nrow(mr_monthly),
    sum(mr_monthly$mr_any == 1L, na.rm = TRUE),
    mean(mr_monthly$mr_rate, na.rm = TRUE),
    nrow(panel_mr),
    uniqueN(panel_mr$HotelID)
  ))
)
fwrite(audit, path_audit)
print(audit)

cat("Done:", as.character(Sys.time()), "\n")
