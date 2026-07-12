version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
log using "`p'/stata-log/run_event_month_pool_gt100_learning_mr_260711.log", text replace
local C ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199
estimates clear
* L1-L2 corrected learning specifications: next-event levels, no mechanically coupled delta outcome.
reghdfe next_event_ars_pool_ev ars_pool_ev ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_ars_pool_ev,ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L1_nextpool
reghdfe next_event_mean_text_chars ars_pool_ev ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_mean_text_chars,ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L2_nextlength
* T1-T3: pooled ARS moderation by prior-event targeting shares.
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_complaint_zf pmr_activity_any pmr_activity_n pmr_cohort_rate7 `C' if !missing(ars_pool_ev,pmr_activity_complaint_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T1_complaint
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_service_zf pmr_activity_any pmr_activity_n pmr_cohort_rate7 `C' if !missing(ars_pool_ev,pmr_activity_service_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T2_service
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_room_zf pmr_activity_any pmr_activity_n pmr_cohort_rate7 `C' if !missing(ars_pool_ev,pmr_activity_room_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T3_room
* T4-T6: targeting and future review production; sequential associations only.
reghdfe next_event_review_count pmr_activity_complaint_zf pmr_activity_service_zf pmr_activity_room_zf pmr_activity_cleanliness_zf pmr_activity_value_zf pmr_activity_any pmr_activity_n ln_pmr_words ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_review_count), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T4_volume
reghdfe next_event_ars_pool_ev pmr_activity_complaint_zf pmr_activity_service_zf pmr_activity_room_zf pmr_activity_cleanliness_zf pmr_activity_value_zf pmr_activity_any pmr_activity_n ln_pmr_words ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T5_pool
reghdfe next_event_sent_bing pmr_activity_complaint_zf pmr_activity_service_zf pmr_activity_room_zf pmr_activity_cleanliness_zf pmr_activity_value_zf pmr_activity_any pmr_activity_n ln_pmr_words ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_sent_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store T6_sentiment
* Pool-only dynamic path: prior-event MR -> current pooled ARS -> next-calendar revenue.
reghdfe ars_pool_ev pmr_activity_any pmr_cohort_rate7 pmr_activity_n pmr_activity_invite_zf pmr_activity_recovery_zf pmr_activity_complaint_zf pmr_activity_service_zf pmr_activity_room_zf pmr_activity_cleanliness_zf pmr_activity_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D1_mrpool
capture drop lnRevenue_next_calendar_w199
winsor2 lnRevenue_next_calendar, cuts(1 99) suffix(_w199)
reghdfe lnRevenue_next_calendar_w199 ars_pool_ev pmr_activity_any pmr_cohort_rate7 pmr_activity_n pmr_activity_invite_zf pmr_activity_recovery_zf pmr_activity_complaint_zf pmr_activity_service_zf pmr_activity_room_zf pmr_activity_cleanliness_zf pmr_activity_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D2_nextrevenue
reghdfe lnRevenue_next_calendar_w199 c.ars_pool_ev##c.pmr_activity_invite_zf c.ars_pool_ev##c.pmr_activity_recovery_zf c.ars_pool_ev##c.pmr_activity_complaint_zf c.ars_pool_ev##c.pmr_activity_service_zf c.ars_pool_ev##c.pmr_activity_room_zf c.ars_pool_ev##c.pmr_activity_cleanliness_zf c.ars_pool_ev##c.pmr_activity_value_zf pmr_activity_any pmr_activity_n ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store D3_interaction
estimates table L1_nextpool L2_nextlength T1_complaint T2_service T3_room T4_volume T5_pool T6_sentiment D1_mrpool D2_nextrevenue D3_interaction, b(%9.4f) se stats(N r2_a)
log close
