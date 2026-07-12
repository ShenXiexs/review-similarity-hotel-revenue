*******************************************************
* Route A market boundaries, rebuilt pooled-ARS panel.
* Self-contained: load, prepare, all specifications explicit.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
log using "`p'/stata-log/run_event_month_pool_gt100_market_boundaries_260711.log", text replace
estimates clear

* M0.1 pooled-ARS baseline.
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M01

* M0.2 competitor RevPAR level.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_avg_com_RevPAR ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_lag_RevPAR_clean_w199 if !missing(sim_mean, ln_avg_com_RevPAR), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M02

* M1-M9 market-boundary interactions.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_comp_zip_focus100 ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_comp_zip_focus100), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M1_zipcomp
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_comp_city_focus100 ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, high_comp_city_focus100), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M2_citycomp
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.zip_n_full_c ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, zip_n_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M3_zipthick
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.city_n_full_c ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, city_n_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M4_citythick
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_comp_zip_mean_excl_full ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, ln_comp_zip_mean_excl_full), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M5_ziprev
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_comp_city_mean_excl_full ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, ln_comp_city_mean_excl_full), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M6_cityrev
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.gap_zip_mean_full_c ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, gap_zip_mean_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M7_zipgap
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.gap_city_mean_full_c ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, gap_city_mean_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M8_citygap
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.price_gap_c ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, price_gap_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M9_pricegap

* Grouped M1 slopes, following the Route A grouped-boundary convention.
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if high_comp_zip_focus100 == 0 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M1_low
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if high_comp_zip_focus100 == 1 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M1_high

* Grouped M5 and M6 slopes within ZIP-month and city-month cells.
capture drop m5_cell_median m5_high m6_cell_median m6_high
bysort Zip ym: egen double m5_cell_median = median(ln_comp_zip_mean_excl_full)
gen byte m5_high = ln_comp_zip_mean_excl_full > m5_cell_median if !missing(ln_comp_zip_mean_excl_full, m5_cell_median)
replace m5_high = 0 if !missing(ln_comp_zip_mean_excl_full, m5_cell_median) & m5_high == 0
bysort CityID ym: egen double m6_cell_median = median(ln_comp_city_mean_excl_full)
gen byte m6_high = ln_comp_city_mean_excl_full > m6_cell_median if !missing(ln_comp_city_mean_excl_full, m6_cell_median)
replace m6_high = 0 if !missing(ln_comp_city_mean_excl_full, m6_cell_median) & m6_high == 0
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if m5_high == 0 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M5_low
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if m5_high == 1 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M5_high
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if m6_high == 0 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M6_low
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if m6_high == 1 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M6_high

estimates table M01 M02 M1_zipcomp M2_citycomp M3_zipthick M4_citythick M5_ziprev M6_cityrev M7_zipgap M8_citygap M9_pricegap M1_low M1_high M5_low M5_high M6_low M6_high, b(%9.4f) se stats(N r2_a)
log close
