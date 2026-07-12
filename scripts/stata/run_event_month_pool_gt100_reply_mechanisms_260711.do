************************************************************
* Management replies -> subsequent review generation/content
*
* Unit: hotel-calendar-month t.  The treatment is restricted to
* replies posted in t-1, hence observable before t starts.  It never
* contains a response posted in t or a review posted in t.
*
* Quantity primary outcome: review_count (including zero-review months).
* Content primary outcome: ars_within_current, the pooled mean cosine
* similarity among new reviews written in t only.  It has no review-text
* overlap with the t-1 treatment/cohort.  Two-/three-month pooled ARS is
* retained only as a clearly labelled secondary check.
************************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close

local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/calendar_month_pool_visible_mr_gt100_panel_260711.dta", clear

* Fail early if the strict month-start panel has not been rebuilt.
capture confirm variable review_count
if _rc {
    display as error "Missing strict visible-reply variables. Run scripts/r/build_calendar_month_pool_visible_mr_gt100_260711.R first."
    exit 111
}
capture confirm variable mr_prevcohort_visible_rate
if _rc {
    display as error "Missing mr_prevcohort_visible_rate. Rebuild the strict visible-reply DTA first."
    exit 111
}

capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen int ym = monthly(event_ym, "YM")
format ym %tm
xtset hotel_id_num ym

* Make the analysis self-contained even if it is run with the preceding DTA.
* The R builder writes these variables permanently; the algebra below is an
* exact fallback because every visible reply is either to a t-1 review or to
* an older review.  No current-month observation is used.
capture confirm variable mr_visible_start_oldreview_n
if _rc gen long mr_visible_start_oldreview_n = mr_visible_start_n - mr_prevcohort_visible_n
replace mr_visible_start_oldreview_n = 0 if mr_visible_start_oldreview_n < 0 | missing(mr_visible_start_oldreview_n)
capture confirm variable mr_prevcohort_visible_any
if _rc gen byte mr_prevcohort_visible_any = mr_prevcohort_visible_n > 0
capture confirm variable mr_visible_start_oldreview_any
if _rc gen byte mr_visible_start_oldreview_any = mr_visible_start_oldreview_n > 0
capture confirm variable ln_mr_visible_start_oldreview_n
if _rc gen double ln_mr_visible_start_oldreview_n = ln(mr_visible_start_oldreview_n + 1)
capture confirm variable pre_ars_within_current
if _rc gen double pre_ars_within_current = L.ars_within_current
capture confirm variable pre_ars_within_current_missing
if _rc gen byte pre_ars_within_current_missing = missing(pre_ars_within_current)
replace pre_ars_within_current = 0 if missing(pre_ars_within_current)

capture which ppmlhdfe
if _rc {
    display as error "ppmlhdfe is required for the review-count primary models."
    exit 199
}
capture which reghdfe
if _rc {
    display as error "reghdfe is required for the linear content models."
    exit 199
}

* PPML is primary for count outcomes and keeps every at-risk month, including
* months with zero reviews.  The following log-count outcomes are only the
* previously requested winsorized linear sensitivity checks.
capture drop ln_review_count_w199 ln_review_count_w595 ln_review_count_w195
quietly _pctile ln_review_count if !missing(ln_review_count), p(1 99)
local count_p1 = r(r1)
local count_p99 = r(r2)
gen double ln_review_count_w199 = ln_review_count
replace ln_review_count_w199 = min(max(ln_review_count, `count_p1'), `count_p99') if !missing(ln_review_count)
quietly _pctile ln_review_count if !missing(ln_review_count), p(5 95)
local count_p5 = r(r1)
local count_p95 = r(r2)
gen double ln_review_count_w595 = ln_review_count
replace ln_review_count_w595 = min(max(ln_review_count, `count_p5'), `count_p95') if !missing(ln_review_count)
quietly _pctile ln_review_count if !missing(ln_review_count), p(1 95)
local count_p195 = r(r1)
local count_p995 = r(r2)
gen double ln_review_count_w195 = ln_review_count
replace ln_review_count_w195 = min(max(ln_review_count, `count_p195'), `count_p995') if !missing(ln_review_count)

* Grouped reply dose: no reply, 1--3 visible replies, and 4+ visible replies.
* This is a grouped specification, not an interaction.
capture drop mr_visible_intensity_group delta_ars_pool_visible L1_mr_visible_start_any L2_mr_visible_start_any
gen byte mr_visible_intensity_group = 0 if mr_visible_start_n == 0
replace mr_visible_intensity_group = 1 if inrange(mr_visible_start_n, 1, 3)
replace mr_visible_intensity_group = 2 if mr_visible_start_n >= 4
label define mr_visible_intensity_group_lbl 0 "0 replies" 1 "1-3 replies" 2 "4+ replies", replace
label values mr_visible_intensity_group mr_visible_intensity_group_lbl
gen double delta_ars_pool_visible = ars_pool_visible - L.ars_pool_visible if !missing(ars_pool_visible, L.ars_pool_visible)
gen byte L1_mr_visible_start_any = L.mr_visible_start_any
gen byte L2_mr_visible_start_any = L2.mr_visible_start_any

log using "`p'/stata-log/run_event_month_pool_gt100_reply_mechanisms_260711.log", text replace
estimates clear

* ----------------------------------------------------------
* A. Quantity of newly generated reviews in t.
* A1--A3 are the primary timing-safe specifications.
* All controls are measured before t begins.  pre_review_count both controls
* for the t-1 review opportunity and is the denominator for A3.
* ----------------------------------------------------------
ppmlhdfe review_count mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store Q1_ppml_any

ppmlhdfe review_count ln_mr_visible_start_n ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store Q2_ppml_lnn

ppmlhdfe review_count mr_prevcohort_visible_rate ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if pre_review_eligible == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store Q3_ppml_prevcohort_rate

* A4 is a vintage-decomposition diagnostic.  It uses replies posted in t-1
* to reviews written before t-1, so it cannot scale mechanically with the
* number of reviews written in t-1.  It remains observational.
ppmlhdfe review_count ln_mr_visible_start_oldreview_n ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store Q4_ppml_oldreview

reghdfe ln_review_count_w199 mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store Q5_log_w199

reghdfe ln_review_count_w595 mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store Q6_log_w595

reghdfe ln_review_count_w195 mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store Q7_log_w195

* ----------------------------------------------------------
* B. Content generated by new reviews in t.
* ars_within_current is the primary content outcome.  It is defined only
* when at least two current-month reviews have valid vectors, so these are
* conditional-content associations after the separate count analysis.
* Do not control for current review_count in B1--B5: it can mediate a reply
* effect and conditioning on it would change the estimand.
* ----------------------------------------------------------
reghdfe ars_within_current mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C1_within_any

reghdfe ars_within_current ln_mr_visible_start_n ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C2_within_lnn

reghdfe ars_within_current mr_prevcohort_visible_rate ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if pre_review_eligible == 1 & !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C3_within_prevcohort_rate

reghdfe ars_within_current ib0.mr_visible_intensity_group ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C4_within_groups

reghdfe ars_within_current ln_mr_visible_start_oldreview_n ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C5_within_oldreview

* B6 is only a composition sensitivity check: current review count is a
* plausible mediator of the reply -> content pathway.
reghdfe ars_within_current mr_visible_start_any ln_review_count ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C6_within_condcount

* B7 tests persistence without using future reply information.
reghdfe ars_within_current mr_visible_start_any L1_mr_visible_start_any L2_mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_within_current, L1_mr_visible_start_any, L2_mr_visible_start_any), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C7_within_lags

* ----------------------------------------------------------
* C. Secondary pooled-window checks.  These answer the original pool-only
* question but are not primary because ars_pool_visible embeds t-1 review
* text, which also helps determine the t-1 reply treatment.
* ----------------------------------------------------------
reghdfe ars_pool_visible mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store S1_pool2_any

reghdfe delta_ars_pool_visible mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(delta_ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store S2_pool2_change

reghdfe ars_pool_visible_3m mr_visible_start_any ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_within_current pre_ars_within_current_missing if !missing(ars_pool_visible_3m), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store S3_pool3_any

estimates table Q1_ppml_any Q2_ppml_lnn Q3_ppml_prevcohort_rate Q4_ppml_oldreview Q5_log_w199 Q6_log_w595 Q7_log_w195, b(%9.6f) se(%9.6f) stats(N r2_a)
estimates table C1_within_any C2_within_lnn C3_within_prevcohort_rate C4_within_groups C5_within_oldreview C6_within_condcount C7_within_lags S1_pool2_any S2_pool2_change S3_pool3_any, b(%9.6f) se(%9.6f) stats(N r2_a)
log close
