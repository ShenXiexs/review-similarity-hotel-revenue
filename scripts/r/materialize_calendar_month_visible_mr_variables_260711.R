#!/usr/bin/env Rscript
# Add the strict-reply analysis variables to an already-built calendar panel.
# This is algebraically identical to the corresponding section of
# build_calendar_month_pool_visible_mr_gt100_260711.R and avoids rebuilding
# costly text vectors when only the final DTA needs to be refreshed.
suppressPackageStartupMessages({ library(data.table); library(haven) })

root <- "/Users/samxie/Research/ReviewSimi_Sales/Code"
path <- file.path(root, "outputs/core_simi_260501/data/calendar_month_pool_visible_mr_gt100_panel_260711.dta")
stopifnot(file.exists(path))

panel <- as.data.table(read_dta(path))
need <- c("HotelID", "event_start", "mr_visible_start_n", "mr_prevcohort_visible_n", "pre_review_count", "ars_within_current")
stopifnot(all(need %chin% names(panel)))

# Responses visible at the start of t were posted in t-1.  A response is
# either to a review written in t-1 or to an older review (response dates are
# already validated to be no earlier than the linked review date).
panel[, mr_visible_start_oldreview_n := pmax(mr_visible_start_n - mr_prevcohort_visible_n, 0L)]
panel[, `:=`(
  mr_prevcohort_visible_any = as.integer(mr_prevcohort_visible_n > 0L),
  mr_visible_start_oldreview_any = as.integer(mr_visible_start_oldreview_n > 0L),
  ln_mr_visible_start_oldreview_n = log(mr_visible_start_oldreview_n + 1)
)]

setorder(panel, HotelID, event_start)
panel[, pre_ars_within_current := shift(ars_within_current), by=HotelID]
panel[, pre_ars_within_current_missing := as.integer(is.na(pre_ars_within_current))]
panel[is.na(pre_ars_within_current), pre_ars_within_current := 0]

stopifnot(
  !anyDuplicated(panel, by=c("HotelID", "event_ym")),
  all(panel$mr_prevcohort_visible_n[panel$pre_review_count > 0] <= panel$pre_review_count[panel$pre_review_count > 0]),
  all(panel$mr_visible_start_oldreview_n >= 0)
)
write_dta(panel, path, version=14)
cat("Materialized strict visible-reply variables in:", path, "\n")
