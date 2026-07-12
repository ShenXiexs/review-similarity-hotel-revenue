*******************************************************
* Management-response mechanisms using the direct Route B
* variable interface: lag_mr_*, sim_mean, and recent_*.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
capture which ppmlhdfe
if _rc {
    display as error "ppmlhdfe is required for the review-count model."
    exit 199
}
capture drop ln_lag_mr_count ln_recent_volumn_w199 ln_recent_volumn_w595 ln_recent_volumn_w195
gen double ln_lag_mr_count = ln(lag_mr_count + 1)
quietly _pctile ln_recent_volumn if !missing(ln_recent_volumn), p(1 99)
local count_p1 = r(r1)
local count_p99 = r(r2)
gen double ln_recent_volumn_w199 = ln_recent_volumn
replace ln_recent_volumn_w199 = min(max(ln_recent_volumn, `count_p1'), `count_p99') if !missing(ln_recent_volumn)
quietly _pctile ln_recent_volumn if !missing(ln_recent_volumn), p(5 95)
local count_p5 = r(r1)
local count_p95 = r(r2)
gen double ln_recent_volumn_w595 = ln_recent_volumn
replace ln_recent_volumn_w595 = min(max(ln_recent_volumn, `count_p5'), `count_p95') if !missing(ln_recent_volumn)
quietly _pctile ln_recent_volumn if !missing(ln_recent_volumn), p(1 95)
local count_p195 = r(r1)
local count_p995 = r(r2)
gen double ln_recent_volumn_w195 = ln_recent_volumn
replace ln_recent_volumn_w195 = min(max(ln_recent_volumn, `count_p195'), `count_p995') if !missing(ln_recent_volumn)

log using "`p'/stata-log/run_event_month_pool_gt100_reply_mechanisms_260711.log", text replace
estimates clear

* Review generation: count model and winsorized log-count checks.
ppmlhdfe recent_volumn lag_mr_any ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V1_ppml_any
ppmlhdfe recent_volumn lag_mr_quick7_share ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(recent_volumn, lag_mr_quick7_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V2_ppml_rate7
ppmlhdfe recent_volumn ln_lag_mr_count ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V3_ppml_lnn
reghdfe ln_recent_volumn_w199 lag_mr_any ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(ln_recent_volumn_w199), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V4_log_w199
reghdfe ln_recent_volumn_w595 lag_mr_any ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(ln_recent_volumn_w595), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V5_log_w595
reghdfe ln_recent_volumn_w195 lag_mr_any ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(ln_recent_volumn_w195), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V6_log_w195

* New-content homogeneity: sim_mean is the rebuilt pooled ARS in the DTA.
reghdfe sim_mean lag_mr_any ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C1_pool_any
reghdfe sim_mean lag_mr_quick7_share ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_quick7_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C2_pool_rate7
reghdfe sim_mean ln_lag_mr_count ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C3_pool_lnn

estimates table V1_ppml_any V2_ppml_rate7 V3_ppml_lnn V4_log_w199 V5_log_w595 V6_log_w195 C1_pool_any C2_pool_rate7 C3_pool_lnn, b(%9.6f) se(%9.6f) stats(N r2_a)
log close
