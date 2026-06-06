*******************************************************
* run_routeA_review_environment_260605.do
* Route A extension: ARS as the main effect, with review
* environment boundaries rebuilt around the same visible
* review sets that underlie sim_mean.
*
* Current-window variables:
*   - use all reviews in the current month
*   - plus the 10 most recent reviews before the month
*
* Robustness variables:
*   - use the most recent prior month with any visible reviews
********************************************************

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
local log_dir "`out_root'/stata-log"
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
log using "`log_dir'/run_routeA_review_environment_`run_id'.log", text replace

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

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)

estimates clear

*******************************************************
************ 2. current-window boundaries *************
*******************************************************

* E1. Scope-10 review-dispersion boundary.
* The moderator is the rating dispersion computed from the same visible review set
* used for sim_mean: current-month reviews plus the 10 most recent earlier reviews.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.recent_sd_10 ///
    ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(recent_sd_10), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_scope10_sd

* E1a-E1b. Scope-10 review-dispersion grouped regressions.
* Split hotels into lower- and higher-dispersion cells within each Zip-month.
capture drop med_recent_sd_10
capture drop re_high_recent_sd_10
bysort Zip ym: egen med_recent_sd_10 = median(recent_sd_10)
generate re_high_recent_sd_10 = 1 if cs_sample_focus100 == 1 & !missing(recent_sd_10) & recent_sd_10 > med_recent_sd_10
replace re_high_recent_sd_10 = 0 if cs_sample_focus100 == 1 & !missing(recent_sd_10) & recent_sd_10 < med_recent_sd_10

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & re_high_recent_sd_10 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_scope10_sd_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & re_high_recent_sd_10 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_scope10_sd_high

* E2. Previous-visible-month dispersion boundary.
* As a robustness check, use the most recent earlier month with any visible reviews.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.prevvis_recent_sd ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(prevvis_recent_sd), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_sd

* E2a-E2b. Previous-visible-month dispersion grouped regressions.
* Split hotels into lower- and higher-dispersion cells within each Zip-month.
capture drop med_prevvis_recent_sd
capture drop re_high_prevvis_recent_sd
bysort Zip ym: egen med_prevvis_recent_sd = median(prevvis_recent_sd)
generate re_high_prevvis_recent_sd = 1 if cs_sample_focus100 == 1 & !missing(prevvis_recent_sd) & prevvis_recent_sd > med_prevvis_recent_sd
replace re_high_prevvis_recent_sd = 0 if cs_sample_focus100 == 1 & !missing(prevvis_recent_sd) & prevvis_recent_sd < med_prevvis_recent_sd

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & re_high_prevvis_recent_sd == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_sd_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & re_high_prevvis_recent_sd == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_sd_high

* E3. Scope-10 average Bing sentiment boundary.
* The moderator is average review-text sentiment from the same visible scope-10 review set.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.sent_avg_bing_10 ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & sent_any_text_10 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_scope10_bingavg

*******************************************************
************ 3. previous-visible robustness ***********
*******************************************************

* E4. Scope-10 net-positive Bing sentiment boundary.
* The moderator is the net positive-minus-negative Bing share in the visible scope-10 review set.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.sent_net_pos_bing_10 ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & sent_any_text_10 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_scope10_netpos

* E4a-E4b. Scope-10 net-positive grouped regressions.
* Split hotels into lower- and higher-net-positive cells within each Zip-month.
capture drop med_sent_net_pos_bing_10
capture drop re_high_sent_net_pos_bing_10
bysort Zip ym: egen med_sent_net_pos_bing_10 = median(sent_net_pos_bing_10) if sent_any_text_10 == 1
generate re_high_sent_net_pos_bing_10 = 1 if cs_sample_focus100 == 1 & sent_any_text_10 == 1 & sent_net_pos_bing_10 >= med_sent_net_pos_bing_10
replace re_high_sent_net_pos_bing_10 = 0 if cs_sample_focus100 == 1 & sent_any_text_10 == 1 & sent_net_pos_bing_10 < med_sent_net_pos_bing_10

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & re_high_sent_net_pos_bing_10 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_scope10_netpos_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & re_high_sent_net_pos_bing_10 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_scope10_netpos_high

* E5. Previous-visible-month average Bing sentiment boundary.
* As a robustness check, use the average Bing sentiment from the most recent prior visible review month.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.prevvis_sent_avg_bing ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & prevvis_sent_any_text == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_bingavg

* E5a-E5b. Previous-visible-month average-Bing grouped regressions.
* Split hotels into lower- and higher-sentiment cells within each Zip-month.
capture drop med_prevvis_sent_avg_bing
capture drop re_high_prevvis_sent_avg_bing
bysort Zip ym: egen med_prevvis_sent_avg_bing = median(prevvis_sent_avg_bing) if prevvis_sent_any_text == 1
generate re_high_prevvis_sent_avg_bing = 1 if cs_sample_focus100 == 1 & prevvis_sent_any_text == 1 & prevvis_sent_avg_bing >= med_prevvis_sent_avg_bing
replace re_high_prevvis_sent_avg_bing = 0 if cs_sample_focus100 == 1 & prevvis_sent_any_text == 1 & prevvis_sent_avg_bing < med_prevvis_sent_avg_bing

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & re_high_prevvis_sent_avg_bing == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_bingavg_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & re_high_prevvis_sent_avg_bing == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_bingavg_high

* E6. Previous-visible-month net-positive Bing sentiment boundary.
* As a robustness check, use the net positive-minus-negative Bing share from the most recent prior visible review month.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.prevvis_sent_net_pos_bing ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & prevvis_sent_any_text == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_netpos

* E6a-E6b. Previous-visible-month net-positive grouped regressions.
* Split hotels into lower- and higher-net-positive cells within each Zip-month.
capture drop med_prevvis_sent_net_pos_bing
capture drop re_hi_prevvis_netpos
bysort Zip ym: egen med_prevvis_sent_net_pos_bing = median(prevvis_sent_net_pos_bing) if prevvis_sent_any_text == 1
generate re_hi_prevvis_netpos = 1 if cs_sample_focus100 == 1 & prevvis_sent_any_text == 1 & prevvis_sent_net_pos_bing >= med_prevvis_sent_net_pos_bing
replace re_hi_prevvis_netpos = 0 if cs_sample_focus100 == 1 & prevvis_sent_any_text == 1 & prevvis_sent_net_pos_bing < med_prevvis_sent_net_pos_bing

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & re_hi_prevvis_netpos == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_netpos_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & re_hi_prevvis_netpos == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_prevvis_netpos_high

*******************************************************
************ 4. export current model set **************
*******************************************************

esttab ///
    env_scope10_sd env_prevvis_sd env_scope10_bingavg env_scope10_netpos env_prevvis_bingavg env_prevvis_netpos ///
    using "`table_dir'/routeA_review_environment_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("scope10 sd" "prevvis sd" "scope10 bing avg" "scope10 net pos" "prevvis bing avg" "prevvis net pos") ///
    nogap compress

esttab ///
    env_scope10_sd env_prevvis_sd env_scope10_bingavg env_scope10_netpos env_prevvis_bingavg env_prevvis_netpos ///
    using "`csv_dir'/routeA_review_environment_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("scope10 sd" "prevvis sd" "scope10 bing avg" "scope10 net pos" "prevvis bing avg" "prevvis net pos") ///
    nogap

esttab ///
    env_scope10_sd_low env_scope10_sd_high ///
    env_prevvis_sd_low env_prevvis_sd_high ///
    env_scope10_bingavg_low env_scope10_bingavg_high ///
    env_scope10_netpos_low env_scope10_netpos_high ///
    env_prevvis_bingavg_low env_prevvis_bingavg_high ///
    env_prevvis_netpos_low env_prevvis_netpos_high ///
    using "`table_dir'/routeA_review_environment_grouped_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("scope10 sd low" "scope10 sd high" "prevvis sd low" "prevvis sd high" "scope10 bing avg low" "scope10 bing avg high" "scope10 net pos low" "scope10 net pos high" "prevvis bing avg low" "prevvis bing avg high" "prevvis net pos low" "prevvis net pos high") ///
    nogap compress

esttab ///
    env_scope10_sd_low env_scope10_sd_high ///
    env_prevvis_sd_low env_prevvis_sd_high ///
    env_scope10_bingavg_low env_scope10_bingavg_high ///
    env_scope10_netpos_low env_scope10_netpos_high ///
    env_prevvis_bingavg_low env_prevvis_bingavg_high ///
    env_prevvis_netpos_low env_prevvis_netpos_high ///
    using "`csv_dir'/routeA_review_environment_grouped_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("scope10 sd low" "scope10 sd high" "prevvis sd low" "prevvis sd high" "scope10 bing avg low" "scope10 bing avg high" "scope10 net pos low" "scope10 net pos high" "prevvis bing avg low" "prevvis bing avg high" "prevvis net pos low" "prevvis net pos high") ///
    nogap

log close
