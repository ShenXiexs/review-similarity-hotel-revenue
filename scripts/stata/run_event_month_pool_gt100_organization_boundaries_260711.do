*******************************************************
* Route A organization boundaries, rebuilt pooled-ARS panel.
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
log using "`p'/stata-log/run_event_month_pool_gt100_organization_boundaries_260711.log", text replace
estimates clear

* O1-O4 chain form and size.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.chain ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, chain), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O1_chain
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.independent ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, independent), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O2_independent
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.chain_small ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, chain_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O3_smallchain
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.chain3_small ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, chain3_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O4_chain3

* O5-O7 star-class boundaries.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.star_class_final ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, star_class_final), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O5_starclass
reghdfe ln_RevPAR_clean_w199 c.sim_mean##ib2.star_class_bucket3 ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, star_class_bucket3), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O6_starbucket
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_star4 ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_star4), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O7_highstar

* O8-O10 quality level and local quality status.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_avg_rating_acc ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_avg_rating_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O8_qualitylevel
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_quality_ym ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_quality_ym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O8_qualityym
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_quality_cityym ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_quality_cityym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O9_qualitycity
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_quality_zipym ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_quality_zipym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O10_qualityzip

* O11-O13 rank, evaluation category, and accumulated popularity.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_rank_status ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_rank_status), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O11_rank
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.hotel_evaluation_factor ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, hotel_evaluation_factor), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O12_evaluation
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_lag_volumn_acc ln_recent_volumn recent_rating recent_sd lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, ln_lag_volumn_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O13_popularity
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_popularity ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_popularity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O13_popularitycell

* Grouped O13 slopes.
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if high_popularity == 0 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O13_low
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if high_popularity == 1 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O13_high

estimates table O1_chain O2_independent O3_smallchain O4_chain3 O5_starclass O6_starbucket O7_highstar O8_qualitylevel O8_qualityym O9_qualitycity O10_qualityzip O11_rank O12_evaluation O13_popularity O13_popularitycell O13_low O13_high, b(%9.4f) se stats(N r2_a)
log close
