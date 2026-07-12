version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
log using "`p'/stata-log/run_event_month_pool_gt100_grouped_slopes_260711.log", text replace
local C ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199
* M1: binary high-competition ZIP groups.
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if high_comp_zip_focus100==0 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_M1_zip_low
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if high_comp_zip_focus100==1 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_M1_zip_high
* M5: ZIP competitor-RevPAR high/low, defined within ZIP-by-calendar-month cells.
bysort Zip ym: egen double gs_m5_med = median(ln_comp_zip_mean_excl_full)
gen byte gs_m5_high = ln_comp_zip_mean_excl_full > gs_m5_med if !missing(ln_comp_zip_mean_excl_full,gs_m5_med)
replace gs_m5_high = 0 if !missing(ln_comp_zip_mean_excl_full,gs_m5_med) & gs_m5_high==0
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if gs_m5_high==0 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_M5_ziprev_low
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if gs_m5_high==1 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_M5_ziprev_high
* M6: city competitor-RevPAR high/low, defined within City-by-calendar-month cells.
bysort CityID ym: egen double gs_m6_med = median(ln_comp_city_mean_excl_full)
gen byte gs_m6_high = ln_comp_city_mean_excl_full > gs_m6_med if !missing(ln_comp_city_mean_excl_full,gs_m6_med)
replace gs_m6_high = 0 if !missing(ln_comp_city_mean_excl_full,gs_m6_med) & gs_m6_high==0
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if gs_m6_high==0 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_M6_cityrev_low
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if gs_m6_high==1 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_M6_cityrev_high
* O13: within-ZIP-by-month cumulative-review-volume groups.
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if high_popularity==0 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_O13_pop_low
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if high_popularity==1 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_O13_pop_high
* E2: previous-visible-event dispersion, ZIP-by-month high/low groups.
bysort Zip ym: egen double gs_e2_med = median(prevvis_recent_sd)
gen byte gs_e2_high = prevvis_recent_sd > gs_e2_med if !missing(prevvis_recent_sd,gs_e2_med)
replace gs_e2_high = 0 if !missing(prevvis_recent_sd,gs_e2_med) & gs_e2_high==0
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if gs_e2_high==0 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_E2_disp_low
reghdfe lnRevenue_current_w199 ars_pool_ev `C' if gs_e2_high==1 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_E2_disp_high
* G11: no-invite versus invite wording; retain reply-activity control in both groups.
gen byte gs_g11_invite = pmr_activity_invite_zf > 0 if !missing(pmr_activity_invite_zf)
reghdfe lnRevenue_current_w199 ars_pool_ev pmr_activity_any `C' if gs_g11_invite==0 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_G11_noinvite
reghdfe lnRevenue_current_w199 ars_pool_ev pmr_activity_any `C' if gs_g11_invite==1 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_G11_invite
* T1: complaint-targeting high/low among hotels that responded in the prior event.
bysort Zip ym: egen double gs_t1_med = median(pmr_activity_complaint_zf) if pmr_activity_any==1
gen byte gs_t1_high = pmr_activity_complaint_zf > gs_t1_med if pmr_activity_any==1 & !missing(gs_t1_med)
replace gs_t1_high = 0 if pmr_activity_any==1 & !missing(gs_t1_med) & gs_t1_high==0
reghdfe lnRevenue_current_w199 ars_pool_ev pmr_activity_any `C' if gs_t1_high==0 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_T1_complaint_low
reghdfe lnRevenue_current_w199 ars_pool_ev pmr_activity_any `C' if gs_t1_high==1 & !missing(ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store GS_T1_complaint_high
estimates table GS_M1_zip_low GS_M1_zip_high GS_M5_ziprev_low GS_M5_ziprev_high GS_M6_cityrev_low GS_M6_cityrev_high GS_O13_pop_low GS_O13_pop_high GS_E2_disp_low GS_E2_disp_high GS_G11_noinvite GS_G11_invite GS_T1_complaint_low GS_T1_complaint_high, b(%9.4f) se stats(N r2_a)
log close
