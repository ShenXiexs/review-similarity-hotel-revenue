*******************************************************
* results_focus_tables_260407.do
* Purpose:
*   1) export same-sample FE / OLS tables for Paper_Results_260407.md
*   2) export grouped FE tables on the selected within-sample moderator rules
*   3) keep FE as the baseline and treat pre2019 as one time-robustness check
*******************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local output_root "`project'/outputs"
local data_dir "`output_root'/data"
local table_dir "`output_root'/tables"
local log_dir "`output_root'/logs"
cap mkdir "`output_root'"
cap mkdir "`data_dir'"
cap mkdir "`table_dir'"
cap mkdir "`log_dir'"
local data_main "`data_dir'/valid_match_review_acc_260407_main.dta"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find valid_match_review_acc_260407_main.dta. Run scripts/r/Review_Simi_260325.Rmd first."
    exit 601
}

use "`data_main'", clear
log using "`log_dir'/results_focus_tables_260407.log", text replace

capture confirm numeric variable HotelID
if _rc {
    encode HotelID, gen(hotel_id_num)
}
else {
    gen long hotel_id_num = HotelID
}

capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

capture which reghdfe
if _rc {
    di as error "reghdfe not found. Please run: ssc install reghdfe, replace"
    exit 199
}

capture which esttab
if _rc {
    di as error "esttab not found. Please run: ssc install estout, replace"
    exit 199
}

quietly levelsof selected_control_family if main_sample_keep == 1, local(selected_ctrl) clean
if "`selected_ctrl'" == "" {
    di as error "selected_control_family not found on the adopted sample."
    exit 459
}

local ctrl_base
if "`selected_ctrl'" == "rich8_current" {
    local ctrl_base "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "quality6" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month ln_avg_com_RevPAR review_freshness ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "base4_acc" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "base4_month" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "lean3" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "momentum_plus" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR rating_momentum volume_momentum review_freshness ln_lag_RevPAR_clean"
}
else {
    di as error "Unknown selected_control_family: `selected_ctrl'"
    exit 198
}

local ctrl_dm
foreach var of local ctrl_base {
    local ctrl_dm "`ctrl_dm' `var'_dm_cym"
}
local ctrl_dm : list retokenize ctrl_dm

di as text "Selected FE/OLS control family: `selected_ctrl'"

* -----------------------------
* 1) Main FE table: shared sample baseline + pre2019 robustness
* -----------------------------
di as text "============================================================"
di as text "1) MAIN FE TABLE"
di as text "============================================================"
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store m1_focus

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & Year <= 2019, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store m2_pre2019

esttab m1_focus m2_pre2019 ///
    using "`table_dir'/results_focus260407_main.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

* -----------------------------
* 2) OLS table on the same rows
* -----------------------------
di as text "============================================================"
di as text "2) SAME-SAMPLE OLS TABLE"
di as text "============================================================"
reg ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1, vce(cluster hotel_id_num)
estimates store o1_focus

reg ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & Year <= 2019, vce(cluster hotel_id_num)
estimates store o2_pre2019

esttab o1_focus o2_pre2019 ///
    using "`table_dir'/results_focus260407_ols.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

* -----------------------------
* 3) Demeaned FE / OLS table on the same rows
* -----------------------------
di as text "============================================================"
di as text "3) DEMEANED SAME-SAMPLE TABLES"
di as text "============================================================"
reghdfe ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store d1_focus_fe

reghdfe ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1 & Year <= 2019, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store d2_pre2019_fe

reg ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1, vce(cluster hotel_id_num)
estimates store d3_focus_ols

reg ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1 & Year <= 2019, vce(cluster hotel_id_num)
estimates store d4_pre2019_ols

esttab d1_focus_fe d2_pre2019_fe d3_focus_ols d4_pre2019_ols ///
    using "`table_dir'/results_focus260407_demean.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

* -----------------------------
* 4) Core heterogeneity on the same shared sample
* -----------------------------
di as text "============================================================"
di as text "4) GROUPED FE TABLES"
di as text "============================================================"
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_month == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f1_rating_last_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_month == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f2_rating_last_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f3_rating_acc_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f4_rating_acc_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_month == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f5_volume_last_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_month == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f6_volume_last_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f7_volume_acc_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f8_volume_acc_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & star_ge3 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f9_star_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & star_ge3 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store f10_star_high

esttab f1_rating_last_low f2_rating_last_high f3_rating_acc_low f4_rating_acc_high f5_volume_last_low f6_volume_last_high f7_volume_acc_low f8_volume_acc_high f9_star_low f10_star_high ///
    using "`table_dir'/results_focus260407_group.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

log close
