*******************************************************
* run_routeB_mr_targeting_260605.do
* Route B / Route C bridge: ARS as a moderator of review
* asset value, with management-response targeting as the
* focal engagement strategy.
*
* The goal is not to treat reply as pure solicitation.
* Instead, reply targeting is treated as observable
* complaint handling and review-environment management.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
mata: mata set matafavor speed
capture log close

*******************************************************
************ 0. paths and required packages ************
*******************************************************

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
if _rc {
    di as error "Cannot find `data_main'."
    exit 601
}

capture which reghdfe
if _rc {
    di as error "reghdfe not found. Install it first: ssc install reghdfe, replace"
    exit 199
}

capture which esttab
if _rc {
    di as error "esttab not found. Install it first: ssc install estout, replace"
    exit 199
}

*******************************************************
************ 1. load data and prepare variables ********
*******************************************************

use "`data_main'", clear
log using "`log_dir'/run_routeB_mr_targeting_`run_id'.log", text replace

di as text "Data source: `data_main'"

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc {
    encode HotelID, gen(hotel_id_num)
}
else {
    gen long hotel_id_num = HotelID
}

keep if cs_sample_focus100 == 1

capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

capture confirm variable ln_lag_mr_words
if _rc {
    capture drop ln_lag_mr_words
    gen double ln_lag_mr_words = ln(lag_mr_text_words + 1)
}

*******************************************************
************ 2. revenue moderation by targeting ********
*******************************************************

estimates clear

* T1. Complaint-heavy reply targeting.
* This asks whether ARS matters differently when management focuses replies on complaint-heavy reviews.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_rep_complaint_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_complaint

* T1a-T1b. Grouped complaint-targeting regressions.
* Split hotels into lower- and higher-complaint-targeting cells within each Zip-month.
capture drop med_lag_mr_rep_complaint_share
capture drop t_hi_complaint
bysort Zip ym: egen med_lag_mr_rep_complaint_share = median(lag_mr_rep_complaint_share)
generate t_hi_complaint = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_rep_complaint_share) & lag_mr_rep_complaint_share > med_lag_mr_rep_complaint_share
replace t_hi_complaint = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_rep_complaint_share) & lag_mr_rep_complaint_share < med_lag_mr_rep_complaint_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1 & t_hi_complaint == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_complaint_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1 & t_hi_complaint == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_complaint_high

* T2. Service-issue targeting.
* Here the interaction tests whether reply focus on service complaints changes the ARS revenue slope.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_rep_service_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_service

* T2a-T2b. Grouped service-targeting regressions.
* Split hotels into lower- and higher-service-targeting cells within each Zip-month.
capture drop med_lag_mr_rep_service_share
capture drop t_hi_service
bysort Zip ym: egen med_lag_mr_rep_service_share = median(lag_mr_rep_service_share)
generate t_hi_service = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_rep_service_share) & lag_mr_rep_service_share > med_lag_mr_rep_service_share
replace t_hi_service = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_rep_service_share) & lag_mr_rep_service_share < med_lag_mr_rep_service_share

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1 & t_hi_service == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_service_low

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1 & t_hi_service == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_service_high

* T3. Room-issue targeting.
* This asks whether room-complaint engagement changes the value of review similarity.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_rep_room_share ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_room

* T3a-T3b. Grouped room-targeting regressions.
* Split hotels into lower- and higher-room-targeting cells within each Zip-month.
capture drop med_lag_mr_rep_room_share
capture drop t_hi_room
bysort Zip ym: egen med_lag_mr_rep_room_share = median(lag_mr_rep_room_share)
generate t_hi_room = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_rep_room_share) & lag_mr_rep_room_share > med_lag_mr_rep_room_share
replace t_hi_room = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_rep_room_share) & lag_mr_rep_room_share < med_lag_mr_rep_room_share

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1 & t_hi_room == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_room_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    lag_mr_any lag_mr_rate lag_mr_count ///
    if cs_sample_focus100 == 1 & t_hi_room == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rt_room_high

esttab rt_complaint rt_service rt_room ///
    using "`table_dir'/routeB_mr_targeting_revenue_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("complaint" "service" "room") ///
    nogap compress

esttab rt_complaint rt_service rt_room ///
    using "`csv_dir'/routeB_mr_targeting_revenue_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("complaint" "service" "room") ///
    nogap

esttab rt_complaint_low rt_complaint_high rt_service_low rt_service_high rt_room_low rt_room_high ///
    using "`table_dir'/routeB_mr_targeting_revenue_grouped_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("complaint low" "complaint high" "service low" "service high" "room low" "room high") ///
    nogap compress

esttab rt_complaint_low rt_complaint_high rt_service_low rt_service_high rt_room_low rt_room_high ///
    using "`csv_dir'/routeB_mr_targeting_revenue_grouped_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("complaint low" "complaint high" "service low" "service high" "room low" "room high") ///
    nogap

*******************************************************
************ 3. targeting and review production ********
*******************************************************

estimates clear

* T4. Next-month review volume.
* This asks whether targeting complaint-heavy or category-specific reviews predicts more later review inflow.
reghdfe ln_recent_volumn ///
    lag_mr_rep_complaint_share lag_mr_rep_service_share lag_mr_rep_room_share ///
    lag_mr_rep_clean_share lag_mr_rep_value_share lag_mr_rate lag_mr_count ///
    ln_lag_mr_words recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_volume

* T5. Next-month ARS.
* This tests whether reply targeting changes the similarity structure of later reviews.
reghdfe sim_mean ///
    lag_mr_rep_complaint_share lag_mr_rep_service_share lag_mr_rep_room_share ///
    lag_mr_rep_clean_share lag_mr_rep_value_share lag_mr_rate lag_mr_count ///
    ln_lag_mr_words ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ///
    ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_ars

* T6. Next-month review sentiment.
* This asks whether reply targeting affects the tone of later review text.
reghdfe sent_net_pos_bing ///
    lag_mr_rep_complaint_share lag_mr_rep_service_share lag_mr_rep_room_share ///
    lag_mr_rep_clean_share lag_mr_rep_value_share lag_mr_rate lag_mr_count ///
    ln_lag_mr_words ln_recent_volumn sim_mean recent_sd recent_rating ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(sent_net_pos_bing), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_sentiment

esttab tm_volume tm_ars tm_sentiment ///
    using "`table_dir'/routeB_mr_targeting_mechanisms_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("DV volume" "DV ARS" "DV sentiment") ///
    nogap compress

esttab tm_volume tm_ars tm_sentiment ///
    using "`csv_dir'/routeB_mr_targeting_mechanisms_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("DV volume" "DV ARS" "DV sentiment") ///
    nogap

log close
