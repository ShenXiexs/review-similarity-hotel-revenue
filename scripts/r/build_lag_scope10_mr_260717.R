#!/usr/bin/env Rscript

# Construct lagged management-response measures from the review cohort that
# matches the t-1 Scope-10 visibility rule: all reviews in t-1 plus the ten
# most recent reviews before t-1.  A reply is counted only if it was posted no
# later than the end of t-1, so no future management-response information is
# used for outcome month t.

suppressPackageStartupMessages({
  library(data.table)
  library(haven)
})

run_id <- "260717"
project <- "/Users/samxie/Research/ReviewSimi_Sales/Code"

panel_path <- file.path(
  project,
  "outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
)
tp_path <- file.path(project, "full-data/tp_data_new.csv")
alltp_path <- file.path(project, "full-data/allTPreview.csv")
out_path <- file.path(
  project,
  sprintf("outputs/core_simi_260501/data/lag_scope10_mr_%s.dta", run_id)
)
panel_out_path <- file.path(
  project,
  sprintf(
    "outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_scope10mr_%s.dta",
    run_id
  )
)
audit_path <- file.path(
  project,
  sprintf("outputs/core_simi_260501/csv/lag_scope10_mr_audit_%s.csv", run_id)
)

parse_idate <- function(x) {
  x <- as.character(x)
  x[x == ""] <- NA_character_

  out <- suppressWarnings(as.IDate(x, format = "%Y-%m-%d"))
  miss <- is.na(out) & !is.na(x)
  out[miss] <- suppressWarnings(as.IDate(x[miss], format = "%Y/%m/%d"))
  miss <- is.na(out) & !is.na(x)
  out[miss] <- suppressWarnings(
    as.IDate(substr(x[miss], 1, 10), format = "%Y-%m-%d")
  )
  miss <- is.na(out) & !is.na(x)
  out[miss] <- suppressWarnings(
    as.IDate(substr(x[miss], 1, 10), format = "%Y/%m/%d")
  )
  out
}

text_words <- function(x) {
  x <- as.character(x)
  out <- integer(length(x))
  ok <- !is.na(x) & nzchar(trimws(x))

  if (any(ok)) {
    out[ok] <- lengths(regmatches(x[ok], gregexpr("\\S+", x[ok], perl = TRUE)))
  }
  out
}

for (path in c(panel_path, tp_path, alltp_path)) {
  if (!file.exists(path)) stop("Missing input: ", path)
}

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(audit_path), recursive = TRUE, showWarnings = FALSE)

cat("Loading panel keys...\n")
panel <- as.data.table(read_dta(panel_path))
panel[, HotelID := as.character(HotelID)]
panel[, Year := as.integer(Year)]
panel[, Mon := as.integer(Mon)]

if (!"year_month" %in% names(panel)) {
  panel[, year_month := sprintf("%04d-%02d", Year, Mon)]
}

panel <- unique(
  panel[, .(HotelID, Year, Mon, year_month)],
  by = c("HotelID", "Year", "Mon")
)

if (anyDuplicated(panel, by = c("HotelID", "Year", "Mon")) > 0L) {
  stop("Panel key is not unique by HotelID-Year-Mon.")
}

# The outcome is at t.  The aligned management-response scope is t-1.
panel[, target_start := as.IDate(sprintf("%04d-%02d-01", Year, Mon))]
panel[, source_start := as.IDate(format(as.Date(target_start) - 1, "%Y-%m-01"))]
panel[, source_end := target_start - 1L]

cat("Loading review keys...\n")
tp_header <- names(fread(tp_path, nrows = 0L, showProgress = FALSE))
tp_cols <- intersect(c("HotelID", "ReviewID", "review_date"), tp_header)
if (length(setdiff(c("HotelID", "ReviewID", "review_date"), tp_cols)) > 0L) {
  stop("tp_data_new.csv must contain HotelID, ReviewID, and review_date.")
}

reviews <- fread(
  tp_path,
  select = tp_cols,
  colClasses = c(HotelID = "character", ReviewID = "character"),
  showProgress = TRUE
)
reviews[, HotelID := as.character(HotelID)]
reviews[, ReviewID := as.character(ReviewID)]
reviews[, review_date := parse_idate(review_date)]
reviews <- reviews[
  HotelID %chin% panel$HotelID &
    !is.na(HotelID) & HotelID != "" &
    !is.na(ReviewID) & ReviewID != "" &
    !is.na(review_date)
]
setorder(reviews, ReviewID, HotelID)
reviews <- unique(reviews, by = "ReviewID")

cat("Loading management-response fields...\n")
response_header <- names(fread(alltp_path, nrows = 0L, showProgress = FALSE))
response_cols <- intersect(
  c(
    "review_id",
    "review_response_id",
    "review_response_date",
    "review_response_text",
    "review_response_author"
  ),
  response_header
)
if (!"review_id" %in% response_cols) {
  stop("allTPreview.csv must contain review_id.")
}

responses <- fread(
  alltp_path,
  select = response_cols,
  colClasses = c(review_id = "character", review_response_text = "character"),
  showProgress = TRUE
)
setnames(responses, "review_id", "ReviewID")
responses[, ReviewID := as.character(ReviewID)]
responses <- responses[ReviewID %chin% reviews$ReviewID]

response_string_vars <- c(
  "review_response_id",
  "review_response_text",
  "review_response_author"
)
for (v in response_string_vars) {
  if (!v %in% names(responses)) responses[, (v) := ""]
  responses[, (v) := as.character(get(v))]
  responses[is.na(get(v)), (v) := ""]
}

if (!"review_response_date" %in% names(responses)) {
  responses[, review_response_date := NA_character_]
}

responses[, response_date := parse_idate(review_response_date)]
responses[, response_words := text_words(review_response_text)]
responses[, response_valid := as.integer(
  nzchar(trimws(review_response_id)) |
    nzchar(trimws(review_response_text)) |
    nzchar(trimws(review_response_author))
)]
responses[, response_dated := as.integer(!is.na(response_date))]

# One response record per review, prioritizing a valid dated response.
setorder(
  responses,
  ReviewID,
  -response_valid,
  -response_dated,
  -response_words
)
responses <- unique(responses, by = "ReviewID")

reviews <- merge(
  reviews,
  responses[, .(ReviewID, response_valid, response_date, response_words)],
  by = "ReviewID",
  all.x = TRUE,
  sort = FALSE
)
reviews[is.na(response_valid), response_valid := 0L]
reviews[is.na(response_words), response_words := 0L]
reviews[, response_days := as.integer(response_date - review_date)]
reviews[response_days < 0L | response_days > 3650L, response_days := NA_integer_]

build_scope10_mr <- function(h_reviews, h_panel) {
  setorder(h_reviews, review_date, ReviewID)

  out <- copy(h_panel[, .(HotelID, Year, Mon, year_month)])
  out[, `:=`(
    lag_scope10_mr_review_n = 0L,
    lag_scope10_mr_reply_n = 0L,
    lag_scope10_mr_any = 0L,
    lag_scope10_mr_rate = 0,
    lag_scope10_mr_text_reply_n = 0L,
    lag_scope10_mr_avg_text_words = NA_real_,
    lag_scope10_mr_timing_n = 0L,
    lag_scope10_mr_quick30_share = NA_real_
  )]

  for (i in seq_len(nrow(h_panel))) {
    source_start <- h_panel$source_start[i]
    source_end <- h_panel$source_end[i]

    before_rows <- which(h_reviews$review_date < source_start)
    source_month_rows <- which(
      h_reviews$review_date >= source_start &
        h_reviews$review_date <= source_end
    )

    # Scope-10 at t-1 = all t-1 reviews + the ten immediately preceding reviews.
    scope_rows <- unique(c(tail(before_rows, 10L), source_month_rows))
    if (length(scope_rows) == 0L) next

    # A reply must have been observable by the end of t-1.
    reply_rows <- scope_rows[
      h_reviews$response_valid[scope_rows] == 1L &
        !is.na(h_reviews$response_date[scope_rows]) &
        h_reviews$response_date[scope_rows] >= h_reviews$review_date[scope_rows] &
        h_reviews$response_date[scope_rows] <= source_end
    ]

    text_reply_rows <- reply_rows[
      h_reviews$response_words[reply_rows] > 0L
    ]

    timing_rows <- reply_rows[
      !is.na(h_reviews$response_days[reply_rows])
    ]

    reply_n <- length(reply_rows)
    timing_n <- length(timing_rows)

    out[i, `:=`(
      lag_scope10_mr_review_n = length(scope_rows),
      lag_scope10_mr_reply_n = reply_n,
      lag_scope10_mr_any = as.integer(reply_n > 0L),
      lag_scope10_mr_rate = reply_n / length(scope_rows),
      lag_scope10_mr_text_reply_n = length(text_reply_rows),
      lag_scope10_mr_avg_text_words = if (length(text_reply_rows) > 0L) {
        mean(h_reviews$response_words[text_reply_rows])
      } else {
        NA_real_
      },
      lag_scope10_mr_timing_n = timing_n,
      lag_scope10_mr_quick30_share = if (timing_n > 0L) {
        mean(h_reviews$response_days[timing_rows] <= 30L)
      } else {
        NA_real_
      }
    )]
  }

  out
}

cat("Constructing lagged Scope-10 management-response variables...\n")
hotel_ids <- sort(unique(panel$HotelID))
scope10_mr <- rbindlist(lapply(hotel_ids, function(hotel_id) {
  build_scope10_mr(
    reviews[HotelID == hotel_id],
    panel[HotelID == hotel_id]
  )
}))
setorder(scope10_mr, HotelID, Year, Mon)

if (nrow(scope10_mr) != nrow(panel)) {
  stop("Scope-10 response output does not match the panel row count.")
}
if (anyDuplicated(scope10_mr, by = c("HotelID", "Year", "Mon")) > 0L) {
  stop("Scope-10 response output key is not unique.")
}
if (any(scope10_mr$lag_scope10_mr_reply_n > scope10_mr$lag_scope10_mr_review_n)) {
  stop("Reply count exceeds Scope-10 review count.")
}
if (any(scope10_mr$lag_scope10_mr_rate < 0 | scope10_mr$lag_scope10_mr_rate > 1)) {
  stop("Scope-10 reply rate falls outside [0, 1].")
}
if (any(
  !is.na(scope10_mr$lag_scope10_mr_quick30_share) &
    (scope10_mr$lag_scope10_mr_quick30_share < 0 |
      scope10_mr$lag_scope10_mr_quick30_share > 1)
)) {
  stop("Scope-10 quick-response share falls outside [0, 1].")
}

audit_vars <- c(
  "lag_scope10_mr_review_n",
  "lag_scope10_mr_reply_n",
  "lag_scope10_mr_any",
  "lag_scope10_mr_rate",
  "lag_scope10_mr_text_reply_n",
  "lag_scope10_mr_avg_text_words",
  "lag_scope10_mr_timing_n",
  "lag_scope10_mr_quick30_share"
)

audit <- rbindlist(lapply(audit_vars, function(v) {
  x <- scope10_mr[[v]]
  data.table(
    variable = v,
    n = length(x),
    n_nonmissing = sum(!is.na(x)),
    n_positive = sum(x > 0, na.rm = TRUE),
    mean = mean(x, na.rm = TRUE),
    median = median(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    max = max(x, na.rm = TRUE)
  )
}))

write_dta(as.data.frame(scope10_mr), out_path, version = 14)

# Also materialize a complete panel that retains every original field and only
# appends the new Scope-10 management-response variables.
full_panel <- as.data.table(read_dta(panel_path))
full_panel[, HotelID := as.character(HotelID)]
existing_scope10_vars <- intersect(audit_vars, names(full_panel))
if (length(existing_scope10_vars) > 0L) {
  full_panel[, (existing_scope10_vars) := NULL]
}
full_panel <- merge(
  full_panel,
  scope10_mr[, c("HotelID", "Year", "Mon", "year_month", audit_vars), with = FALSE],
  by = c("HotelID", "Year", "Mon", "year_month"),
  all.x = TRUE,
  sort = FALSE
)
setorder(full_panel, HotelID, Year, Mon)
if (nrow(full_panel) != nrow(panel) ||
    anyDuplicated(full_panel, by = c("HotelID", "Year", "Mon")) > 0L ||
    any(is.na(full_panel$lag_scope10_mr_rate))) {
  stop("Complete panel validation failed.")
}
write_dta(as.data.frame(full_panel), panel_out_path, version = 14)

fwrite(audit, audit_path)

cat("Wrote:", out_path, "\n")
cat("Wrote:", panel_out_path, "\n")
cat("Audit:", audit_path, "\n")
