#!/usr/bin/env Rscript
# Calendar-month management-response panel.  A treatment in month t contains
# only responses posted strictly before t starts; it therefore cannot use
# information that becomes visible later in t.
suppressPackageStartupMessages({ library(data.table); library(haven) })

root <- "/Users/samxie/Research/ReviewSimi_Sales/Code"
data_dir <- file.path(root, "outputs/core_simi_260501/data")
log_dir <- file.path(root, "outputs/core_simi_260501/logs")
out <- file.path(data_dir, "calendar_month_pool_visible_mr_gt100_panel_260711.dta")
logfile <- file.path(log_dir, "build_calendar_month_pool_visible_mr_gt100_260711.log")
base_path <- file.path(data_dir, "core_simi_panel_260501_with_mr_text_sentiment_260526.dta")
tp_path <- file.path(root, "full-data/tp_data_new.csv")
all_path <- file.path(root, "full-data/allTPreview.csv")
vec_path <- file.path(root, "../Data/matched_new/TP_texas_data/reviews_texas_en_doc2vec200_joined.csv")
stream_script <- file.path(root, "scripts/python/stream_alltpreview_hotels_260711.py")
stopifnot(file.exists(base_path), file.exists(tp_path), file.exists(all_path), file.exists(vec_path), file.exists(stream_script))

sink(logfile, split = TRUE); on.exit(sink(), add = TRUE)
cat("Calendar-month visible-response panel build:", format(Sys.time()), "\n")
idate <- function(x) as.IDate(as.Date(x))
ym <- function(x) format(as.Date(x), "%Y-%m")
month_start <- function(x) as.IDate(format(as.Date(x), "%Y-%m-01"))
next_ym <- function(x) format(as.Date(month_start(x)) + 32, "%Y-%m")
smean <- function(x) if (any(!is.na(x))) as.numeric(mean(x, na.rm = TRUE)) else NA_real_
wc <- function(x) { x <- trimws(as.character(x)); as.integer(ifelse(is.na(x) | x == "", 0L, lengths(regmatches(x, gregexpr("\\S+", x, perl = TRUE))))) }

base <- as.data.table(read_dta(base_path)); base[, HotelID := as.character(HotelID)]
base[, event_ym := sprintf("%04d-%02d", as.integer(Year), as.integer(Mon))]
base <- base[revtot_final > 100]
risk <- base[, .(
  first_base_ym = min(event_ym),
  last_base_ym = max(event_ym),
  final_review_count = max(as.numeric(revtot_final), na.rm = TRUE)
), by = HotelID]
analysis_hotels <- risk$HotelID
cat("Hotels with final review total >100:", length(analysis_hotels), "\n")

cat("Reading unified raw review ledger...\n")
ids_file <- tempfile("visible_mr_hotel_ids_")
writeLines(analysis_hotels, ids_file); on.exit(unlink(ids_file), add = TRUE)
stream_cmd <- paste("python3", shQuote(stream_script), shQuote(all_path), shQuote(ids_file))
all <- fread(cmd=stream_cmd, colClasses = c(location_id="character", review_id="character", review_text="character", review_response_text="character"), showProgress = TRUE)
setnames(all, c("location_id", "review_id"), c("HotelID", "ReviewID")); all[, HotelID := as.character(HotelID)]
all <- all[HotelID %chin% analysis_hotels & !is.na(ReviewID) & ReviewID != ""]
all[, review_date := idate(review_published_date)]
all[, text_chars := nchar(review_text, type="chars", allowNA=TRUE)]; all[is.na(text_chars), text_chars := 0L]
all[, date_valid := as.integer(!is.na(review_date))]
setorder(all, ReviewID, -date_valid, -text_chars); all <- unique(all, by="ReviewID"); all[, date_valid := NULL]
all[, source := "all"]

tp <- fread(tp_path, select=c("HotelID", "ReviewID", "review_date", "review_rating", "review_text"), colClasses=c(HotelID="character", ReviewID="character", review_text="character"), showProgress=TRUE)
tp <- tp[HotelID %chin% analysis_hotels & !is.na(ReviewID) & ReviewID != ""]
tp[, review_date := idate(review_date)]; tp[, source := "tp"]
setnames(tp, c("review_rating", "review_text"), c("tp_rating", "tp_text"))
tp_only <- tp[!ReviewID %chin% all$ReviewID]
reviews <- rbindlist(list(all, tp_only), fill=TRUE, use.names=TRUE)
reviews[, review_rating_num := suppressWarnings(as.numeric(fifelse(!is.na(review_rating), review_rating, tp_rating)))]
reviews[, review_text_final := fifelse(!is.na(review_text) & review_text != "", review_text, tp_text)]
reviews <- reviews[!is.na(review_date)]
reviews[, `:=`(event_ym=ym(review_date), event_start=month_start(review_date), review_words=wc(review_text_final))]
reviews[, text_chars := nchar(review_text_final, type="chars", allowNA=TRUE)]; reviews[is.na(text_chars), text_chars:=0L]
cat("Unified reviews:", nrow(reviews), "; allTPreview:", sum(reviews$source=="all"), "; TP-only:", sum(reviews$source=="tp"), "\n")

cat("Reading and normalizing full identical Doc2Vec vectors...\n")
vd <- paste0("V", 0:199)
vec <- fread(vec_path, select=c("HotelID", "ReviewID", vd), colClasses=c(HotelID="character", ReviewID="character"), showProgress=TRUE)
vec[, HotelID := as.character(HotelID)]; vec <- vec[HotelID %chin% analysis_hotels]
setorder(vec, ReviewID, HotelID); vec <- unique(vec, by="ReviewID")
reviews <- merge(reviews, vec, by=c("HotelID", "ReviewID"), all.x=TRUE, sort=FALSE)
mat <- as.matrix(reviews[, ..vd]); storage.mode(mat) <- "double"; nr <- sqrt(rowSums(mat * mat))
reviews[, valid_vec := is.finite(nr) & nr > 0 & rowSums(!is.finite(mat)) == 0]
idx <- which(reviews$valid_vec)
reviews[idx, (vd) := lapply(.SD, function(z) z / nr[idx]), .SDcols=vd]
cat("Valid-vector review coverage:", mean(reviews$valid_vec), "\n")

cat("Building balanced at-risk calendar months and pre-month outcomes...\n")
month_out <- reviews[, .(
  review_count=.N,
  rating_n=sum(!is.na(review_rating_num)),
  rating_sum=sum(review_rating_num, na.rm=TRUE),
  rating_sumsq=sum(review_rating_num^2, na.rm=TRUE),
  mean_rating=smean(review_rating_num),
  sd_rating=if (.N > 1) suppressWarnings(sd(review_rating_num, na.rm=TRUE)) else NA_real_,
  mean_text_chars=smean(text_chars),
  ln_mean_text_chars=log(smean(text_chars) + 1)
), by=.(HotelID, event_ym, event_start)]
grid <- risk[, {
  ds <- seq(as.Date(paste0(first_base_ym, "-01")), as.Date(paste0(last_base_ym, "-01")), by="month")
  .(event_start=as.IDate(ds), event_ym=format(ds, "%Y-%m"))
}, by=HotelID]
panel <- merge(grid, month_out, by=c("HotelID", "event_ym", "event_start"), all.x=TRUE, sort=FALSE)
panel[is.na(review_count), review_count := 0L]
panel[is.na(rating_n), rating_n := 0L]
panel[is.na(rating_sum), rating_sum := 0]
panel[is.na(rating_sumsq), rating_sumsq := 0]
panel[, ln_review_count := log(review_count + 1)]

cat("Computing pre-specified pooled and new-review ARS measures...\n")
reviews[, gid := paste(HotelID, event_ym, sep="\r")]
groups <- split(reviews[valid_vec == TRUE, ..vd], reviews[valid_vec == TRUE, gid])
ars_targets <- panel[review_count > 0, .(HotelID, event_ym, prev_ym=ym(as.Date(event_start)-1), prev2_ym=ym(as.Date(event_start)-32))]
ars <- vector("list", nrow(ars_targets))
for (i in seq_len(nrow(ars_targets))) {
  r <- ars_targets[i]
  a <- groups[[paste(r$HotelID, r$event_ym, sep="\r")]]
  b <- groups[[paste(r$HotelID, r$prev_ym, sep="\r")]]
  c <- groups[[paste(r$HotelID, r$prev2_ym, sep="\r")]]
  na <- if (is.null(a)) 0L else nrow(a); nb <- if (is.null(b)) 0L else nrow(b); nc <- if (is.null(c)) 0L else nrow(c)
  if (na > 0L && nb > 0L) {
    p <- rbind(as.matrix(a), as.matrix(b)); n <- nrow(p)
    pool2 <- (sum(tcrossprod(p)) - n) / (n * (n - 1))
  } else pool2 <- NA_real_
  if (na > 0L && nb > 0L && nc > 0L) {
    p3 <- rbind(as.matrix(a), as.matrix(b), as.matrix(c)); n3 <- nrow(p3)
    pool3 <- (sum(tcrossprod(p3)) - n3) / (n3 * (n3 - 1))
  } else pool3 <- NA_real_
  if (na >= 2L) {
    s <- tcrossprod(as.matrix(a)); within_current <- (sum(s) - na) / (na * (na - 1))
  } else within_current <- NA_real_
  ars[[i]] <- data.table(HotelID=r$HotelID, event_ym=r$event_ym, ars_pool_visible=pool2, ars_pool_visible_3m=pool3, ars_within_current=within_current, ars_current_nvec=na, ars_previous_nvec=nb, ars_previous2_nvec=nc)
}
panel <- merge(panel, rbindlist(ars), by=c("HotelID", "event_ym"), all.x=TRUE, sort=FALSE)
stopifnot(
  all(is.na(panel$ars_pool_visible) | (panel$ars_pool_visible >= -1.000001 & panel$ars_pool_visible <= 1.000001)),
  all(is.na(panel$ars_pool_visible_3m) | (panel$ars_pool_visible_3m >= -1.000001 & panel$ars_pool_visible_3m <= 1.000001)),
  all(is.na(panel$ars_within_current) | (panel$ars_within_current >= -1.000001 & panel$ars_within_current <= 1.000001))
)

cat("Mapping only month-start-visible management responses...\n")
reviews[, `:=`(response_date=idate(review_response_date), response_chars=nchar(review_response_text, type="chars", allowNA=TRUE))]
reviews[is.na(response_chars), response_chars:=0L]
reviews[, response_valid := as.integer((!is.na(review_response_id) & review_response_id != "") | response_chars > 0L | (!is.na(review_response_author) & review_response_author != ""))]
responses <- reviews[response_valid == 1L & !is.na(response_date) & response_date >= review_date]
responses[, `:=`(response_ym=ym(response_date), visible_event_ym=next_ym(response_date))]
flow <- responses[, .(mr_visible_start_n=.N), by=.(HotelID, event_ym=visible_event_ym)]
# A reply visible at the start of t is decomposed by the vintage of the review
# to which it was written.  "prevcohort" is the cleanest treatment for the
# count question: its denominator is exactly the number of reviews written in
# t-1, and no review posted in t can enter either numerator or denominator.
cohort <- responses[response_ym == event_ym, .(mr_prevcohort_visible_n=.N), by=.(HotelID, event_ym=visible_event_ym)]
oldreview <- responses[response_ym != event_ym, .(mr_visible_start_oldreview_n=.N), by=.(HotelID, event_ym=visible_event_ym)]
panel <- merge(panel, flow, by=c("HotelID", "event_ym"), all.x=TRUE, sort=FALSE)
panel <- merge(panel, cohort, by=c("HotelID", "event_ym"), all.x=TRUE, sort=FALSE)
panel <- merge(panel, oldreview, by=c("HotelID", "event_ym"), all.x=TRUE, sort=FALSE)
panel[is.na(mr_visible_start_n), mr_visible_start_n := 0L]
panel[is.na(mr_prevcohort_visible_n), mr_prevcohort_visible_n := 0L]
panel[is.na(mr_visible_start_oldreview_n), mr_visible_start_oldreview_n := 0L]
panel[, `:=`(
  mr_visible_start_any=as.integer(mr_visible_start_n > 0L),
  ln_mr_visible_start_n=log(mr_visible_start_n + 1),
  mr_prevcohort_visible_any=as.integer(mr_prevcohort_visible_n > 0L),
  mr_visible_start_oldreview_any=as.integer(mr_visible_start_oldreview_n > 0L),
  ln_mr_visible_start_oldreview_n=log(mr_visible_start_oldreview_n + 1)
)]

cat("Adding strictly pre-month controls and response-cohort rates...\n")
setorder(panel, HotelID, event_start)
panel[, `:=`(
  pre_review_count=shift(review_count, fill=0L),
  pre_mean_rating=shift(mean_rating),
  pre_sd_rating=shift(sd_rating),
  pre_ln_mean_text_chars=shift(ln_mean_text_chars),
  pre_ars_pool_visible=shift(ars_pool_visible),
  pre_ars_within_current=shift(ars_within_current)
), by=HotelID]
# Direct legacy Route A/B names, with the strict calendar-month meaning.  The
# lagged monthly rating remains missing when t-1 has no valid rating, exactly
# as in the original event-panel interface; the pre_* companion is separately
# zero-filled only for the strict count-model missing-indicator design below.
panel[, lag_avg_rating_month := pre_mean_rating]
panel[, `:=`(
  ln_pre_review_count=log(pre_review_count + 1),
  mr_prevcohort_visible_rate=fifelse(pre_review_count > 0L, mr_prevcohort_visible_n / pre_review_count, NA_real_),
  pre_review_eligible=as.integer(pre_review_count > 0L)
)]

# Cumulative historical review stock is measured just before each calendar month,
# including review history that predates the 2011 analysis window.
history_start <- reviews[, .(history_start=min(event_start)), by=HotelID]
hist_range <- merge(risk, history_start, by="HotelID", all.x=TRUE, sort=FALSE)
hist_grid <- hist_range[, {
  ds <- seq(as.Date(history_start), as.Date(paste0(last_base_ym, "-01")), by="month")
  .(event_start=as.IDate(ds))
}, by=HotelID]
hist_panel <- merge(hist_grid, month_out[, .(HotelID, event_start, review_count, rating_n, rating_sum, rating_sumsq)], by=c("HotelID", "event_start"), all.x=TRUE, sort=FALSE)
hist_panel[is.na(review_count), review_count:=0L]
hist_panel[is.na(rating_n), rating_n:=0L]
hist_panel[is.na(rating_sum), rating_sum:=0]
hist_panel[is.na(rating_sumsq), rating_sumsq:=0]
setorder(hist_panel, HotelID, event_start)
hist_panel[, `:=`(
  cumulative_reviews_start=shift(cumsum(review_count), fill=0L),
  cumulative_rating_n_start=shift(cumsum(rating_n), fill=0L),
  cumulative_rating_sum_start=shift(cumsum(rating_sum), fill=0),
  cumulative_rating_sumsq_start=shift(cumsum(rating_sumsq), fill=0)
), by=HotelID]
hist_panel[, lag_avg_rating_acc := fifelse(cumulative_rating_n_start > 0L, cumulative_rating_sum_start / cumulative_rating_n_start, NA_real_)]
hist_panel[, lag_sd_acc := fifelse(
  cumulative_rating_n_start > 1L,
  sqrt(pmax((cumulative_rating_sumsq_start - cumulative_rating_sum_start^2 / cumulative_rating_n_start) / (cumulative_rating_n_start - 1L), 0)),
  NA_real_
)]
hist_panel[, ln_lag_volumn_acc := fifelse(cumulative_reviews_start > 0L, log(cumulative_reviews_start), NA_real_)]
panel <- merge(panel, hist_panel[, .(HotelID, event_start, cumulative_reviews_start, cumulative_rating_n_start, cumulative_rating_sum_start, cumulative_rating_sumsq_start, ln_lag_volumn_acc, lag_avg_rating_acc, lag_sd_acc)], by=c("HotelID", "event_start"), all.x=TRUE, sort=FALSE)
panel[, ln_cumulative_reviews_start := log(cumulative_reviews_start + 1)]

# Materialize the remaining legacy names directly in the strict calendar DTA.
# Unlike pre_* variables, these retain legacy missingness for manual Route A/B
# style specifications rather than being used as zero-filled controls here.
panel[, `:=`(
  ln_recent_volumn=ln_review_count,
  recent_rating=mean_rating,
  recent_sd=sd_rating
)]

# Retain all at-risk months in the count model.  Missing prior-quality measures
# are explicitly flagged rather than causing zero-review months to be discarded.
for (v in c("pre_mean_rating", "pre_sd_rating", "pre_ln_mean_text_chars", "pre_ars_pool_visible", "pre_ars_within_current")) {
  panel[, (paste0(v, "_missing")) := as.integer(is.na(get(v)))]
  panel[is.na(get(v)), (v) := 0]
}
panel <- merge(panel, risk[, .(HotelID, final_review_count)], by="HotelID", all.x=TRUE, sort=FALSE)
panel[, sample_final_reviews_gt100 := 1L]
panel[, ym := (as.integer(format(as.Date(event_start), "%Y")) - 1960L) * 12L + as.integer(format(as.Date(event_start), "%m")) - 1L]
stopifnot(
  !anyDuplicated(panel, by=c("HotelID", "event_ym")),
  all(panel$final_review_count > 100),
  all(panel$mr_visible_start_n >= 0),
  # At a hotel's left analysis boundary, its immediately preceding raw-review
  # month can fall before the at-risk calendar panel and hence has a recorded
  # denominator of zero.  The reply-rate model explicitly excludes those
  # months (pre_review_eligible == 0).  Whenever the denominator is observed,
  # one review can contribute at most one valid response record.
  all(panel$mr_prevcohort_visible_n[panel$pre_review_count > 0] <= panel$pre_review_count[panel$pre_review_count > 0])
)
cat("Final rows:", nrow(panel), "; hotels:", uniqueN(panel$HotelID), "; zero-review months:", sum(panel$review_count==0L), "; pooled-ARS(2m) rows:", sum(!is.na(panel$ars_pool_visible)), "; pooled-ARS(3m) rows:", sum(!is.na(panel$ars_pool_visible_3m)), "; within-current ARS rows:", sum(!is.na(panel$ars_within_current)), "; dates:", min(panel$event_ym), max(panel$event_ym), "\n")
cat("Strict timing check: response flow is posted in month t-1 and used only in t.\n")
write_dta(panel, out, version=14)
cat("Wrote:", out, "\nCompleted:", format(Sys.time()), "\n")
