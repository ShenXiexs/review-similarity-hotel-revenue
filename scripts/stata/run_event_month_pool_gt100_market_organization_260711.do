version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
log using "`p'/stata-log/run_event_month_pool_gt100_market_organization_260711.log", text replace
local C ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199
estimates clear
* M0.1-M9 market boundaries, pooled ARS only.
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M01
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.ln_avg_com_RevPAR ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lnRevenue_lag_month_w199 if !missing(ars_pool_ev,ln_avg_com_RevPAR), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M02
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_comp_zip_focus100 `C' if !missing(ars_pool_ev,high_comp_zip_focus100), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M1_zipcomp
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_comp_city_focus100 `C' if !missing(ars_pool_ev,high_comp_city_focus100), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M2_citycomp
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.zip_n_full_c `C' if !missing(ars_pool_ev,zip_n_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M3_zipthick
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.city_n_full_c `C' if !missing(ars_pool_ev,city_n_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M4_citythick
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.ln_comp_zip_mean_excl_full `C' if !missing(ars_pool_ev,ln_comp_zip_mean_excl_full), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M5_ziprev
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.ln_comp_city_mean_excl_full `C' if !missing(ars_pool_ev,ln_comp_city_mean_excl_full), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M6_cityrev
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.gap_zip_mean_full_c `C' if !missing(ars_pool_ev,gap_zip_mean_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M7_zipgap
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.gap_city_mean_full_c `C' if !missing(ars_pool_ev,gap_city_mean_full_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M8_citygap
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.price_gap_c `C' if !missing(ars_pool_ev,price_gap_c), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M9_pricegap
* M1-M13 organization boundaries, pooled ARS only.
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.chain `C' if !missing(ars_pool_ev,chain), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O1_chain
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.independent `C' if !missing(ars_pool_ev,independent), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O2_independent
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.chain_small `C' if !missing(ars_pool_ev,chain_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O3_smallchain
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.chain3_small `C' if !missing(ars_pool_ev,chain3_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O4_chain3
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.star_class_final `C' if !missing(ars_pool_ev,star_class_final), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O5_starclass
reghdfe lnRevenue_current_w199 c.ars_pool_ev##ib2.star_class_bucket3 `C' if !missing(ars_pool_ev,star_class_bucket3), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O6_starbucket
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_star4 `C' if !missing(ars_pool_ev,high_star4), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O7_highstar
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.lag_avg_rating_acc `C' if !missing(ars_pool_ev,lag_avg_rating_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O8_qualitylevel
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_quality_ym `C' if !missing(ars_pool_ev,high_quality_ym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O8_qualityym
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_quality_cityym `C' if !missing(ars_pool_ev,high_quality_cityym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O9_qualitycity
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_quality_zipym `C' if !missing(ars_pool_ev,high_quality_zipym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O10_qualityzip
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_rank_status `C' if !missing(ars_pool_ev,high_rank_status), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O11_rank
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.hotel_evaluation_factor `C' if !missing(ars_pool_ev,hotel_evaluation_factor), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O12_evaluation
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.ln_lag_volumn_acc ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(ars_pool_ev,ln_lag_volumn_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O13_popularity
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.high_popularity `C' if !missing(ars_pool_ev,high_popularity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store O13_popularitycell
estimates table M01 M02 M1_zipcomp M2_citycomp M3_zipthick M4_citythick M5_ziprev M6_cityrev M7_zipgap M8_citygap M9_pricegap O1_chain O2_independent O3_smallchain O4_chain3 O5_starclass O6_starbucket O7_highstar O8_qualitylevel O8_qualityym O9_qualitycity O10_qualityzip O11_rank O12_evaluation O13_popularity O13_popularitycell, b(%9.4f) se stats(N r2_a)
log close
