*******************************************************
* run_routeB_engagement_style_260605.do
* Route B / C extension: finer engagement-style themes
* covering coverage, effort, speed, tone, and
* personalization/standardization.
*
* This version follows the Route A scripts:
* - no centered moderator variables
* - each revenue interaction is paired with grouped
*   low/high regressions
* - grouped splits use Zip-by-month medians for
*   continuous moderators
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
local log_dir "`project'/stata-log"
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
capture which winsor2
if _rc exit 199

use "`data_main'", clear
log using "`log_dir'/run_routeB_engagement_style_`run_id'.log", text replace

keep if cs_sample_focus100 == 1

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID

capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

capture drop ln_lag_mr_words
capture drop ln_lag_mr_avg_words
gen double ln_lag_mr_words = ln(lag_mr_text_words + 1) if !missing(lag_mr_text_words)
gen double ln_lag_mr_avg_words = ln(lag_mr_avg_text_words + 1) if !missing(lag_mr_avg_text_words)


winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)


winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199_cym) by(City ym)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595_cym) by(City ym)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199_cym) by(City ym)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595_cym) by(City ym)

estimates clear

* G1. Coverage: any reply.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.lag_mr_any ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_any

reghdfe sim_mean i.lag_mr_any lag_sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc  ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)

* G1a-G1b. Grouped any-reply regressions.
* Estimate the ARS slope separately when the hotel had no lagged reply activity and when it had any lagged reply activity.
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & lag_mr_any == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_any_0

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & lag_mr_any == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_any_1

* G2. Coverage: reply rate.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_rate ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_rate), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_rate

* G2a-G2b. Grouped reply-rate regressions.
* Split hotels into lower- and higher-reply-rate cells within each Zip-month.
capture drop med_lag_mr_rate
capture drop g_hi_rate
bysort Zip ym: egen med_lag_mr_rate = median(lag_mr_rate)
generate g_hi_rate = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_rate) & lag_mr_rate > med_lag_mr_rate
replace g_hi_rate = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_rate) & lag_mr_rate < med_lag_mr_rate

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_rate == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_rate_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_rate == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_rate_high

* G3. Effort: reply count.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_count ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_count), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_count

* G3a-G3b. Grouped reply-count regressions.
* Split hotels into lower- and higher-reply-count cells within each Zip-month.
capture drop med_lag_mr_count
capture drop g_hi_count
bysort Zip ym: egen med_lag_mr_count = median(lag_mr_count)
generate g_hi_count = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_count) & lag_mr_count > med_lag_mr_count
replace g_hi_count = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_count) & lag_mr_count < med_lag_mr_count

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_count == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_count_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_count == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_count_high

* G4. Effort: total reply words.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_lag_mr_words ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(ln_lag_mr_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_words

* G4a-G4b. Grouped total-reply-word regressions.
* Split hotels into lower- and higher-total-reply-word cells within each Zip-month.
capture drop med_ln_lag_mr_words
capture drop g_hi_words
bysort Zip ym: egen med_ln_lag_mr_words = median(ln_lag_mr_words)
generate g_hi_words = 1 if cs_sample_focus100 == 1 & !missing(ln_lag_mr_words) & ln_lag_mr_words > med_ln_lag_mr_words
replace g_hi_words = 0 if cs_sample_focus100 == 1 & !missing(ln_lag_mr_words) & ln_lag_mr_words < med_ln_lag_mr_words

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_words == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_words_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_words == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_words_high

* G5. Effort: average reply words.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_lag_mr_avg_words ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(ln_lag_mr_avg_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_avgwords

* G5a-G5b. Grouped average-reply-word regressions.
* Split hotels into lower- and higher-average-reply-word cells within each Zip-month.
capture drop med_ln_lag_mr_avg_words
capture drop g_hi_avgw
bysort Zip ym: egen med_ln_lag_mr_avg_words = median(ln_lag_mr_avg_words)
generate g_hi_avgw = 1 if cs_sample_focus100 == 1 & !missing(ln_lag_mr_avg_words) & ln_lag_mr_avg_words > med_ln_lag_mr_avg_words
replace g_hi_avgw = 0 if cs_sample_focus100 == 1 & !missing(ln_lag_mr_avg_words) & ln_lag_mr_avg_words < med_ln_lag_mr_avg_words

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_avgw == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_avgwords_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_avgw == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_avgwords_high

* G6. Speed: quick7 share.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_quick7_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_quick7_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick7

* G6a-G6b. Grouped quick7 regressions.
* Split hotels into lower- and higher-quick7 cells within each Zip-month.
capture drop med_lag_mr_quick7_share
capture drop g_hi_quick7
bysort Zip ym: egen med_lag_mr_quick7_share = median(lag_mr_quick7_share)
generate g_hi_quick7 = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_quick7_share) & lag_mr_quick7_share > med_lag_mr_quick7_share
replace g_hi_quick7 = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_quick7_share) & lag_mr_quick7_share < med_lag_mr_quick7_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_quick7 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick7_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_quick7 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick7_high

* G7. Speed: quick30 share.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_quick30_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_quick30_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick30

* G7a-G7b. Grouped quick30 regressions.
* Split hotels into lower- and higher-quick30 cells within each Zip-month.
capture drop med_lag_mr_quick30_share
capture drop g_hi_quick30
bysort Zip ym: egen med_lag_mr_quick30_share = median(lag_mr_quick30_share)
generate g_hi_quick30 = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_quick30_share) & lag_mr_quick30_share > med_lag_mr_quick30_share
replace g_hi_quick30 = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_quick30_share) & lag_mr_quick30_share < med_lag_mr_quick30_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_quick30 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick30_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_quick30 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_quick30_high

* G8. Speed: average response days.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_avg_resp_days ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_avg_resp_days), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_respdays

* G8a-G8b. Grouped response-days regressions.
* Split hotels into lower- and higher-response-days cells within each Zip-month.
capture drop med_lag_mr_avg_resp_days
capture drop g_hi_respdays
bysort Zip ym: egen med_lag_mr_avg_resp_days = median(lag_mr_avg_resp_days)
generate g_hi_respdays = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_avg_resp_days) & lag_mr_avg_resp_days > med_lag_mr_avg_resp_days
replace g_hi_respdays = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_avg_resp_days) & lag_mr_avg_resp_days < med_lag_mr_avg_resp_days

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_respdays == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_respdays_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_respdays == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_respdays_high

* G9. Tone: thanks wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_thanks_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_thanks_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_thanks

* G9a-G9b. Grouped thanks-wording regressions.
* Split hotels into lower- and higher-thanks-wording cells within each Zip-month.
capture drop med_lag_mr_thanks_share
capture drop g_hi_thanks
bysort Zip ym: egen med_lag_mr_thanks_share = median(lag_mr_thanks_share)
generate g_hi_thanks = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_thanks_share) & lag_mr_thanks_share > med_lag_mr_thanks_share
replace g_hi_thanks = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_thanks_share) & lag_mr_thanks_share < med_lag_mr_thanks_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_thanks == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_thanks_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_thanks == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_thanks_high

* G10. Tone: apology wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_apology_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_apology_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_apology

* G10a-G10b. Grouped apology-wording regressions.
* Split hotels into lower- and higher-apology-wording cells within each Zip-month.
capture drop med_lag_mr_apology_share
capture drop g_hi_apology
bysort Zip ym: egen med_lag_mr_apology_share = median(lag_mr_apology_share)
generate g_hi_apology = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_apology_share) & lag_mr_apology_share > med_lag_mr_apology_share
replace g_hi_apology = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_apology_share) & lag_mr_apology_share < med_lag_mr_apology_share

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_apology == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_apology_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_apology == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_apology_high

* G11. Tone: invite wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_invite_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_invite_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_invite

* G11a-G11b. Grouped invite-wording regressions.
* Split hotels into lower- and higher-invite-wording cells within each Zip-month.
capture drop med_lag_mr_invite_share
capture drop g_hi_invite
bysort Zip ym: egen med_lag_mr_invite_share = median(lag_mr_invite_share)
generate g_hi_invite = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_invite_share) & lag_mr_invite_share > med_lag_mr_invite_share
replace g_hi_invite = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_invite_share) & lag_mr_invite_share < med_lag_mr_invite_share

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_invite == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_invite_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_invite == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_invite_high

* G12. Tone: recovery wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_recovery_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_recovery_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_recovery

* G12a-G12b. Grouped recovery-wording regressions.
* Split hotels into lower- and higher-recovery-wording cells within each Zip-month.
capture drop med_lag_mr_recovery_share
capture drop g_hi_recovery
bysort Zip ym: egen med_lag_mr_recovery_share = median(lag_mr_recovery_share)
generate g_hi_recovery = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_recovery_share) & lag_mr_recovery_share > med_lag_mr_recovery_share
replace g_hi_recovery = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_recovery_share) & lag_mr_recovery_share < med_lag_mr_recovery_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_recovery == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_recovery_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_recovery == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_recovery_high

* G13. Tone: positive wording.
reghdfe ln_RevPAR_clean c.sim_mean##c.lag_mr_positive_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_positive_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_positive

* G13a-G13b. Grouped positive-wording regressions.
* Split hotels into lower- and higher-positive-wording cells within each Zip-month.
capture drop med_lag_mr_positive_share
capture drop g_hi_positive
bysort Zip ym: egen med_lag_mr_positive_share = median(lag_mr_positive_share)
generate g_hi_positive = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_positive_share) & lag_mr_positive_share > med_lag_mr_positive_share
replace g_hi_positive = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_positive_share) & lag_mr_positive_share < med_lag_mr_positive_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_positive == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_positive_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_positive == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_positive_high

* G14. Tone: problem/negative wording.
reghdfe ln_RevPAR_clean c.sim_mean##c.lag_mr_negtone_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_negtone_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_negtone

* G14a-G14b. Grouped negative-tone regressions.
* Split hotels into lower- and higher-negative-tone cells within each Zip-month.
capture drop med_lag_mr_negtone_share
capture drop g_hi_negtone
bysort Zip ym: egen med_lag_mr_negtone_share = median(lag_mr_negtone_share)
generate g_hi_negtone = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_negtone_share) & lag_mr_negtone_share > med_lag_mr_negtone_share
replace g_hi_negtone = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_negtone_share) & lag_mr_negtone_share < med_lag_mr_negtone_share

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_negtone == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_negtone_low

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_negtone == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_negtone_high

* G15. Personalization.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_personal_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_personal_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_personal

* G15a-G15b. Grouped personalization regressions.
* Split hotels into lower- and higher-personalization cells within each Zip-month.
capture drop med_lag_mr_personal_share
capture drop g_hi_personal
bysort Zip ym: egen med_lag_mr_personal_share = median(lag_mr_personal_share)
generate g_hi_personal = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_personal_share) & lag_mr_personal_share > med_lag_mr_personal_share
replace g_hi_personal = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_personal_share) & lag_mr_personal_share < med_lag_mr_personal_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_personal == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_personal_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_personal == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_personal_high

* G16. Manager-signed wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_mgr_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & !missing(lag_mr_mgr_share), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_mgr

* G16a-G16b. Grouped manager-signoff regressions.
* Split hotels into lower- and higher-manager-signoff cells within each Zip-month.
capture drop med_lag_mr_mgr_share
capture drop g_hi_mgr
bysort Zip ym: egen med_lag_mr_mgr_share = median(lag_mr_mgr_share)
generate g_hi_mgr = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_mgr_share) & lag_mr_mgr_share > med_lag_mr_mgr_share
replace g_hi_mgr = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_mgr_share) & lag_mr_mgr_share < med_lag_mr_mgr_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_mgr == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_mgr_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any ///
    if cs_sample_focus100 == 1 & g_hi_mgr == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gr_mgr_high

esttab gr_any gr_rate gr_count gr_words gr_avgwords gr_quick7 gr_quick30 gr_respdays gr_thanks gr_apology gr_invite gr_recovery gr_positive gr_negtone gr_personal gr_mgr ///
    using "`table_dir'/routeB_engagement_style_revenue_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("any" "rate" "count" "words" "avg words" "quick7" "quick30" "days" "thanks" "apology" "invite" "recovery" "positive" "neg tone" "personal" "manager") ///
    nogap compress

esttab gr_any gr_rate gr_count gr_words gr_avgwords gr_quick7 gr_quick30 gr_respdays gr_thanks gr_apology gr_invite gr_recovery gr_positive gr_negtone gr_personal gr_mgr ///
    using "`csv_dir'/routeB_engagement_style_revenue_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("any" "rate" "count" "words" "avg words" "quick7" "quick30" "days" "thanks" "apology" "invite" "recovery" "positive" "neg tone" "personal" "manager") ///
    nogap

esttab gr_any_0 gr_any_1 gr_rate_low gr_rate_high gr_count_low gr_count_high gr_words_low gr_words_high gr_avgwords_low gr_avgwords_high gr_quick7_low gr_quick7_high gr_quick30_low gr_quick30_high gr_respdays_low gr_respdays_high gr_thanks_low gr_thanks_high gr_apology_low gr_apology_high gr_invite_low gr_invite_high gr_recovery_low gr_recovery_high gr_positive_low gr_positive_high gr_negtone_low gr_negtone_high gr_personal_low gr_personal_high gr_mgr_low gr_mgr_high ///
    using "`table_dir'/routeB_engagement_style_revenue_grouped_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("any=0" "any=1" "rate low" "rate high" "count low" "count high" "words low" "words high" "avg words low" "avg words high" "quick7 low" "quick7 high" "quick30 low" "quick30 high" "days low" "days high" "thanks low" "thanks high" "apology low" "apology high" "invite low" "invite high" "recovery low" "recovery high" "positive low" "positive high" "neg tone low" "neg tone high" "personal low" "personal high" "manager low" "manager high") ///
    nogap compress

esttab gr_any_0 gr_any_1 gr_rate_low gr_rate_high gr_count_low gr_count_high gr_words_low gr_words_high gr_avgwords_low gr_avgwords_high gr_quick7_low gr_quick7_high gr_quick30_low gr_quick30_high gr_respdays_low gr_respdays_high gr_thanks_low gr_thanks_high gr_apology_low gr_apology_high gr_invite_low gr_invite_high gr_recovery_low gr_recovery_high gr_positive_low gr_positive_high gr_negtone_low gr_negtone_high gr_personal_low gr_personal_high gr_mgr_low gr_mgr_high ///
    using "`csv_dir'/routeB_engagement_style_revenue_grouped_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("any=0" "any=1" "rate low" "rate high" "count low" "count high" "words low" "words high" "avg words low" "avg words high" "quick7 low" "quick7 high" "quick30 low" "quick30 high" "days low" "days high" "thanks low" "thanks high" "apology low" "apology high" "invite low" "invite high" "recovery low" "recovery high" "positive low" "positive high" "neg tone low" "neg tone high" "personal low" "personal high" "manager low" "manager high") ///
    nogap

estimates clear

* M1. Engagement style -> next-month review volume.
reghdfe ln_recent_volumn ///
    lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_quick30_share ///
    lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share ///
    lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_template_share lag_mr_mgr_share ///
    recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gm_volume

* M2. Engagement style -> next-month ARS.
reghdfe sim_mean ///
    lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_quick30_share ///
    lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share ///
    lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_template_share lag_mr_mgr_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gm_ars

* M3. Engagement style -> next-month sentiment.
reghdfe sent_net_pos_bing ///
    lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_quick30_share ///
    lag_mr_avg_resp_days lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share ///
    lag_mr_positive_share lag_mr_negtone_share lag_mr_personal_share lag_mr_template_share lag_mr_mgr_share ///
    ln_recent_volumn sim_mean recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(sent_net_pos_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store gm_sent

esttab gm_volume gm_ars gm_sent ///
    using "`table_dir'/routeB_engagement_style_mechanisms_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("DV volume" "DV ARS" "DV sentiment") ///
    nogap compress

esttab gm_volume gm_ars gm_sent ///
    using "`csv_dir'/routeB_engagement_style_mechanisms_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("DV volume" "DV ARS" "DV sentiment") ///
    nogap

log close
