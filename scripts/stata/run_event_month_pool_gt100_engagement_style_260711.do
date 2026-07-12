*******************************************************
* Route B engagement style, rebuilt pooled-ARS panel.
* Self-contained; all controls are written in every regression.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
log using "`p'/stata-log/run_event_month_pool_gt100_engagement_style_260711.log", text replace
estimates clear

* G1-G8 coverage, rate, effort, and response speed.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_any), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G1_any
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_quick7_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_quick7_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G2_rate7
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_count ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_count), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G3_count
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_lag_mr_words lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, ln_lag_mr_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G4_words
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_lag_mr_avg_words lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, ln_lag_mr_avg_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G5_avgwords
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_quick7_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_quick7_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G6_quick7
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_quick30_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_quick30_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G7_quick30
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_avg_resp_days lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_avg_resp_days), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G8_speed

* G9-G16 response wording and manager identity.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_thanks_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_thanks_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G9_thanks
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_apology_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_apology_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G10_apology
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_invite_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_invite_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G11_invite
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_recovery_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_recovery_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G12_recovery
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_positive_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_positive_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G13_positive
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_negtone_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_negtone_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G14_problem
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_personal_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_personal_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G15_personal
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_mgr_share lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean, lag_mr_mgr_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G16_manager

* Route B production outcomes, retaining the original variable interface.
reghdfe ln_recent_volumn lag_mr_any lag_mr_rate lag_mr_count ln_lag_mr_words lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_mgr_share recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(ln_recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G_volume
reghdfe sim_mean lag_mr_any lag_mr_rate lag_mr_count ln_lag_mr_words lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_mgr_share ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G_poolmechanism
reghdfe sent_net_pos_bing lag_mr_any lag_mr_rate lag_mr_count ln_lag_mr_words lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_mgr_share ln_recent_volumn sim_mean recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if !missing(sent_net_pos_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G_sentiment

* Grouped G11 slopes.
capture drop g11_invite_group
gen byte g11_invite_group = lag_mr_invite_share > 0 if !missing(lag_mr_invite_share)
reghdfe ln_RevPAR_clean_w199 sim_mean lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if g11_invite_group == 0 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G11_noinvite
reghdfe ln_RevPAR_clean_w199 sim_mean lag_mr_any ln_recent_volumn recent_rating recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if g11_invite_group == 1 & !missing(sim_mean), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store G11_invitegroup

estimates table G1_any G2_rate7 G3_count G4_words G5_avgwords G6_quick7 G7_quick30 G8_speed G9_thanks G10_apology G11_invite G12_recovery G13_positive G14_problem G15_personal G16_manager G_volume G_poolmechanism G_sentiment G11_noinvite G11_invitegroup, b(%9.4f) se stats(N r2_a)
log close
