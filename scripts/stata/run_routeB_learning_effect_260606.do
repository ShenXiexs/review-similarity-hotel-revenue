*******************************************************
* run_routeB_learning_effect_260606.do
* Route B extension: learning effect from current ARS
* to next-month review content.
*
* This script adapts the "learning effect" idea from
* GAIRS-style evidence to the current setting:
* - current review similarity (ARS) is the focal regressor
* - outcomes are next-month changes in review structure
*   and review text tone/length
*
* The current panel does not yet contain an aligned
* readability / SMOG measure, so this first version
* focuses on:
*   1. Delta topic similarity
*   2. Delta positive-share
*   3. Delta neutral-share
*   4. Delta negative-share
*   5. Delta average review length
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
local run_id "260606"
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
log using "`log_dir'/run_routeB_learning_effect_`run_id'.log", text replace

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

* Build current and next-month text shares.
capture drop sent_neu_share_bing
gen double sent_neu_share_bing = 1 - sent_pos_share_bing - sent_neg_share_bing if sent_any_text == 1

capture drop lead1_sent_pos_share_bing
capture drop lead1_sent_neu_share_bing
capture drop lead1_sent_neg_share_bing
capture drop lead1_sent_avg_text_words
capture drop lead1_sent_any_text
gen double lead1_sent_pos_share_bing = F1.sent_pos_share_bing
gen double lead1_sent_neu_share_bing = F1.sent_neu_share_bing
gen double lead1_sent_neg_share_bing = F1.sent_neg_share_bing
gen double lead1_sent_avg_text_words = F1.sent_avg_text_words
gen double lead1_sent_any_text = F1.sent_any_text

* Build learning-effect delta outcomes.
capture drop d_topic_similarity
capture drop d_sent_pos_bing
capture drop d_sent_neu_bing
capture drop d_sent_neg_bing
capture drop d_sent_avg_text_words
gen double d_topic_similarity = lead1_sim_mean - sim_mean if !missing(lead1_sim_mean, sim_mean)
gen double d_sent_avg_text_words = lead1_sent_avg_text_words - sent_avg_text_words if !missing(lead1_sent_avg_text_words, sent_avg_text_words)


winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_sent_avg_text_words, cuts(1 99) suffix(_w199)
winsor2 ln_sent_avg_text_words, cuts(5 95) suffix(_w595)


* Group current ARS into low/high cells within each Zip-month.
capture drop med_sim_mean_zipym
capture drop learn_hi_ars
bysort Zip ym: egen med_sim_mean_zipym = median(sim_mean)
gen byte learn_hi_ars = 1 if cs_sample_focus100 == 1 & !missing(sim_mean) & sim_mean > med_sim_mean_zipym
replace learn_hi_ars = 0 if cs_sample_focus100 == 1 & !missing(sim_mean) & sim_mean < med_sim_mean_zipym

estimates clear

* L1. Learning effect on next-month topic similarity.
* A higher current ARS may induce later reviews to look more similar to each other.
reghdfe d_topic_similarity sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    if cs_sample_focus100 == 1 & !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_topic

reghdfe d_topic_similarity c.sim_mean##i.learn_hi_ars ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    if cs_sample_focus100 == 1 & !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_topic_inter

* L1a-L1b. Grouped topic learning regressions.
* Estimate the learning slope separately in low-ARS and high-ARS Zip-month cells.
reghdfe d_topic_similarity sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    if cs_sample_focus100 == 1 & learn_hi_ars == 0 & !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_topic_low

reghdfe d_topic_similarity sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    if cs_sample_focus100 == 1 & learn_hi_ars == 1 & !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_topic_high

* L2. Learning effect on next-month review length.
* A higher current ARS may change how much users write in the next month.
reghdfe ln_sent_avg_text_words sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    if cs_sample_focus100 == 1 & !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_len

reghdfe ln_sent_avg_text_words c.sim_mean##i.learn_hi_ars ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    if cs_sample_focus100 == 1 & !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_len_inter

* L2a-L2b. Grouped length learning regressions.
* Estimate the learning slope separately in low-ARS and high-ARS Zip-month cells.
reghdfe d_sent_avg_text_words sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc  ///
    if cs_sample_focus100 == 1 & learn_hi_ars == 0 & !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_len_low

reghdfe d_sent_avg_text_words sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    if cs_sample_focus100 == 1 & learn_hi_ars == 1 & !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store lf_len_high

esttab lf_topic lf_topic_inter lf_len lf_len_inter ///
    using "`table_dir'/routeB_learning_effect_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("Delta topic" "Topic x high ARS" "Delta length" "Length x high ARS") ///
    nogap compress

esttab lf_topic lf_topic_inter lf_len lf_len_inter ///
    using "`csv_dir'/routeB_learning_effect_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("Delta topic" "Topic x high ARS" "Delta length" "Length x high ARS") ///
    nogap

esttab lf_topic_low lf_topic_high lf_len_low lf_len_high ///
    using "`table_dir'/routeB_learning_effect_grouped_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("topic low" "topic high" "length low" "length high") ///
    nogap compress

esttab lf_topic_low lf_topic_high lf_len_low lf_len_high ///
    using "`csv_dir'/routeB_learning_effect_grouped_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("topic low" "topic high" "length low" "length high") ///
    nogap

log close
