*******************************************************
* run_routeB_engagement_style_260605.do
* Route B / C extension: finer engagement-style themes
* covering coverage, effort, speed, tone, and
* personalization/standardization.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
mata: mata set matafavor speed
capture log close

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/core_simi_260501"
local data_dir "`out_root'/data"
local table_dir "`out_root'/tables_explicit"
local csv_dir "`out_root'/csv"
local log_dir "`out_root'/logs"
local run_id "260605"
local data_main "`data_dir'/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"

cap mkdir "`table_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`log_dir'"

capture confirm file "`data_main'"
if _rc exit 601
capture which reghdfe
if _rc exit 199
capture which esttab
if _rc exit 199

use "`data_main'", clear
log using "`log_dir'/run_routeB_engagement_style_`run_id'.log", text replace

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

capture drop ln_RevPAR_clean_w199 ln_lag_RevPAR_clean_w199
gen double ln_RevPAR_clean_w199 = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w199 = ln_lag_RevPAR_clean
quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local y_p1 = r(r1)
local y_p99 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local ly_p1 = r(r1)
local ly_p99 = r(r2)
replace ln_RevPAR_clean_w199 = `y_p1' if ln_RevPAR_clean_w199 < `y_p1' & !missing(ln_RevPAR_clean_w199)
replace ln_RevPAR_clean_w199 = `y_p99' if ln_RevPAR_clean_w199 > `y_p99' & !missing(ln_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p1' if ln_lag_RevPAR_clean_w199 < `ly_p1' & !missing(ln_lag_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p99' if ln_lag_RevPAR_clean_w199 > `ly_p99' & !missing(ln_lag_RevPAR_clean_w199)

capture confirm variable ln_lag_mr_words
if _rc gen double ln_lag_mr_words = ln(lag_mr_text_words + 1)
capture confirm variable ln_lag_mr_avg_words
if _rc gen double ln_lag_mr_avg_words = ln(lag_mr_avg_text_words + 1)

capture drop sim_mean_c lagrate_c lagcount_c lnmrwords_c lnmravgw_c quick7_c quick30_c respdays_c thanks_c apology_c invite_c recover_c positive_c negtone_c personal_c template_c mgr_c
quietly summarize sim_mean if cs_sample_focus100 == 1 & !missing(sim_mean)
gen double sim_mean_c = sim_mean - r(mean) if !missing(sim_mean)
quietly summarize lag_mr_rate if cs_sample_focus100 == 1 & !missing(lag_mr_rate)
gen double lagrate_c = lag_mr_rate - r(mean) if !missing(lag_mr_rate)
quietly summarize lag_mr_count if cs_sample_focus100 == 1 & !missing(lag_mr_count)
gen double lagcount_c = lag_mr_count - r(mean) if !missing(lag_mr_count)
quietly summarize ln_lag_mr_words if cs_sample_focus100 == 1 & !missing(ln_lag_mr_words)
gen double lnmrwords_c = ln_lag_mr_words - r(mean) if !missing(ln_lag_mr_words)
quietly summarize ln_lag_mr_avg_words if cs_sample_focus100 == 1 & !missing(ln_lag_mr_avg_words)
gen double lnmravgw_c = ln_lag_mr_avg_words - r(mean) if !missing(ln_lag_mr_avg_words)
quietly summarize lag_mr_quick7_share if cs_sample_focus100 == 1 & !missing(lag_mr_quick7_share)
gen double quick7_c = lag_mr_quick7_share - r(mean) if !missing(lag_mr_quick7_share)
quietly summarize lag_mr_quick30_share if cs_sample_focus100 == 1 & !missing(lag_mr_quick30_share)
gen double quick30_c = lag_mr_quick30_share - r(mean) if !missing(lag_mr_quick30_share)
quietly summarize lag_mr_avg_resp_days if cs_sample_focus100 == 1 & !missing(lag_mr_avg_resp_days)
gen double respdays_c = lag_mr_avg_resp_days - r(mean) if !missing(lag_mr_avg_resp_days)
quietly summarize lag_mr_thanks_share if cs_sample_focus100 == 1 & !missing(lag_mr_thanks_share)
gen double thanks_c = lag_mr_thanks_share - r(mean) if !missing(lag_mr_thanks_share)
quietly summarize lag_mr_apology_share if cs_sample_focus100 == 1 & !missing(lag_mr_apology_share)
gen double apology_c = lag_mr_apology_share - r(mean) if !missing(lag_mr_apology_share)
quietly summarize lag_mr_invite_share if cs_sample_focus100 == 1 & !missing(lag_mr_invite_share)
gen double invite_c = lag_mr_invite_share - r(mean) if !missing(lag_mr_invite_share)
quietly summarize lag_mr_recovery_share if cs_sample_focus100 == 1 & !missing(lag_mr_recovery_share)
gen double recover_c = lag_mr_recovery_share - r(mean) if !missing(lag_mr_recovery_share)
quietly summarize lag_mr_positive_share if cs_sample_focus100 == 1 & !missing(lag_mr_positive_share)
gen double positive_c = lag_mr_positive_share - r(mean) if !missing(lag_mr_positive_share)
quietly summarize lag_mr_negtone_share if cs_sample_focus100 == 1 & !missing(lag_mr_negtone_share)
gen double negtone_c = lag_mr_negtone_share - r(mean) if !missing(lag_mr_negtone_share)
quietly summarize lag_mr_personal_share if cs_sample_focus100 == 1 & !missing(lag_mr_personal_share)
gen double personal_c = lag_mr_personal_share - r(mean) if !missing(lag_mr_personal_share)
quietly summarize lag_mr_template_share if cs_sample_focus100 == 1 & !missing(lag_mr_template_share)
gen double template_c = lag_mr_template_share - r(mean) if !missing(lag_mr_template_share)
quietly summarize lag_mr_mgr_share if cs_sample_focus100 == 1 & !missing(lag_mr_mgr_share)
gen double mgr_c = lag_mr_mgr_share - r(mean) if !missing(lag_mr_mgr_share)

estimates clear

* G1. Coverage: any reply.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.lag_mr_any ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_any

* G2. Coverage: reply rate.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.lagrate_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_rate

* G3. Effort: reply count.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.lagcount_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_count

* G4. Effort: total reply words.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.lnmrwords_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_words

* G5. Effort: average reply words.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.lnmravgw_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_avgwords

* G6. Speed: quick7 share.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.quick7_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick7

* G7. Speed: quick30 share.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.quick30_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick30

* G8. Speed: average response days.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.respdays_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_respdays

* G9. Tone: thanks wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.thanks_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_thanks

* G10. Tone: apology wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.apology_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_apology

* G11. Tone: invite wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.invite_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_invite

* G12. Tone: recovery wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.recover_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_recovery

* G13. Tone: positive wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.positive_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_positive

* G14. Tone: problem/negative wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.negtone_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_negtone

* G15. Personalization.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.personal_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_personal

* G16. Standardized template wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.template_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_template

* G17. Manager-signed wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.mgr_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_mgr

esttab gr_any gr_rate gr_count gr_words gr_avgwords gr_quick7 gr_quick30 gr_respdays gr_thanks gr_apology gr_invite gr_recovery gr_positive gr_negtone gr_personal gr_template gr_mgr using "`table_dir'/routeB_engagement_style_revenue_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("any" "rate" "count" "words" "avg words" "quick7" "quick30" "days" "thanks" "apology" "invite" "recovery" "positive" "neg tone" "personal" "template" "manager") nogap compress
esttab gr_any gr_rate gr_count gr_words gr_avgwords gr_quick7 gr_quick30 gr_respdays gr_thanks gr_apology gr_invite gr_recovery gr_positive gr_negtone gr_personal gr_template gr_mgr using "`csv_dir'/routeB_engagement_style_revenue_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("any" "rate" "count" "words" "avg words" "quick7" "quick30" "days" "thanks" "apology" "invite" "recovery" "positive" "neg tone" "personal" "template" "manager") nogap

estimates clear

* M1. Engagement style -> next-month review volume.
reghdfe ln_recent_volumn lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_quick30_share lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_template_share lag_mr_mgr_share recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gm_volume

* M2. Engagement style -> next-month ARS.
reghdfe sim_mean lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_quick30_share lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_template_share lag_mr_mgr_share ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gm_ars

* M3. Engagement style -> next-month sentiment.
reghdfe sent_net_pos_bing lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_quick30_share lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_template_share lag_mr_mgr_share ln_recent_volumn sim_mean recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(sent_net_pos_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gm_sent

esttab gm_volume gm_ars gm_sent using "`table_dir'/routeB_engagement_style_mechanisms_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("DV volume" "DV ARS" "DV sentiment") nogap compress
esttab gm_volume gm_ars gm_sent using "`csv_dir'/routeB_engagement_style_mechanisms_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("DV volume" "DV ARS" "DV sentiment") nogap

log close
