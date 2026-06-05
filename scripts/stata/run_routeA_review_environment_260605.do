*******************************************************
* run_routeA_review_environment_260605.do
* Route A extension: ARS as the main effect, with review
* environment boundaries from dispersion, dynamics, and
* sentiment conditions.
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
log using "`log_dir'/run_routeA_review_environment_`run_id'.log", text replace

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

capture drop sim_mean_c recent_sd_c sd_acc_c rmom_c fresh_c sentbing_c sentnet_c sentneg_c lsentnet_c sentsd_c
quietly summarize sim_mean if cs_sample_focus100 == 1 & !missing(sim_mean)
gen double sim_mean_c = sim_mean - r(mean) if !missing(sim_mean)
quietly summarize recent_sd if cs_sample_focus100 == 1 & !missing(recent_sd)
gen double recent_sd_c = recent_sd - r(mean) if !missing(recent_sd)
quietly summarize sd_acc if cs_sample_focus100 == 1 & !missing(sd_acc)
gen double sd_acc_c = sd_acc - r(mean) if !missing(sd_acc)
quietly summarize rating_momentum if cs_sample_focus100 == 1 & !missing(rating_momentum)
gen double rmom_c = rating_momentum - r(mean) if !missing(rating_momentum)
quietly summarize review_freshness if cs_sample_focus100 == 1 & !missing(review_freshness)
gen double fresh_c = review_freshness - r(mean) if !missing(review_freshness)
quietly summarize sent_avg_bing if cs_sample_focus100 == 1 & !missing(sent_avg_bing)
gen double sentbing_c = sent_avg_bing - r(mean) if !missing(sent_avg_bing)
quietly summarize sent_net_pos_bing if cs_sample_focus100 == 1 & !missing(sent_net_pos_bing)
gen double sentnet_c = sent_net_pos_bing - r(mean) if !missing(sent_net_pos_bing)
quietly summarize sent_neg_share_bing if cs_sample_focus100 == 1 & !missing(sent_neg_share_bing)
gen double sentneg_c = sent_neg_share_bing - r(mean) if !missing(sent_neg_share_bing)
quietly summarize lag_sent_net_pos_bing if cs_sample_focus100 == 1 & !missing(lag_sent_net_pos_bing)
gen double lsentnet_c = lag_sent_net_pos_bing - r(mean) if !missing(lag_sent_net_pos_bing)
quietly summarize sent_sd_bing if cs_sample_focus100 == 1 & !missing(sent_sd_bing)
gen double sentsd_c = sent_sd_bing - r(mean) if !missing(sent_sd_bing)

estimates clear

* E1. Recent rating dispersion boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.recent_sd_c ///
    ln_recent_volumn recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_recentsd

* E2. Accumulated dispersion boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.sd_acc_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_accsd

* E3. Rating momentum boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.rmom_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_momentum

* E4. Review freshness boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.fresh_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_fresh

* E5. Current average Bing sentiment boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.sentbing_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_bingavg

* E6. Current net-positive sentiment boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.sentnet_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_netpos

* E7. Current negative-share boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.sentneg_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_negshare

* E8. Prior-month net-positive sentiment boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.lsentnet_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_lagnet

* E9. Sentiment volatility boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.sentsd_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store env_sentsd

esttab env_recentsd env_accsd env_momentum env_fresh env_bingavg env_netpos env_negshare env_lagnet env_sentsd using "`table_dir'/routeA_review_environment_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recent sd" "acc sd" "momentum" "freshness" "bing avg" "net pos" "neg share" "lag net" "sent sd") nogap compress
esttab env_recentsd env_accsd env_momentum env_fresh env_bingavg env_netpos env_negshare env_lagnet env_sentsd using "`csv_dir'/routeA_review_environment_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recent sd" "acc sd" "momentum" "freshness" "bing avg" "net pos" "neg share" "lag net" "sent sd") nogap

log close
