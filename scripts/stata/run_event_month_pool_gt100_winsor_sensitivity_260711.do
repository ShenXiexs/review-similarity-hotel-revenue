version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"

use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"

* Parallel sensitivity specifications: same percentile caps for the outcome and its lag.
winsor2 lnRevenue_current, cuts(1 95) suffix(_w195)
winsor2 lnRevenue_lag_month, cuts(1 95) suffix(_w195)

log using "`p'/stata-log/run_event_month_pool_gt100_winsor_sensitivity_260711.log", text replace
estimates clear

* M0.1: change only the symmetric outcome/lag winsorization rule.
reghdfe lnRevenue_current_w199 ars_pool_ev ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store W199
reghdfe lnRevenue_current_w595 ars_pool_ev ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w595 if !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store W595
reghdfe lnRevenue_current_w195 ars_pool_ev ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w195 if !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store W195

estimates table W199 W595 W195, b(%9.6f) se(%9.6f) stats(N r2_a)
log close
