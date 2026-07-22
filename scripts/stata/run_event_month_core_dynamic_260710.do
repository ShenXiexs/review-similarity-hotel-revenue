version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_ars_mr_panel_260710.dta", clear
log using "`p'/stata-log/run_event_month_core_dynamic_260710.log", text replace

keep if cs_sample_focus100 == 1
encode HotelID, gen(hotel_id_num)
gen ym = monthly(event_ym,"YM")
format ym %tm
quietly _pctile lnRevenue_current if !missing(lnRevenue_current), p(1 99)
gen double lnRevenue_current_w199 = min(max(lnRevenue_current,r(r1)),r(r2)) if !missing(lnRevenue_current)
quietly _pctile lnRevenue_lag_month if !missing(lnRevenue_lag_month), p(1 99)
gen double lnRevenue_lag_month_w199 = min(max(lnRevenue_lag_month,r(r1)),r(r2)) if !missing(lnRevenue_lag_month)
quietly _pctile lnRevenue_next_calendar if !missing(lnRevenue_next_calendar), p(1 99)
gen double lnRevenue_next_calendar_w199 = min(max(lnRevenue_next_calendar,r(r1)),r(r2)) if !missing(lnRevenue_next_calendar)

* M0.1: event-aligned controls, hotel and calendar year-month fixed effects.
reghdfe lnRevenue_current_w199 ars_cross_ev ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(ars_cross_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M01_cross
reghdfe lnRevenue_current_w199 ars_pool_ev ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store M01_pool

* Route B: previous-event response activity and wording predict current ARS.
reghdfe ars_cross_ev pmr_any pmr_activity_n pmr_cohort_rate7 pmr_text_invite_zf pmr_text_recovery_zf pmr_target_complaint_zf pmr_target_service_zf pmr_target_room_zf pmr_target_cleanliness_zf pmr_target_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating sent_avg_bing ln_lag_volumn_acc if !missing(ars_cross_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D1_cross
reghdfe ars_pool_ev pmr_any pmr_activity_n pmr_cohort_rate7 pmr_text_invite_zf pmr_text_recovery_zf pmr_target_complaint_zf pmr_target_service_zf pmr_target_room_zf pmr_target_cleanliness_zf pmr_target_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating sent_avg_bing ln_lag_volumn_acc if !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D1_pool

* Sequential revenue models: next calendar month outcome, not mediation claims.
reghdfe lnRevenue_next_calendar_w199 ars_cross_ev pmr_any pmr_activity_n pmr_cohort_rate7 pmr_text_invite_zf pmr_text_recovery_zf pmr_target_complaint_zf pmr_target_service_zf pmr_target_room_zf pmr_target_cleanliness_zf pmr_target_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,ars_cross_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D2_cross
reghdfe lnRevenue_next_calendar_w199 ars_pool_ev pmr_any pmr_activity_n pmr_cohort_rate7 pmr_text_invite_zf pmr_text_recovery_zf pmr_target_complaint_zf pmr_target_service_zf pmr_target_room_zf pmr_target_cleanliness_zf pmr_target_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D2_pool
reghdfe lnRevenue_next_calendar_w199 c.ars_cross_ev##c.pmr_cohort_rate7 c.ars_cross_ev##c.pmr_text_invite_zf c.ars_cross_ev##c.pmr_text_recovery_zf c.ars_cross_ev##c.pmr_target_complaint_zf c.ars_cross_ev##c.pmr_target_service_zf c.ars_cross_ev##c.pmr_target_room_zf c.ars_cross_ev##c.pmr_target_cleanliness_zf c.ars_cross_ev##c.pmr_target_value_zf pmr_any pmr_activity_n ev_ln_review_count ev_mean_rating ev_sd_rating sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,ars_cross_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D3_cross
reghdfe lnRevenue_next_calendar_w199 c.ars_pool_ev##c.pmr_cohort_rate7 c.ars_pool_ev##c.pmr_text_invite_zf c.ars_pool_ev##c.pmr_text_recovery_zf c.ars_pool_ev##c.pmr_target_complaint_zf c.ars_pool_ev##c.pmr_target_service_zf c.ars_pool_ev##c.pmr_target_room_zf c.ars_pool_ev##c.pmr_target_cleanliness_zf c.ars_pool_ev##c.pmr_target_value_zf pmr_any pmr_activity_n ev_ln_review_count ev_mean_rating ev_sd_rating sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D3_pool

estimates table M01_cross M01_pool D1_cross D1_pool D2_cross D2_pool D3_cross D3_pool, b(%9.4f) se stats(N r2_a)
log close
