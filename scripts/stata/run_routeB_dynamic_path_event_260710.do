*******************************************************
* Event-aligned dynamic path, 260710.  Logs only.
* Every ARS x MR specification contains exactly one interaction.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_ars_mr_panel_260710.dta", clear
log using "`p'/stata-log/run_routeB_dynamic_path_event_260710.log", text replace
capture which reghdfe
if _rc exit 199
keep if cs_sample_focus100 == 1
encode HotelID, gen(hotel_id_num)
gen ym = monthly(event_ym,"YM")
format ym %tm
capture drop lnRevenue_next_calendar_w199 lnRevenue_lag_month_w199
quietly _pctile lnRevenue_next_calendar if !missing(lnRevenue_next_calendar), p(1 99)
gen double lnRevenue_next_calendar_w199=min(max(lnRevenue_next_calendar,r(r1)),r(r2)) if !missing(lnRevenue_next_calendar)
quietly _pctile lnRevenue_lag_month if !missing(lnRevenue_lag_month), p(1 99)
gen double lnRevenue_lag_month_w199=min(max(lnRevenue_lag_month,r(r1)),r(r2)) if !missing(lnRevenue_lag_month)

foreach a in ars_cross_ev ars_pool_ev {
    * D1 main timing: previous-event MR; D1i interval robustness.
    reghdfe `a' pmr_any pmr_activity_n pmr_cohort_rate7 pmr_text_invite_zf pmr_text_recovery_zf pmr_target_complaint_zf pmr_target_service_zf pmr_target_room_zf pmr_target_cleanliness_zf pmr_target_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    reghdfe `a' imr_any imr_activity_n imr_text_invite_zf imr_text_recovery_zf imr_target_complaint_zf imr_target_service_zf imr_target_room_zf imr_target_cleanliness_zf imr_target_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    * D2: next calendar-month revenue; sequence is exploratory, not mediation.
    reghdfe lnRevenue_next_calendar_w199 `a' pmr_any pmr_activity_n pmr_cohort_rate7 pmr_text_invite_zf pmr_text_recovery_zf pmr_target_complaint_zf pmr_target_service_zf pmr_target_room_zf pmr_target_cleanliness_zf pmr_target_value_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    * D3: one predeclared interaction per regression, so no repeated ARS main effect occurs.
    foreach m in c.pmr_activity_n c.pmr_cohort_rate7 c.pmr_text_invite_zf c.pmr_text_recovery_zf c.pmr_target_complaint_zf c.pmr_target_service_zf c.pmr_target_room_zf c.pmr_target_cleanliness_zf c.pmr_target_value_zf {
        reghdfe lnRevenue_next_calendar_w199 c.`a'##`m' pmr_any ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(lnRevenue_next_calendar_w199,`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    }
}
log close
