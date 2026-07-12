version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"

use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
capture which ppmlhdfe
if _rc {
    display as error "ppmlhdfe is required for the review-count model."
    exit 199
}

* The reply variables are already mapped to the interval from the previous
* review event to the current one.  Form controls from that previous event.
sort hotel_id_num event_seq
foreach v in ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ars_pool_ev {
    capture drop pre_`v'
    by hotel_id_num (event_seq): gen double pre_`v' = `v'[_n-1] if _n > 1
}
capture drop ln_event_gap ln_pmr_activity_n
gen double ln_event_gap = ln(event_gap_months) if event_gap_months > 0
gen double ln_pmr_activity_n = ln(pmr_activity_n + 1)

* Winsorization is a reporting robustness check for log review count only.
capture drop ev_ln_review_count_w199 ev_ln_review_count_w595 ev_ln_review_count_w195
winsor2 ev_ln_review_count, cuts(1 99) suffix(_w199)
winsor2 ev_ln_review_count, cuts(5 95) suffix(_w595)
winsor2 ev_ln_review_count, cuts(1 95) suffix(_w195)

local X pre_ev_ln_review_count pre_ev_mean_rating pre_ev_sd_rating pre_ev_ln_mean_text_chars pre_ars_pool_ev ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_event_gap
local Xmiss pre_ev_ln_review_count, pre_ev_mean_rating, pre_ev_sd_rating, pre_ev_ln_mean_text_chars, pre_ars_pool_ev, ln_lag_volumn_acc, lag_avg_rating_acc, lag_sd_acc, ln_avg_com_RevPAR, ln_event_gap
local S event_seq > 1 & !missing(`Xmiss')

log using "`p'/stata-log/run_event_month_pool_gt100_reply_mechanisms_260711.log", text replace
estimates clear

* A. Next-event review generation: count outcome (primary) and winsorized log-count checks.
ppmlhdfe ev_review_count pmr_activity_any `X' if `S', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V1_ppml_any
ppmlhdfe ev_review_count pmr_cohort_rate7 `X' if `S' & !missing(pmr_cohort_rate7), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V2_ppml_rate7
ppmlhdfe ev_review_count ln_pmr_activity_n `X' if `S', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V3_ppml_lnn
reghdfe ev_ln_review_count_w199 pmr_activity_any `X' if `S', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V4_log_w199
reghdfe ev_ln_review_count_w595 pmr_activity_any `X' if `S', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V5_log_w595
reghdfe ev_ln_review_count_w195 pmr_activity_any `X' if `S', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V6_log_w195

* B. New-content homogeneity: higher pooled ARS means the current event is
* more similar to its preceding review history.  Do not winsor this bounded outcome.
reghdfe ars_pool_ev pmr_activity_any `X' if `S' & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C1_pool_any
reghdfe ars_pool_ev pmr_cohort_rate7 `X' if `S' & !missing(ars_pool_ev,pmr_cohort_rate7), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C2_pool_rate7
reghdfe ars_pool_ev ln_pmr_activity_n `X' if `S' & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C3_pool_lnn

* Conditional composition check: this adds current review volume, a potential
* mediator, and is therefore secondary to C1-C3 rather than a total-effect model.
reghdfe ars_pool_ev pmr_activity_any ev_ln_review_count `X' if `S' & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C4_pool_any_condvol

estimates table V1_ppml_any V2_ppml_rate7 V3_ppml_lnn V4_log_w199 V5_log_w595 V6_log_w195 C1_pool_any C2_pool_rate7 C3_pool_lnn C4_pool_any_condvol, b(%9.6f) se(%9.6f) stats(N r2_a)
log close
