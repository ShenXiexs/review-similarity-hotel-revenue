*******************************************************
* run_routeA_organization_boundaries_260605.do
* Route A extension: ARS as the main effect, with
* organization-form boundaries from chain structure.
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

use "`data_main'", clear
log using "`log_dir'/run_routeA_organization_boundaries_`run_id'.log", text replace

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

keep if cs_sample_focus100 == 1 

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

* Reattach explicit star-class labels so factor-variable output shows the original hotel-star values.
capture label drop star_class_final_lbl
label define star_class_final_lbl ///
    1 "1.0" ///
    2 "1.5" ///
    3 "2.0" ///
    4 "2.5" ///
    5 "3.0" ///
    6 "3.5" ///
    7 "4.0" ///
    8 "4.5" ///
    9 "5.0"
capture label values star_class_final star_class_final_lbl

* Build coarser star-class groups for easier interpretation.
capture drop star_class_bucket3
gen byte star_class_bucket3 = .
replace star_class_bucket3 = 1 if !missing(star_class_final_raw) & star_class_final_raw < 3
replace star_class_bucket3 = 2 if !missing(star_class_final_raw) & star_class_final_raw >= 3 & star_class_final_raw < 4
replace star_class_bucket3 = 3 if !missing(star_class_final_raw) & star_class_final_raw >= 4
label define star_class_bucket3_lbl 1 "<3.0" 2 "3.0-<4.0" 3 ">=4.0", replace
label values star_class_bucket3 star_class_bucket3_lbl

* Build simple status boundaries aligned with the low/high class-quality-rank logic.
capture drop high_star4
gen byte high_star4 = .
replace high_star4 = 0 if !missing(star_class_final_raw) & star_class_final_raw < 4
replace high_star4 = 1 if !missing(star_class_final_raw) & star_class_final_raw >= 4
label define high_star4_lbl 0 "<4.0" 1 ">=4.0", replace
label values high_star4 high_star4_lbl

label define high_quality_ym_lbl 0 "low quality ym" 1 "high quality ym", replace
capture label values high_quality_ym high_quality_ym_lbl
label define high_quality_cityym_lbl 0 "low quality city-ym" 1 "high quality city-ym", replace
capture label values high_quality_cityym high_quality_cityym_lbl
label define high_quality_zipym_lbl 0 "low quality zip-ym" 1 "high quality zip-ym", replace
capture label values high_quality_zipym high_quality_zipym_lbl

quietly summarize hotel_rank_pct if cs_sample_focus100 == 1 & !missing(hotel_rank_pct), detail
local med_rank = r(p50)
capture drop high_rank_status
gen byte high_rank_status = .
replace high_rank_status = 0 if cs_sample_focus100 == 1 & !missing(hotel_rank_pct) & hotel_rank_pct > `med_rank'
replace high_rank_status = 1 if cs_sample_focus100 == 1 & !missing(hotel_rank_pct) & hotel_rank_pct <= `med_rank'
label define high_rank_status_lbl 0 "low rank status" 1 "high rank status", replace
label values high_rank_status high_rank_status_lbl

capture drop hotel_evaluation_factor
encode hotel_evaluation_raw, gen(hotel_evaluation_factor)

estimates clear

* M1. Chain versus non-chain boundary.
* This tests whether the ARS slope differs between chain and non-chain hotels.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.chain ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(chain), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chain

* M1a-M1b. Chain grouped regressions.
* Estimate the ARS slope separately for non-chain and chain hotels.
reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & chain==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chain_nonchain

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & chain==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chain_chain

* M2. Independent-hotel boundary.
* This tests whether ARS matters differently for independent hotels versus chain-affiliated hotels.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.independent ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(independent), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_indep

* M2a-M2b. Independent grouped regressions.
* Estimate the ARS slope separately for independent and non-independent hotels.
reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & independent==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_indep_yes

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & independent==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_indep_no

* M3. Small-chain boundary.
* This asks whether ARS differs between hotels inside small chains and the rest of the sample.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.chain_small ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(chain_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chsmall

* M3a-M3b. Small-chain grouped regressions.
* Estimate the ARS slope separately outside and inside the small-chain subset.
reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & chain_small==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chsmall_no

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & chain_small==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chsmall_yes

* M4. Three-property chain boundary.
* This isolates very small chains and tests whether their ARS slope differs from the rest of the market.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.chain3_small ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(chain3_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_ch3

* M4a-M4b. Three-property chain grouped regressions.
* Estimate the ARS slope separately outside and inside the three-property-chain subset.
reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & chain3_small==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_ch3_no

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & chain3_small==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_ch3_yes

* M5. Star Class.
* star_class_final is filled by hotel_profile_TP.csv hotel_class when the original panel star_class is missing.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.star_class_final ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(star_class_final), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_star

* M6. Coarser star-class boundary.
* Group hotels into below-3-star, 3-to-below-4-star, and 4-star-and-above buckets.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##ib2.star_class_bucket3 ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(star_class_bucket3), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_star3grp

* M6a-M6c. Star-bucket grouped regressions.
* Estimate the ARS slope separately for below-3-star, 3-to-below-4-star, and 4-star-and-above hotels.
reghdfe ln_RevPAR_clean_w199 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & star_class_bucket3 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_stargrp_lt3

reghdfe ln_RevPAR_clean_w199 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & star_class_bucket3 == 2, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_stargrp_3to4

reghdfe ln_RevPAR_clean_w199 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & star_class_bucket3 == 3, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_stargrp_ge4

* M7. Four-star-and-above boundary.
* Split hotels into below-4-star versus 4-star-and-above using the filled star-class variable.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.high_star4 ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(high_star4), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_star4

* M7a-M7b. Four-star grouped regressions.
* Estimate the ARS slope separately for below-4-star and 4-star-and-above hotels.
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & high_star4==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_star4_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & high_star4==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_star4_high

* M8. Quality boundary based on monthly cumulative rating.
* High-quality hotels are those with lag_avg_rating_acc above the full-sample month median within each ym.
reghdfe ln_RevPAR_clean c.sim_mean##c.lag_avg_rating_acc ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(high_quality_ym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)

reghdfe ln_RevPAR_clean c.sim_mean##i.high_quality_ym ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(high_quality_ym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_ym

* M8a-M8b. Monthly-quality grouped regressions.
* Estimate the ARS slope separately for below-median and above-median hotels within each month.
reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_quality_ym==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_ym_low

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_quality_ym==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_ym_high

* M9. Quality boundary based on city-month relative rating.
* High-quality hotels are those with lag_avg_rating_acc above the City-ym median.
reghdfe ln_RevPAR_clean c.sim_mean##i.high_quality_cityym ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(high_quality_cityym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_cityym

* M9a-M9b. City-month quality grouped regressions.
* Estimate the ARS slope separately for below-median and above-median hotels within each city-month cell.
reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_quality_cityym==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_cityym_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_quality_cityym==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_cityym_high

* M10. Quality boundary based on zip-month relative rating.
* High-quality hotels are those with lag_avg_rating_acc above the Zip-ym median.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_quality_zipym ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(high_quality_zipym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_zipym

* M10a-M10b. Zip-month quality grouped regressions.
* Estimate the ARS slope separately for below-median and above-median hotels within each zip-month cell.
reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_quality_zipym==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_zipym_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_quality_zipym==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_quality_zipym_high

* M11. Rank-status boundary based on normalized platform rank.
* Smaller rank/total ratios mean better standing, so the high-rank-status group is rank_pct <= median.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.high_rank_status ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(high_rank_status), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_rank

* M11a-M11b. Rank grouped regressions.
* Estimate the ARS slope separately for lower-status and higher-status hotels based on normalized platform rank.
reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & high_rank_status==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_rank_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & high_rank_status==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_rank_high

* M12. Hotel evaluation text category boundary.
* Use the original hotel_evaluation text from hotel_profile_TP.csv and keep the raw labels via an encoded factor.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.hotel_evaluation_factor ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(hotel_evaluation_factor), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_eval

* M12a-M12c. Collapsed evaluation grouped regressions.
* Collapse the raw evaluation text into Not Good, Good, and Very Good/Excellent, then estimate separate ARS slopes.
capture drop hotel_quality_group
gen str20 hotel_quality_group = ""
replace hotel_quality_group = "Not Good" ///
    if inlist(hotel_evaluation_raw, "Average", "Poor", "Terrible")
replace hotel_quality_group = "Good" ///
    if hotel_evaluation_raw == "Good"
replace hotel_quality_group = "Very Good/Excellent" ///
    if inlist(hotel_evaluation_raw, "Very Good", "Excellent")
replace hotel_quality_group = "Missing/None" ///
    if missing(hotel_evaluation_raw) | hotel_evaluation_raw == "None"

capture drop hotel_quality_group_f
encode hotel_quality_group, gen(hotel_quality_group_f)

tab hotel_quality_group hotel_quality_group_f, missing

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.hotel_quality_group_f ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(hotel_quality_group_f), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_eval_group

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & hotel_quality_group == "Not Good", ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_eval_notgood

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & hotel_quality_group == "Good", ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_eval_good

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & hotel_quality_group == "Very Good/Excellent", ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_eval_vgood

* M13. Hotel popularity boundary.
* Use the zip-month median lagged cumulative review volume to split hotels into lower- and higher-popularity groups.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.ln_lag_volumn_acc ///
    ln_recent_volumn recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(hotel_evaluation_factor), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_popularity_cont

capture drop med_ln_lag_volumn_acc high_popularity
bysort Zip ym: egen med_ln_lag_volumn_acc = median(ln_lag_volumn_acc)
generate high_popularity = 1 if cs_sample_focus100 == 1 & ln_lag_volumn_acc >  med_ln_lag_volumn_acc
replace high_popularity = 0 if cs_sample_focus100 == 1 & ln_lag_volumn_acc <  med_ln_lag_volumn_acc

* M13a. Popularity binary interaction.
* This pairs the zip-month popularity split with an explicit interaction regression.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.high_popularity ///
    ln_recent_volumn recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(high_popularity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_popularity

* M13b-M13c. Popularity grouped regressions.
* Estimate the ARS slope separately for lower- and higher-popularity hotels within each zip-month cell.
reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_popularity==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_popularity_low

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_popularity==1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_popularity_high

* Main interaction table.
esttab org_chain org_indep org_chsmall org_ch3 org_star org_star3grp org_star4 ///
    org_quality_ym org_quality_cityym org_quality_zipym org_rank org_eval org_eval_group ///
    org_popularity using "`table_dir'/routeA_organization_boundaries_`run_id'.rtf", ///
    replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("chain" "independent" "chain small" "chain3 small" "star class" "star 3 groups" "star >=4" ///
            "quality ym" "quality cityym" "quality zipym" "rank" "evaluation" "eval 3 groups" "popularity") ///
    nogap compress

esttab org_chain org_indep org_chsmall org_ch3 org_star org_star3grp org_star4 ///
    org_quality_ym org_quality_cityym org_quality_zipym org_rank org_eval org_eval_group ///
    org_popularity using "`csv_dir'/routeA_organization_boundaries_`run_id'.csv", ///
    replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("chain" "independent" "chain small" "chain3 small" "star class" "star 3 groups" "star >=4" ///
            "quality ym" "quality cityym" "quality zipym" "rank" "evaluation" "eval 3 groups" "popularity") ///
    nogap

* Grouped-slope table.
esttab org_chain_nonchain org_chain_chain ///
    org_indep_no org_indep_yes ///
    org_chsmall_no org_chsmall_yes ///
    org_ch3_no org_ch3_yes ///
    org_stargrp_lt3 org_stargrp_3to4 org_stargrp_ge4 ///
    org_star4_low org_star4_high ///
    org_quality_ym_low org_quality_ym_high ///
    org_quality_cityym_low org_quality_cityym_high ///
    org_quality_zipym_low org_quality_zipym_high ///
    org_rank_low org_rank_high ///
    org_eval_notgood org_eval_good org_eval_vgood ///
    org_popularity_low org_popularity_high using "`table_dir'/routeA_organization_boundaries_grouped_`run_id'.rtf", ///
    replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("non-chain" "chain" "non-indep" "indep" "non-small-chain" "small-chain" ///
            "non-chain3" "chain3" "<3 star" "3-<4 star" ">=4 star" "<4 star" ">=4 star" ///
            "low q ym" "high q ym" "low q cityym" "high q cityym" "low q zipym" "high q zipym" ///
            "low rank" "high rank" "Not Good" "Good" "Very Good/Excellent" "low popularity" "high popularity") ///
    nogap compress

esttab org_chain_nonchain org_chain_chain ///
    org_indep_no org_indep_yes ///
    org_chsmall_no org_chsmall_yes ///
    org_ch3_no org_ch3_yes ///
    org_stargrp_lt3 org_stargrp_3to4 org_stargrp_ge4 ///
    org_star4_low org_star4_high ///
    org_quality_ym_low org_quality_ym_high ///
    org_quality_cityym_low org_quality_cityym_high ///
    org_quality_zipym_low org_quality_zipym_high ///
    org_rank_low org_rank_high ///
    org_eval_notgood org_eval_good org_eval_vgood ///
    org_popularity_low org_popularity_high using "`csv_dir'/routeA_organization_boundaries_grouped_`run_id'.csv", ///
    replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("non-chain" "chain" "non-indep" "indep" "non-small-chain" "small-chain" ///
            "non-chain3" "chain3" "<3 star" "3-<4 star" ">=4 star" "<4 star" ">=4 star" ///
            "low q ym" "high q ym" "low q cityym" "high q cityym" "low q zipym" "high q zipym" ///
            "low rank" "high rank" "Not Good" "Good" "Very Good/Excellent" "low popularity" "high popularity") ///
    nogap

log close
