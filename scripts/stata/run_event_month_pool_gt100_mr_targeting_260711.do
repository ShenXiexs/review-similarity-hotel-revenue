*******************************************************
* Route B management-response targeting, pooled-ARS panel.
* Self-contained; every regression lists controls explicitly.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
log using "`p'/stata-log/run_event_month_pool_gt100_mr_targeting_260711.log", text replace
estimates clear

* T1-T3: ARS revenue moderation by complaint, service, and room targeting.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_rep_complaint_share lag_mr_any lag_mr_count lag_mr_quick7_share ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_rep_complaint_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T1_complaint
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_rep_service_share lag_mr_any lag_mr_count lag_mr_quick7_share ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_rep_service_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T2_service
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_rep_room_share lag_mr_any lag_mr_count lag_mr_quick7_share ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_rep_room_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T3_room

* T4-T6: the original Route B targeting production outcomes.
reghdfe ln_recent_volumn lag_mr_rep_complaint_share lag_mr_rep_service_share lag_mr_rep_room_share lag_mr_rep_clean_share lag_mr_rep_value_share lag_mr_rate lag_mr_count ln_lag_mr_words recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(ln_recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T4_volume
reghdfe sim_mean lag_mr_rep_complaint_share lag_mr_rep_service_share lag_mr_rep_room_share lag_mr_rep_clean_share lag_mr_rep_value_share lag_mr_rate lag_mr_count ln_lag_mr_words ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T5_pool
reghdfe sent_net_pos_bing lag_mr_rep_complaint_share lag_mr_rep_service_share lag_mr_rep_room_share lag_mr_rep_clean_share lag_mr_rep_value_share lag_mr_rate lag_mr_count ln_lag_mr_words ln_recent_volumn sim_mean recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sent_net_pos_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T6_sentiment

* Grouped T1 slopes as in the original Route B targeting file.
capture drop t1_cell_median t1_high
bysort Zip ym: egen double t1_cell_median = median(lag_mr_rep_complaint_share) if lag_mr_any == 1
gen byte t1_high = lag_mr_rep_complaint_share > t1_cell_median if lag_mr_any == 1 & !missing(t1_cell_median)
replace t1_high = 0 if lag_mr_any == 1 & !missing(t1_cell_median) & t1_high == 0
reghdfe ln_RevPAR_clean_w199 sim_mean lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if t1_high == 0 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T1_low
reghdfe ln_RevPAR_clean_w199 sim_mean lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if t1_high == 1 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T1_high

estimates table T1_complaint T2_service T3_room T4_volume T5_pool T6_sentiment T1_low T1_high, b(%9.4f) se stats(N r2_a)
log close
