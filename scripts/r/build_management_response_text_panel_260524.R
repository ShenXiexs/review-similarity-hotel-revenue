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

flag_regex <- function(x, pattern) {
  as.integer(grepl(pattern, x, ignore.case = TRUE, perl = TRUE))
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
path_panel_mr <- file.path(data_dir, sprintf("core_simi_panel_260501_with_mr%s_%s.dta", sample_tag, RUN_ID))
path_panel_core <- file.path(data_dir, "core_simi_panel_260501.dta")
path_panel <- if (file.exists(path_panel_mr)) path_panel_mr else path_panel_core

path_mr_text_monthly <- file.path(data_dir, sprintf("management_response_text_monthly%s_%s.dta", sample_tag, RUN_ID))
path_panel_mr_text <- file.path(data_dir, sprintf("core_simi_panel_260501_with_mr_text%s_%s.dta", sample_tag, RUN_ID))
path_audit <- file.path(csv_dir, sprintf("management_response_text_audit%s_%s.csv", sample_tag, RUN_ID))
path_log <- file.path(log_dir, sprintf("build_management_response_text_panel%s_%s.log", sample_tag, RUN_ID))

assert_inside_project(c(path_mr_text_monthly, path_panel_mr_text, path_audit, path_log), project_dir)

sink(path_log, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Build management-response text panel:", as.character(Sys.time()), "\n")
cat("Project:", project_dir, "\n")
cat("Sample mode:", sample_mode, "\n")
cat("Response source:", path_alltp, "\n")
cat("Review-key source:", path_tp, "\n")
cat("Base panel:", path_panel, "\n")

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
if (anyDuplicated(panel_key, by = c("HotelID", "Year", "Mon")) > 0) {
  stop("Panel key is not unique by HotelID-Year-Mon.")
}

cat("Reading review-level keys and ratings...\n")
tp_header <- names(fread(path_tp, nrows = 0, showProgress = FALSE))
tp_cols <- intersect(c("HotelID", "ReviewID", "review_date", "review_rating", "year", "month"), tp_header)
missing_tp <- setdiff(c("HotelID", "ReviewID"), tp_cols)
if (length(missing_tp) > 0) stop("tp_data_new is missing: ", paste(missing_tp, collapse = ", "))

review_key <- fread(
  path_tp,
  select = tp_cols,
  showProgress = TRUE,
  colClasses = c(ReviewID = "character", HotelID = "character")
)
if ("year" %in% names(review_key)) setnames(review_key, "year", "review_year")
if ("month" %in% names(review_key)) setnames(review_key, "month", "review_mon")
review_key[, ReviewID := as.character(ReviewID)]
review_key[, HotelID := as.character(HotelID)]
review_key[, review_date_parsed := if ("review_date" %in% names(review_key)) parse_idate(review_date) else as.IDate(NA)]
if (!"review_year" %in% names(review_key)) {
  review_key[, review_year := as.integer(format(review_date_parsed, "%Y"))]
}
if (!"review_mon" %in% names(review_key)) {
  review_key[, review_mon := as.integer(format(review_date_parsed, "%m"))]
}
if ("review_rating" %in% names(review_key)) {
  review_key[, review_rating_num := suppressWarnings(as.numeric(review_rating))]
} else {
  review_key[, review_rating_num := as.numeric(NA)]
}
review_key[, review_year := as.integer(review_year)]
review_key[, review_mon := as.integer(review_mon)]
review_key <- review_key[!is.na(ReviewID) & ReviewID != "" & !is.na(HotelID) & HotelID != ""]
review_key_dups <- review_key[, .N, by = ReviewID][N > 1L, .N]
setorder(review_key, ReviewID, HotelID)
review_key <- unique(review_key, by = "ReviewID")
review_ids <- review_key$ReviewID

cat("Reading response columns, then narrowing to project ReviewIDs before text parsing...\n")
response_header <- names(fread(path_alltp, nrows = 0, showProgress = FALSE))
response_cols <- c(
  "review_id", "location_id", "geo_id", "review_published_date", "review_rating",
  "review_response_id", "review_response_date", "review_response_language",
  "review_response_text", "review_response_author", "review_response_author_connection"
)
response_cols <- intersect(response_cols, response_header)
if (!"review_id" %in% response_cols) stop("allTPreview is missing review_id.")

response_dt <- fread(path_alltp, select = response_cols, showProgress = TRUE, colClasses = c(review_id = "character"))
setnames(response_dt, "review_id", "ReviewID")
response_dt[, ReviewID := as.character(ReviewID)]
response_dt[, response_date := parse_idate(review_response_date)]
response_dt[, has_response_raw := as.integer(
  (!is.na(review_response_id) & as.character(review_response_id) != "") |
    (!is.na(review_response_text) & nzchar(trimws(as.character(review_response_text)))) |
    (!is.na(review_response_author) & nzchar(trimws(as.character(review_response_author))))
)]
response_rows_raw <- nrow(response_dt)
response_reviews_raw <- response_dt[, sum(has_response_raw, na.rm = TRUE)]
response_reviews_dated <- response_dt[, sum(has_response_raw == 1L & !is.na(response_date), na.rm = TRUE)]
response_duplicate_ids <- response_dt[!is.na(ReviewID) & ReviewID != "", .N, by = ReviewID][N > 1L, .N]

response_dt <- response_dt[!is.na(ReviewID) & ReviewID != "" & ReviewID %chin% review_ids]
cat("Rows after ReviewID narrowing:", nrow(response_dt), "\n")

response_dt[, response_text_chars := text_chars(review_response_text)]
response_dt[, response_text_words := text_words(review_response_text)]
response_dt[, has_response_dated := as.integer(has_response_raw == 1L & !is.na(response_date))]
response_dt[, pub_date := parse_idate(review_published_date)]
if ("review_rating" %in% names(response_dt)) {
  response_dt[, alltp_review_rating := suppressWarnings(as.numeric(review_rating))]
} else {
  response_dt[, alltp_review_rating := as.numeric(NA)]
}

setorder(response_dt, ReviewID, -has_response_dated, -has_response_raw, -response_text_chars)
response_dt <- unique(response_dt, by = "ReviewID")

cat("Joining review keys to response fields...\n")
review_response <- merge(review_key, response_dt, by = "ReviewID", all.x = TRUE, sort = FALSE)
for (v in c("has_response_raw", "has_response_dated", "response_text_chars", "response_text_words")) {
  if (!v %in% names(review_response)) review_response[, (v) := 0L]
}
zfill_na(review_response, c("has_response_raw", "has_response_dated", "response_text_chars", "response_text_words"), 0L)
review_response[, rating_num := fifelse(!is.na(review_rating_num), review_rating_num, alltp_review_rating)]
review_response[, review_date_final := fifelse(!is.na(review_date_parsed), review_date_parsed, pub_date)]
review_response[, response_days := as.integer(response_date - review_date_final)]
review_response[response_days < 0 | response_days > 3650, response_days := NA_integer_]

txt <- tolower(as.character(review_response$review_response_text))
txt[is.na(txt)] <- ""
review_response[, txt_thanks := flag_regex(txt, "\\b(thank|thanks|appreciate|grateful)\\b")]
review_response[, txt_apology := flag_regex(txt, "\\b(sorry|apolog|apology|regret)\\b")]
review_response[, txt_invite := flag_regex(txt, "\\b(come back|return|visit again|welcome back|stay again|see you again)\\b")]
review_response[, txt_recovery := flag_regex(txt, "\\b(refund|compensat|credit|discount|resolve|resolved|fix|address|follow up|make it right)\\b")]
review_response[, txt_contact := flag_regex(txt, "\\b(contact|email|phone|call|manager|front desk|reach out|directly)\\b")]
review_response[, txt_personal := flag_regex(txt, "\\b(dear|you|your|guest|sir|madam|mr\\.?|ms\\.?)\\b")]
review_response[, txt_positive := flag_regex(txt, "\\b(great|glad|pleased|delight|wonderful|excellent|happy|enjoyed|perfect)\\b")]
review_response[, txt_negative_tone := flag_regex(txt, "\\b(issue|problem|concern|disappoint|inconvenience|unacceptable|poor|bad)\\b")]
review_response[, txt_mgr := flag_regex(as.character(review_response$review_response_author_connection), "\\b(manager|management|owner|general manager|director)\\b")]

norm_txt <- tolower(trimws(gsub("[^[:alnum:][:space:]]+", " ", as.character(review_response$review_response_text), perl = TRUE)))
norm_txt <- gsub("\\s+", " ", norm_txt, perl = TRUE)
norm_txt[is.na(norm_txt) | norm_txt == ""] <- NA_character_
review_response[, norm_response_text := norm_txt]
review_response[, template_n := .N, by = .(HotelID, norm_response_text)]
review_response[is.na(norm_response_text), template_n := 0L]
review_response[, txt_template := as.integer(has_response_raw == 1L & response_text_words >= 8L & template_n >= 3L)]

review_counts <- review_response[
  !is.na(review_year) & !is.na(review_mon),
  .(
    mr_review_count = .N,
    mr_low_review_count = sum(!is.na(rating_num) & rating_num <= 2, na.rm = TRUE),
    mr_avg_review_rating = mean(rating_num, na.rm = TRUE)
  ),
  by = .(HotelID, Year = review_year, Mon = review_mon)
]
review_counts[is.nan(mr_avg_review_rating), mr_avg_review_rating := NA_real_]

response_counts <- review_response[
  has_response_dated == 1L & !is.na(response_date),
  .(
    mr_count = .N,
    mr_text_chars = sum(response_text_chars, na.rm = TRUE),
    mr_text_words = sum(response_text_words, na.rm = TRUE),
    mr_avg_resp_days = as.numeric(mean(response_days, na.rm = TRUE)),
    mr_med_resp_days = as.numeric(median(response_days, na.rm = TRUE)),
    mr_quick7_count = sum(!is.na(response_days) & response_days <= 7, na.rm = TRUE),
    mr_quick30_count = sum(!is.na(response_days) & response_days <= 30, na.rm = TRUE),
    mr_thanks_count = sum(txt_thanks, na.rm = TRUE),
    mr_apology_count = sum(txt_apology, na.rm = TRUE),
    mr_invite_count = sum(txt_invite, na.rm = TRUE),
    mr_recovery_count = sum(txt_recovery, na.rm = TRUE),
    mr_contact_count = sum(txt_contact, na.rm = TRUE),
    mr_personal_count = sum(txt_personal, na.rm = TRUE),
    mr_positive_count = sum(txt_positive, na.rm = TRUE),
    mr_negtone_count = sum(txt_negative_tone, na.rm = TRUE),
    mr_template_count = sum(txt_template, na.rm = TRUE),
    mr_mgr_count = sum(txt_mgr, na.rm = TRUE),
    mr_neg_review_count = sum(!is.na(rating_num) & rating_num <= 2, na.rm = TRUE),
    mr_resp_rating_avg = as.numeric(mean(rating_num, na.rm = TRUE))
  ),
  by = .(
    HotelID,
    Year = as.integer(format(response_date, "%Y")),
    Mon = as.integer(format(response_date, "%m"))
  )
]
for (v in c("mr_avg_resp_days", "mr_med_resp_days", "mr_resp_rating_avg")) {
  response_counts[is.nan(get(v)), (v) := NA_real_]
}

mr_monthly <- merge(panel_key, review_counts, by = c("HotelID", "Year", "Mon"), all.x = TRUE, sort = FALSE)
mr_monthly <- merge(mr_monthly, response_counts, by = c("HotelID", "Year", "Mon"), all.x = TRUE, sort = FALSE)

count_vars <- c(
  "mr_review_count", "mr_low_review_count", "mr_count", "mr_text_chars", "mr_text_words",
  "mr_quick7_count", "mr_quick30_count", "mr_thanks_count", "mr_apology_count",
  "mr_invite_count", "mr_recovery_count", "mr_contact_count", "mr_personal_count",
  "mr_positive_count", "mr_negtone_count", "mr_template_count", "mr_mgr_count",
  "mr_neg_review_count"
)
zfill_na(mr_monthly, count_vars, 0)

mr_monthly[, mr_any := as.integer(mr_count > 0)]
mr_monthly[, mr_rate := fifelse(mr_review_count > 0, mr_count / mr_review_count, 0)]
mr_monthly[, mr_low_review_share := fifelse(mr_review_count > 0, mr_low_review_count / mr_review_count, 0)]
mr_monthly[, mr_neg_review_share := fifelse(mr_count > 0, mr_neg_review_count / mr_count, 0)]
mr_monthly[, mr_neg_response_rate := fifelse(mr_low_review_count > 0, mr_neg_review_count / mr_low_review_count, 0)]
mr_monthly[, mr_avg_text_chars := fifelse(mr_count > 0, mr_text_chars / mr_count, 0)]
mr_monthly[, mr_avg_text_words := fifelse(mr_count > 0, mr_text_words / mr_count, 0)]
mr_monthly[, mr_quick7_share := fifelse(mr_count > 0, mr_quick7_count / mr_count, 0)]
mr_monthly[, mr_quick30_share := fifelse(mr_count > 0, mr_quick30_count / mr_count, 0)]
mr_monthly[, mr_thanks_share := fifelse(mr_count > 0, mr_thanks_count / mr_count, 0)]
mr_monthly[, mr_apology_share := fifelse(mr_count > 0, mr_apology_count / mr_count, 0)]
mr_monthly[, mr_invite_share := fifelse(mr_count > 0, mr_invite_count / mr_count, 0)]
mr_monthly[, mr_recovery_share := fifelse(mr_count > 0, mr_recovery_count / mr_count, 0)]
mr_monthly[, mr_contact_share := fifelse(mr_count > 0, mr_contact_count / mr_count, 0)]
mr_monthly[, mr_personal_share := fifelse(mr_count > 0, mr_personal_count / mr_count, 0)]
mr_monthly[, mr_positive_share := fifelse(mr_count > 0, mr_positive_count / mr_count, 0)]
mr_monthly[, mr_negtone_share := fifelse(mr_count > 0, mr_negtone_count / mr_count, 0)]
mr_monthly[, mr_template_share := fifelse(mr_count > 0, mr_template_count / mr_count, 0)]
mr_monthly[, mr_mgr_share := fifelse(mr_count > 0, mr_mgr_count / mr_count, 0)]
mr_monthly[, mr_avg_resp_days := fifelse(mr_count > 0 & !is.na(mr_avg_resp_days), mr_avg_resp_days, 0)]
mr_monthly[, mr_med_resp_days := fifelse(mr_count > 0 & !is.na(mr_med_resp_days), mr_med_resp_days, 0)]
mr_monthly[, mr_resp_rating_avg := fifelse(mr_count > 0 & !is.na(mr_resp_rating_avg), mr_resp_rating_avg, 0)]
mr_monthly[, mr_avg_review_rating := fifelse(!is.na(mr_avg_review_rating), mr_avg_review_rating, 0)]

setorder(mr_monthly, HotelID, Year, Mon)
lag_vars <- setdiff(names(mr_monthly)[startsWith(names(mr_monthly), "mr_")], c("mr_review_count", "mr_low_review_count", "mr_avg_review_rating"))
for (v in lag_vars) {
  mr_monthly[, paste0("lag_", v) := shift(get(v), 1L, type = "lag"), by = HotelID]
}
lag_fill_vars <- names(mr_monthly)[startsWith(names(mr_monthly), "lag_mr_")]
zfill_na(mr_monthly, lag_fill_vars, 0)

drop_existing <- intersect(setdiff(names(mr_monthly), c("HotelID", "Year", "Mon", "year_month")), names(panel))
if (length(drop_existing) > 0) {
  panel[, (drop_existing) := NULL]
}
panel_mr_text <- merge(panel, mr_monthly, by = c("HotelID", "Year", "Mon", "year_month"), all.x = TRUE, sort = FALSE)
setorder(panel_mr_text, HotelID, Year, Mon)
if (anyDuplicated(panel_mr_text, by = c("HotelID", "Year", "Mon")) > 0) {
  stop("Enhanced MR text panel is not unique by HotelID-Year-Mon.")
}

optional_ars_files <- c(
  file.path(data_dir, "ars_robustness_260509.dta"),
  file.path(data_dir, "ars_scope_5_10_15_20_30_260509.dta")
)
for (ars_path in optional_ars_files[file.exists(optional_ars_files)]) {
  cat("Merging optional ARS file:", ars_path, "\n")
  ars_dt <- as.data.table(read_dta(ars_path))
  ars_dt[, HotelID := as.character(HotelID)]
  ars_dt[, Year := as.integer(Year)]
  ars_dt[, Mon := as.integer(Mon)]
  if (!"year_month" %in% names(ars_dt)) {
    ars_dt[, year_month := sprintf("%04d-%02d", Year, Mon)]
  }
  ars_dt <- unique(ars_dt, by = c("HotelID", "Year", "Mon", "year_month"))
  new_cols <- setdiff(names(ars_dt), c("HotelID", "Year", "Mon", "year_month", names(panel_mr_text)))
  if (length(new_cols) > 0) {
    panel_mr_text <- merge(
      panel_mr_text,
      ars_dt[, c("HotelID", "Year", "Mon", "year_month", new_cols), with = FALSE],
      by = c("HotelID", "Year", "Mon", "year_month"),
      all.x = TRUE,
      sort = FALSE
    )
  }
}
setorder(panel_mr_text, HotelID, Year, Mon)

cat("Writing monthly MR text data:", path_mr_text_monthly, "\n")
write_dta(as.data.frame(mr_monthly), path_mr_text_monthly)
cat("Writing enhanced MR text panel:", path_panel_mr_text, "\n")
write_dta(as.data.frame(panel_mr_text), path_panel_mr_text)

audit <- data.table(
  metric = c(
    "sample_mode",
    "base_panel_rows",
    "base_panel_hotels",
    "review_key_rows_after_dedup",
    "review_key_duplicate_review_ids",
    "response_rows_raw",
    "response_duplicate_review_ids",
    "response_reviews_raw",
    "response_reviews_dated",
    "response_rows_after_key_filter_dedup",
    "key_reviews_with_any_response",
    "key_reviews_with_dated_response",
    "key_reviews_with_response_text",
    "key_responses_missing_date",
    "mr_monthly_rows",
    "mr_monthly_rows_any_response",
    "mr_text_rows_any_lag_response",
    "mr_mean_rate",
    "mr_mean_avg_text_words_when_response",
    "mr_mean_quick7_share_when_response",
    "mr_mean_apology_share_when_response",
    "mr_mean_template_share_when_response",
    "enhanced_panel_rows",
    "enhanced_panel_hotels"
  ),
  value = as.character(c(
    sample_mode,
    nrow(panel),
    uniqueN(panel$HotelID),
    nrow(review_key),
    review_key_dups,
    response_rows_raw,
    response_duplicate_ids,
    response_reviews_raw,
    response_reviews_dated,
    nrow(response_dt),
    review_response[has_response_raw == 1L, .N],
    review_response[has_response_dated == 1L, .N],
    review_response[response_text_words > 0L, .N],
    review_response[has_response_raw == 1L & is.na(response_date), .N],
    nrow(mr_monthly),
    mr_monthly[mr_any == 1L, .N],
    mr_monthly[lag_mr_any == 1L, .N],
    round(mean(mr_monthly$mr_rate, na.rm = TRUE), 6),
    round(mean(mr_monthly[mr_any == 1L]$mr_avg_text_words, na.rm = TRUE), 6),
    round(mean(mr_monthly[mr_any == 1L]$mr_quick7_share, na.rm = TRUE), 6),
    round(mean(mr_monthly[mr_any == 1L]$mr_apology_share, na.rm = TRUE), 6),
    round(mean(mr_monthly[mr_any == 1L]$mr_template_share, na.rm = TRUE), 6),
    nrow(panel_mr_text),
    uniqueN(panel_mr_text$HotelID)
  ))
)
fwrite(audit, path_audit)
print(audit)

cat("Done:", as.character(Sys.time()), "\n")
