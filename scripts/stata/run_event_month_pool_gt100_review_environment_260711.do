*******************************************************
* Route A review-environment boundaries, pooled-ARS panel.
* Self-contained; every specification lists controls explicitly.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
log using "`p'/stata-log/run_event_month_pool_gt100_review_environment_260711.log", text replace
estimates clear

* E1-E6 dispersion and sentiment boundaries.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.recent_sd_10 ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, recent_sd_10), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E1_scope10sd
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.prevvis_recent_sd ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, prevvis_recent_sd), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E2_prevvis_sd
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.sent_avg_bing_10 ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, sent_avg_bing_10), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E3_scope10bing
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.sent_net_pos_bing_10 ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, sent_net_pos_bing_10), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E4_scope10net
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.prevvis_sent_avg_bing ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, prevvis_sent_avg_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E5_prevvisbing
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.prevvis_sent_net_pos_bing ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, prevvis_sent_net_pos_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E6_prevvisnet

* Grouped E2 slopes, following the original review-environment grouped design.
capture drop e2_cell_median e2_high
bysort Zip ym: egen double e2_cell_median = median(prevvis_recent_sd)
gen byte e2_high = prevvis_recent_sd > e2_cell_median if !missing(prevvis_recent_sd, e2_cell_median)
replace e2_high = 0 if !missing(prevvis_recent_sd, e2_cell_median) & e2_high == 0
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if e2_high == 0 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E2_low
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if e2_high == 1 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E2_high

estimates table E1_scope10sd E2_prevvis_sd E3_scope10bing E4_scope10net E5_prevvisbing E6_prevvisnet E2_low E2_high, b(%9.4f) se stats(N r2_a)
log close
