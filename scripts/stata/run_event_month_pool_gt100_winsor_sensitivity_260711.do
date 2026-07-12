*******************************************************
* M0.1 winsor sensitivity, direct Route A variable names.
*******************************************************
version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
capture drop ln_RevPAR_clean_w195 ln_lag_RevPAR_clean_w195
quietly _pctile ln_RevPAR_clean if !missing(ln_RevPAR_clean), p(1 95)
local y_p1 = r(r1)
local y_p95 = r(r2)
gen double ln_RevPAR_clean_w195 = ln_RevPAR_clean
replace ln_RevPAR_clean_w195 = min(max(ln_RevPAR_clean, `y_p1'), `y_p95') if !missing(ln_RevPAR_clean)
quietly _pctile ln_lag_RevPAR_clean if !missing(ln_lag_RevPAR_clean), p(1 95)
local ly_p1 = r(r1)
local ly_p95 = r(r2)
gen double ln_lag_RevPAR_clean_w195 = ln_lag_RevPAR_clean
replace ln_lag_RevPAR_clean_w195 = min(max(ln_lag_RevPAR_clean, `ly_p1'), `ly_p95') if !missing(ln_lag_RevPAR_clean)
log using "`p'/stata-log/run_event_month_pool_gt100_winsor_sensitivity_260711.log", text replace
estimates clear
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store W199
reghdfe ln_RevPAR_clean_w595 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store W595
reghdfe ln_RevPAR_clean_w195 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store W195
estimates table W199 W595 W195, b(%9.6f) se(%9.6f) stats(N r2_a)
log close
