version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
log using "`p'/stata-log/run_event_month_pool_gt100_engagement_260711.log", text replace
local C ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199
estimates clear
* G1-G16: prior-event management-response engagement styles, pool ARS only.
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_any), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G1_any
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_cohort_rate7 pmr_activity_any `C' if !missing(ars_pool_ev,pmr_cohort_rate7), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G2_rate7
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_n `C' if !missing(ars_pool_ev,pmr_activity_n), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G3_count
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.ln_pmr_words pmr_activity_any `C' if !missing(ars_pool_ev,ln_pmr_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G4_words
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.ln_pmr_avg_words pmr_activity_any `C' if !missing(ars_pool_ev,ln_pmr_avg_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G5_avgwords
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_cohort_rate7 pmr_activity_any `C' if !missing(ars_pool_ev,pmr_cohort_rate7), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G6_quick7
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_cohort_rate30 pmr_activity_any `C' if !missing(ars_pool_ev,pmr_cohort_rate30), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G7_quick30
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_avg_days pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_avg_days), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G8_speed
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_thanks_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_thanks_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G9_thanks
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_apology_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_apology_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G10_apology
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_invite_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_invite_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G11_invite
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_recovery_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_recovery_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G12_recovery
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_positive_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_positive_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G13_positive
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_problem_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_problem_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G14_problem
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_personal_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_personal_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G15_personal
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.pmr_activity_mgr_zf pmr_activity_any `C' if !missing(ars_pool_ev,pmr_activity_mgr_zf), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G16_manager
* Engagement mechanisms: next event review volume, pooled ARS, and sentiment.
reghdfe next_event_review_count pmr_activity_any pmr_cohort_rate7 pmr_activity_n ln_pmr_words pmr_activity_avg_days pmr_activity_thanks_zf pmr_activity_apology_zf pmr_activity_invite_zf pmr_activity_recovery_zf pmr_activity_positive_zf pmr_activity_problem_zf pmr_activity_personal_zf pmr_activity_mgr_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_review_count), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G_volume
reghdfe next_event_ars_pool_ev pmr_activity_any pmr_cohort_rate7 pmr_activity_n ln_pmr_words pmr_activity_avg_days pmr_activity_thanks_zf pmr_activity_apology_zf pmr_activity_invite_zf pmr_activity_recovery_zf pmr_activity_positive_zf pmr_activity_problem_zf pmr_activity_personal_zf pmr_activity_mgr_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_ars_pool_ev), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G_poolmechanism
reghdfe next_event_sent_bing pmr_activity_any pmr_cohort_rate7 pmr_activity_n ln_pmr_words pmr_activity_avg_days pmr_activity_thanks_zf pmr_activity_apology_zf pmr_activity_invite_zf pmr_activity_recovery_zf pmr_activity_positive_zf pmr_activity_problem_zf pmr_activity_personal_zf pmr_activity_mgr_zf ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR if !missing(next_event_sent_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G_sentiment
estimates table G1_any G2_rate7 G3_count G4_words G5_avgwords G6_quick7 G7_quick30 G8_speed G9_thanks G10_apology G11_invite G12_recovery G13_positive G14_problem G15_personal G16_manager G_volume G_poolmechanism G_sentiment, b(%9.4f) se stats(N r2_a)
log close
