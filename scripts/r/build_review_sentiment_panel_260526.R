library(data.table)
library(haven)
library(syuzhet)

RUN_ID <- "260526"
BASE_RUN_ID <- "260524"

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

safe_mean <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  mean(x, na.rm = TRUE)
}

safe_median <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  median(x, na.rm = TRUE)
}

safe_share <- function(x) {
  if (length(x) == 0L || all(is.na(x))) return(NA_real_)
  mean(as.integer(x), na.rm = TRUE)
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
path_alltp <- file.path(project_dir, "full-data/allTPreview.csv")
path_panel_in <- file.path(data_dir, sprintf("core_simi_panel_260501_with_mr_text_%s.dta", BASE_RUN_ID))
path_sent_monthly <- file.path(data_dir, sprintf("review_sentiment_monthly_%s.dta", RUN_ID))
path_panel_out <- file.path(data_dir, sprintf("core_simi_panel_260501_with_mr_text_sentiment_%s.dta", RUN_ID))
path_audit <- file.path(csv_dir, sprintf("review_sentiment_audit_%s.csv", RUN_ID))
path_log <- file.path(log_dir, sprintf("build_review_sentiment_panel_%s.log", RUN_ID))

assert_inside_project(c(path_sent_monthly, path_panel_out, path_audit, path_log), project_dir)

sink(path_log, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Build review sentiment panel:", as.character(Sys.time()), "\n")
cat("Project:", project_dir, "\n")
cat("Review source:", path_tp, "\n")
cat("Panel source:", path_panel_in, "\n")

for (p in c(path_tp, path_alltp, path_panel_in)) {
  if (!file.exists(p)) stop("Missing required input: ", p)
}

panel <- as.data.table(read_dta(path_panel_in))
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

cat("Reading review text columns...\n")
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
reviews[, review_date_parsed := if ("review_date" %in% names(reviews)) parse_idate(review_date) else as.IDate(NA)]
if (!"review_year" %in% names(reviews)) {
  reviews[, review_year := as.integer(format(review_date_parsed, "%Y"))]
}
if (!"review_mon" %in% names(reviews)) {
  reviews[, review_mon := as.integer(format(review_date_parsed, "%m"))]
}
reviews[, review_year := as.integer(review_year)]
reviews[, review_mon := as.integer(review_mon)]
reviews <- reviews[!is.na(HotelID) & HotelID != "" & !is.na(ReviewID) & ReviewID != ""]
setorder(reviews, ReviewID, HotelID)
review_dup_ids <- reviews[, .N, by = ReviewID][N > 1L, .N]
reviews <- unique(reviews, by = "ReviewID")
reviews <- reviews[!is.na(review_year) & !is.na(review_mon)]

reviews[, review_text_clean := as.character(review_text)]
reviews[is.na(review_text_clean), review_text_clean := ""]
reviews[, review_text_words_sent := text_words(review_text_clean)]
reviews[, has_review_text_sent := as.integer(review_text_words_sent > 0L)]
reviews[, review_rating_num_sent := if ("review_rating" %in% names(reviews)) suppressWarnings(as.numeric(review_rating)) else as.numeric(NA)]

text_idx <- which(reviews$has_review_text_sent == 1L)
cat("Rows after ReviewID dedup:", nrow(reviews), "\n")
cat("Rows with nonempty review text:", length(text_idx), "\n")

reviews[, sent_syuzhet := as.numeric(NA)]
reviews[, sent_bing := as.numeric(NA)]
reviews[, sent_afinn := as.numeric(NA)]
reviews[, sent_nrc := as.numeric(NA)]

if (length(text_idx) > 0) {
  txt <- reviews$review_text_clean[text_idx]
  cat("Scoring review sentiment with syuzhet lexicons...\n")
  reviews[text_idx, sent_syuzhet := get_sentiment(txt, method = "syuzhet")]
  reviews[text_idx, sent_bing := get_sentiment(txt, method = "bing")]
  reviews[text_idx, sent_afinn := get_sentiment(txt, method = "afinn")]
  reviews[text_idx, sent_nrc := get_sentiment(txt, method = "nrc")]
}

reviews[, sent_positive_bing := as.integer(sent_bing > 0)]
reviews[, sent_negative_bing := as.integer(sent_bing < 0)]
reviews[, sent_positive_afinn := as.integer(sent_afinn > 0)]
reviews[, sent_negative_afinn := as.integer(sent_afinn < 0)]
reviews[, sent_syuzhet_per100w := fifelse(review_text_words_sent > 0, 100 * sent_syuzhet / review_text_words_sent, NA_real_)]
reviews[, sent_bing_per100w := fifelse(review_text_words_sent > 0, 100 * sent_bing / review_text_words_sent, NA_real_)]
reviews[, sent_afinn_per100w := fifelse(review_text_words_sent > 0, 100 * sent_afinn / review_text_words_sent, NA_real_)]
reviews[, sent_nrc_per100w := fifelse(review_text_words_sent > 0, 100 * sent_nrc / review_text_words_sent, NA_real_)]

reviews[, review_text_lc := tolower(review_text_clean)]
reviews[, review_issue_service := as.integer(grepl("\\b(service|staff|front desk|manager|rude)\\b", review_text_lc, perl = TRUE))]
reviews[, review_issue_room := as.integer(grepl("\\b(room|bed|bathroom|shower|noise|sleep)\\b", review_text_lc, perl = TRUE))]
reviews[, review_issue_cleanliness := as.integer(grepl("\\b(clean|dirty|smell|mold|stain)\\b", review_text_lc, perl = TRUE))]
reviews[, review_issue_value := as.integer(grepl("\\b(price|expensive|worth|rate|charge|fee)\\b", review_text_lc, perl = TRUE))]
reviews[, review_issue_any := as.integer(review_issue_service == 1L | review_issue_room == 1L | review_issue_cleanliness == 1L | review_issue_value == 1L)]

cat("Reading response metadata for replied-review panel...\n")
alltp_header <- names(fread(path_alltp, nrows = 0, showProgress = FALSE))
alltp_cols <- intersect(
  c("review_id", "review_response_id", "review_response_date", "review_response_text", "review_response_author"),
  alltp_header
)
if (!"review_id" %in% alltp_cols) stop("allTPreview.csv is missing review_id.")
responses <- fread(
  path_alltp,
  select = alltp_cols,
  showProgress = TRUE,
  colClasses = c(review_id = "character")
)
setnames(responses, "review_id", "ReviewID")
responses[, ReviewID := as.character(ReviewID)]
responses <- responses[ReviewID %in% reviews$ReviewID]
for (v in intersect(c("review_response_id", "review_response_text", "review_response_author"), names(responses))) {
  responses[, (v) := fifelse(is.na(get(v)), "", as.character(get(v)))]
}
responses[, has_response_raw := 0L]
if ("review_response_id" %in% names(responses)) {
  responses[nzchar(trimws(review_response_id)), has_response_raw := 1L]
}
if ("review_response_text" %in% names(responses)) {
  responses[nzchar(trimws(review_response_text)), has_response_raw := 1L]
  responses[, response_text_chars := nchar(review_response_text, type = "chars", allowNA = FALSE, keepNA = FALSE)]
} else {
  responses[, response_text_chars := 0L]
}
if ("review_response_author" %in% names(responses)) {
  responses[nzchar(trimws(review_response_author)), has_response_raw := 1L]
}
responses[, response_date := if ("review_response_date" %in% names(responses)) parse_idate(review_response_date) else as.IDate(NA)]
responses[, has_response_dated := as.integer(has_response_raw == 1L & !is.na(response_date))]
setorder(responses, ReviewID, -has_response_dated, response_date, -response_text_chars)
responses <- unique(responses, by = "ReviewID")
reviews <- merge(
  reviews,
  responses[, .(ReviewID, has_response_raw, response_date, has_response_dated)],
  by = "ReviewID",
  all.x = TRUE,
  sort = FALSE
)
reviews[is.na(has_response_raw), has_response_raw := 0L]
reviews[is.na(has_response_dated), has_response_dated := 0L]

cat("Aggregating to HotelID-Year-Mon...\n")
sent_monthly_raw <- reviews[
  ,
  .(
    sent_review_count = .N,
    sent_text_review_count = sum(has_review_text_sent, na.rm = TRUE),
    sent_avg_syuzhet = mean(sent_syuzhet, na.rm = TRUE),
    sent_avg_bing = mean(sent_bing, na.rm = TRUE),
    sent_avg_afinn = mean(sent_afinn, na.rm = TRUE),
    sent_avg_nrc = mean(sent_nrc, na.rm = TRUE),
    sent_med_syuzhet = safe_median(sent_syuzhet),
    sent_med_bing = safe_median(sent_bing),
    sent_med_afinn = safe_median(sent_afinn),
    sent_med_nrc = safe_median(sent_nrc),
    sent_avg_per100w_syuzhet = safe_mean(sent_syuzhet_per100w),
    sent_avg_per100w_bing = safe_mean(sent_bing_per100w),
    sent_avg_per100w_afinn = safe_mean(sent_afinn_per100w),
    sent_avg_per100w_nrc = safe_mean(sent_nrc_per100w),
    sent_sd_syuzhet = sd(sent_syuzhet, na.rm = TRUE),
    sent_sd_bing = sd(sent_bing, na.rm = TRUE),
    sent_sd_afinn = sd(sent_afinn, na.rm = TRUE),
    sent_sd_nrc = sd(sent_nrc, na.rm = TRUE),
    sent_pos_share_bing = mean(sent_positive_bing, na.rm = TRUE),
    sent_neg_share_bing = mean(sent_negative_bing, na.rm = TRUE),
    sent_pos_share_afinn = mean(sent_positive_afinn, na.rm = TRUE),
    sent_neg_share_afinn = mean(sent_negative_afinn, na.rm = TRUE),
    sent_net_pos_bing = mean(sent_positive_bing, na.rm = TRUE) - mean(sent_negative_bing, na.rm = TRUE),
    sent_net_pos_afinn = mean(sent_positive_afinn, na.rm = TRUE) - mean(sent_negative_afinn, na.rm = TRUE),
    sent_avg_review_rating = mean(review_rating_num_sent, na.rm = TRUE),
    sent_avg_text_words = mean(review_text_words_sent, na.rm = TRUE)
  ),
  by = .(HotelID, Year = review_year, Mon = review_mon)
]

for (v in names(sent_monthly_raw)) {
  if (startsWith(v, "sent_") && is.numeric(sent_monthly_raw[[v]])) {
    set(sent_monthly_raw, which(is.nan(sent_monthly_raw[[v]])), v, NA_real_)
  }
}

sent_monthly <- merge(panel_key, sent_monthly_raw, by = c("HotelID", "Year", "Mon"), all.x = TRUE, sort = FALSE)
count_vars <- c("sent_review_count", "sent_text_review_count")
for (v in count_vars) {
  if (v %in% names(sent_monthly)) set(sent_monthly, which(is.na(sent_monthly[[v]])), v, 0L)
}

score_vars <- names(sent_monthly)[startsWith(names(sent_monthly), "sent_")]
score_vars <- setdiff(score_vars, c("sent_review_count", "sent_text_review_count"))
for (v in score_vars) {
  set(sent_monthly, which(is.na(sent_monthly[[v]]) & sent_monthly$sent_text_review_count == 0L), v, 0)
}

sent_monthly[, sent_any_text := as.integer(sent_text_review_count > 0L)]
sent_monthly[, ln_sent_text_review_count := log(sent_text_review_count + 1)]
sent_monthly[, ln_sent_avg_text_words := log(sent_avg_text_words + 1)]
sent_monthly[, sent_syuzhet100 := sent_avg_per100w_syuzhet]
sent_monthly[, sent_bing100 := sent_avg_per100w_bing]
sent_monthly[, sent_afinn100 := sent_avg_per100w_afinn]
sent_monthly[, sent_nrc100 := sent_avg_per100w_nrc]

cat("Aggregating replied-review characteristics by response month...\n")
replied_reviews <- reviews[has_response_dated == 1L & !is.na(response_date)]
if (nrow(replied_reviews) > 0) {
  replied_reviews[, response_year := as.integer(format(response_date, "%Y"))]
  replied_reviews[, response_mon := as.integer(format(response_date, "%m"))]
  replied_monthly_raw <- replied_reviews[
    ,
    .(
      mr_rep_count = .N,
      mr_rep_low_count = sum(review_rating_num_sent <= 2, na.rm = TRUE),
      mr_rep_low_share = safe_share(review_rating_num_sent <= 2),
      mr_rep_neg_share = mean(sent_negative_bing, na.rm = TRUE),
      mr_rep_avg_bing = mean(sent_bing, na.rm = TRUE),
      mr_rep_avg_afinn = mean(sent_afinn, na.rm = TRUE),
      mr_rep_complaint_share = mean(review_issue_any, na.rm = TRUE),
      mr_rep_service_share = mean(review_issue_service, na.rm = TRUE),
      mr_rep_room_share = mean(review_issue_room, na.rm = TRUE),
      mr_rep_clean_share = mean(review_issue_cleanliness, na.rm = TRUE),
      mr_rep_value_share = mean(review_issue_value, na.rm = TRUE)
    ),
    by = .(HotelID, Year = response_year, Mon = response_mon)
  ]
} else {
  replied_monthly_raw <- data.table(
    HotelID = character(), Year = integer(), Mon = integer(),
    mr_rep_count = integer(), mr_rep_low_count = integer(),
    mr_rep_low_share = numeric(), mr_rep_neg_share = numeric(),
    mr_rep_avg_bing = numeric(), mr_rep_avg_afinn = numeric(),
    mr_rep_complaint_share = numeric(), mr_rep_service_share = numeric(),
    mr_rep_room_share = numeric(), mr_rep_clean_share = numeric(),
    mr_rep_value_share = numeric()
  )
}
for (v in names(replied_monthly_raw)) {
  if (startsWith(v, "mr_rep_") && is.numeric(replied_monthly_raw[[v]])) {
    set(replied_monthly_raw, which(is.nan(replied_monthly_raw[[v]])), v, NA_real_)
  }
}
sent_monthly <- merge(sent_monthly, replied_monthly_raw, by = c("HotelID", "Year", "Mon"), all.x = TRUE, sort = FALSE)
replied_vars <- names(sent_monthly)[startsWith(names(sent_monthly), "mr_rep_")]
for (v in replied_vars) {
  set(sent_monthly, which(is.na(sent_monthly[[v]])), v, 0)
}

setorder(sent_monthly, HotelID, Year, Mon)
lag_vars <- setdiff(names(sent_monthly)[startsWith(names(sent_monthly), "sent_")], c("sent_review_count", "sent_text_review_count"))
lag_vars <- c(lag_vars, replied_vars, "ln_sent_text_review_count", "ln_sent_avg_text_words")
for (v in unique(lag_vars)) {
  sent_monthly[, paste0("lag_", v) := shift(get(v), 1L, type = "lag"), by = HotelID]
}
lag_fill_vars <- names(sent_monthly)[startsWith(names(sent_monthly), "lag_sent_") | startsWith(names(sent_monthly), "lag_ln_sent_")]
lag_fill_vars <- c(lag_fill_vars, names(sent_monthly)[startsWith(names(sent_monthly), "lag_mr_rep_")])
for (v in lag_fill_vars) {
  set(sent_monthly, which(is.na(sent_monthly[[v]])), v, 0)
}

drop_existing <- intersect(setdiff(names(sent_monthly), c("HotelID", "Year", "Mon", "year_month")), names(panel))
if (length(drop_existing) > 0) {
  panel[, (drop_existing) := NULL]
}
panel_sent <- merge(panel, sent_monthly, by = c("HotelID", "Year", "Mon", "year_month"), all.x = TRUE, sort = FALSE)
setorder(panel_sent, HotelID, Year, Mon)
if (anyDuplicated(panel_sent, by = c("HotelID", "Year", "Mon")) > 0) {
  stop("Enhanced sentiment panel is not unique by HotelID-Year-Mon.")
}

focus_idx <- which(panel_sent$cs_sample_focus100 == 1 & panel_sent$sent_any_text == 1)
sent_cut_med <- median(panel_sent$sent_net_pos_bing[focus_idx], na.rm = TRUE)
sent_cut_p25 <- quantile(panel_sent$sent_net_pos_bing[focus_idx], 0.25, na.rm = TRUE, names = FALSE)
sent_cut_p75 <- quantile(panel_sent$sent_net_pos_bing[focus_idx], 0.75, na.rm = TRUE, names = FALSE)
panel_sent[, high_sent_bing := as.integer(sent_any_text == 1L & sent_net_pos_bing >= sent_cut_med)]
panel_sent[, low_sent_bing := as.integer(sent_any_text == 1L & sent_net_pos_bing < sent_cut_med)]
panel_sent[, top_sent_bing_p75 := as.integer(sent_any_text == 1L & sent_net_pos_bing >= sent_cut_p75)]
panel_sent[, bottom_sent_bing_p25 := as.integer(sent_any_text == 1L & sent_net_pos_bing <= sent_cut_p25)]

cat("Writing monthly review sentiment data:", path_sent_monthly, "\n")
write_dta(as.data.frame(sent_monthly), path_sent_monthly)
cat("Writing enhanced sentiment panel:", path_panel_out, "\n")
write_dta(as.data.frame(panel_sent), path_panel_out)

audit <- data.table(
  metric = c(
    "base_panel_rows",
    "base_panel_hotels",
    "review_rows_after_dedup",
    "review_duplicate_review_ids",
    "review_rows_with_text",
    "sent_monthly_rows",
    "sent_monthly_rows_with_text",
    "enhanced_panel_rows",
    "enhanced_panel_hotels",
    "mean_sent_avg_syuzhet",
    "mean_sent_avg_bing",
    "mean_sent_avg_afinn",
    "mean_sent_avg_nrc",
    "mean_sent_neg_share_bing",
    "mean_sent_neg_share_afinn",
    "mean_sent_net_pos_bing",
    "min_sent_pos_share_bing",
    "max_sent_pos_share_bing",
    "min_sent_neg_share_bing",
    "max_sent_neg_share_bing",
    "min_sent_avg_per100w_afinn",
    "max_sent_avg_per100w_afinn",
    "response_rows_reviewid_matched",
    "response_rows_with_dated_reply",
    "replied_monthly_rows",
    "mean_mr_rep_neg_share",
    "mean_mr_rep_low_share",
    "focus100_sent_net_pos_bing_median",
    "focus100_sent_net_pos_bing_p25",
    "focus100_sent_net_pos_bing_p75"
  ),
  value = as.character(c(
    nrow(panel),
    uniqueN(panel$HotelID),
    nrow(reviews),
    review_dup_ids,
    length(text_idx),
    nrow(sent_monthly),
    sent_monthly[sent_any_text == 1L, .N],
    nrow(panel_sent),
    uniqueN(panel_sent$HotelID),
    round(mean(sent_monthly$sent_avg_syuzhet, na.rm = TRUE), 6),
    round(mean(sent_monthly$sent_avg_bing, na.rm = TRUE), 6),
    round(mean(sent_monthly$sent_avg_afinn, na.rm = TRUE), 6),
    round(mean(sent_monthly$sent_avg_nrc, na.rm = TRUE), 6),
    round(mean(sent_monthly$sent_neg_share_bing, na.rm = TRUE), 6),
    round(mean(sent_monthly$sent_neg_share_afinn, na.rm = TRUE), 6),
    round(mean(sent_monthly$sent_net_pos_bing, na.rm = TRUE), 6),
    round(min(sent_monthly$sent_pos_share_bing, na.rm = TRUE), 6),
    round(max(sent_monthly$sent_pos_share_bing, na.rm = TRUE), 6),
    round(min(sent_monthly$sent_neg_share_bing, na.rm = TRUE), 6),
    round(max(sent_monthly$sent_neg_share_bing, na.rm = TRUE), 6),
    round(min(sent_monthly$sent_avg_per100w_afinn, na.rm = TRUE), 6),
    round(max(sent_monthly$sent_avg_per100w_afinn, na.rm = TRUE), 6),
    nrow(responses),
    responses[has_response_dated == 1L, .N],
    nrow(replied_monthly_raw),
    round(mean(sent_monthly$mr_rep_neg_share, na.rm = TRUE), 6),
    round(mean(sent_monthly$mr_rep_low_share, na.rm = TRUE), 6),
    round(sent_cut_med, 6),
    round(sent_cut_p25, 6),
    round(sent_cut_p75, 6)
  ))
)
fwrite(audit, path_audit)
print(audit)

cat("Done:", as.character(Sys.time()), "\n")
