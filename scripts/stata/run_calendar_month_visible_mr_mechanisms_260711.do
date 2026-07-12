version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"

use "`p'/outputs/core_simi_260501/data/calendar_month_pool_visible_mr_gt100_panel_260711.dta", clear
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen ym = monthly(event_ym, "YM")
format ym %tm
capture which ppmlhdfe
if _rc {
    display as error "ppmlhdfe is required for the review-count model."
    exit 199
}

* All controls are measured before the outcome month.  Missing pre-month text
* and quality measures are zero-filled with explicit missingness indicators in
* the DTA so that zero-review months remain in the count analysis.
local X ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_pool_visible pre_ars_pool_visible_missing

* Winsorization is only a linear-log-count sensitivity check; PPML remains the
* primary count specification and retains all zero-review months.
capture drop ln_review_count_w199 ln_review_count_w595 ln_review_count_w195
winsor2 ln_review_count, cuts(1 99) suffix(_w199)
winsor2 ln_review_count, cuts(5 95) suffix(_w595)
winsor2 ln_review_count, cuts(1 95) suffix(_w195)

log using "`p'/stata-log/run_calendar_month_visible_mr_mechanisms_260711.log", text replace
estimates clear

* A. Review generation. Treatment is response activity posted in t-1 and
* observable before month t begins; it never uses a reply posted during t.
ppmlhdfe review_count mr_visible_start_any `X', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V1_ppml_any
ppmlhdfe review_count ln_mr_visible_start_n `X', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V2_ppml_lnn
ppmlhdfe review_count mr_prevcohort_visible_rate `X' if pre_review_eligible == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V3_ppml_rate
reghdfe ln_review_count_w199 mr_visible_start_any `X', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V4_log_w199
reghdfe ln_review_count_w595 mr_visible_start_any `X', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V5_log_w595
reghdfe ln_review_count_w195 mr_visible_start_any `X', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V6_log_w195

* B. New-content homogeneity. Higher pooled ARS means current-month review text
* is more similar within the current-plus-previous-month pooled review set.
* It is bounded, so it is not winsorized.
reghdfe ars_pool_visible mr_visible_start_any `X' if !missing(ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C1_pool_any
reghdfe ars_pool_visible ln_mr_visible_start_n `X' if !missing(ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C2_pool_lnn
reghdfe ars_pool_visible mr_prevcohort_visible_rate `X' if pre_review_eligible == 1 & !missing(ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C3_pool_rate

* Conditional composition check: current count is a possible response mediator,
* so this model is secondary and does not replace C1-C3.
reghdfe ars_pool_visible mr_visible_start_any ln_review_count `X' if !missing(ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C4_pool_any_condcount

estimates table V1_ppml_any V2_ppml_lnn V3_ppml_rate V4_log_w199 V5_log_w595 V6_log_w195 C1_pool_any C2_pool_lnn C3_pool_rate C4_pool_any_condcount, b(%9.6f) se(%9.6f) stats(N r2_a)
log close
