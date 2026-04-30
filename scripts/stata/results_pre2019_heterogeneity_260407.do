*******************************************************
* results_pre2019_heterogeneity_260407.do
* Purpose:
*   1) export pre2019 grouped FE tables on the selected rules
*   2) export pre2019 binary / continuous interaction FE tables
*   3) preserve full raw Stata output for Paper_Results_260407.md
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
local data_pre "`data_dir'/valid_match_review_acc_260407_main.dta"

capture confirm file "`data_pre'"
if _rc {
    di as error "Cannot find valid_match_review_acc_260407_main.dta."
    exit 601
}

use "`data_pre'", clear
keep if main_sample_keep == 1 & Year <= 2019
log using "`log_dir'/results_pre2019_heterogeneity_260407.log", text replace

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

quietly levelsof selected_control_family, local(selected_ctrl) clean
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

capture drop md_rating_last_pre q30_rating_acc_pre q70_rating_acc_pre md_volume_last_pre md_volume_acc_pre
capture drop high_rating_month_pre high_rating_acc_pre high_volume_month_pre high_volume_acc_pre high_star_pre
capture drop center_rating_month_pre center_rating_acc_pre center_volume_month_pre center_volume_acc_pre

bysort CityID Year: egen md_rating_last_pre = median(lag_avg_rating_month)
bysort CityID Year: egen mean_rating_last_pre = mean(lag_avg_rating_month)
gen byte high_rating_month_pre = .
replace high_rating_month_pre = 0 if !missing(lag_avg_rating_month, md_rating_last_pre) & lag_avg_rating_month < md_rating_last_pre
replace high_rating_month_pre = 1 if !missing(lag_avg_rating_month, md_rating_last_pre) & lag_avg_rating_month > md_rating_last_pre
gen double center_rating_month_pre = lag_avg_rating_month - mean_rating_last_pre if !missing(lag_avg_rating_month, mean_rating_last_pre)

bysort CityID Year: egen q30_rating_acc_pre = pctile(lag_avg_rating_acc), p(30)
bysort CityID Year: egen q70_rating_acc_pre = pctile(lag_avg_rating_acc), p(70)
bysort CityID Year: egen mean_rating_acc_pre = mean(lag_avg_rating_acc)
gen byte high_rating_acc_pre = .
replace high_rating_acc_pre = 0 if !missing(lag_avg_rating_acc, q30_rating_acc_pre) & lag_avg_rating_acc <= q30_rating_acc_pre
replace high_rating_acc_pre = 1 if !missing(lag_avg_rating_acc, q70_rating_acc_pre) & lag_avg_rating_acc >= q70_rating_acc_pre
gen double center_rating_acc_pre = lag_avg_rating_acc - mean_rating_acc_pre if !missing(lag_avg_rating_acc, mean_rating_acc_pre)

bysort Year Mon: egen md_volume_last_pre = median(lag_recent_volumn)
bysort Year Mon: egen mean_volume_last_pre = mean(lag_recent_volumn)
gen byte high_volume_month_pre = .
replace high_volume_month_pre = 0 if !missing(lag_recent_volumn, md_volume_last_pre) & lag_recent_volumn < md_volume_last_pre
replace high_volume_month_pre = 1 if !missing(lag_recent_volumn, md_volume_last_pre) & lag_recent_volumn >= md_volume_last_pre
gen double center_volume_month_pre = lag_recent_volumn - mean_volume_last_pre if !missing(lag_recent_volumn, mean_volume_last_pre)

bysort Year Mon: egen md_volume_acc_pre = median(lag_volumn_acc)
bysort Year Mon: egen mean_volume_acc_pre = mean(lag_volumn_acc)
gen byte high_volume_acc_pre = .
replace high_volume_acc_pre = 0 if !missing(lag_volumn_acc, md_volume_acc_pre) & lag_volumn_acc < md_volume_acc_pre
replace high_volume_acc_pre = 1 if !missing(lag_volumn_acc, md_volume_acc_pre) & lag_volumn_acc >= md_volume_acc_pre
gen double center_volume_acc_pre = lag_volumn_acc - mean_volume_acc_pre if !missing(lag_volumn_acc, mean_volume_acc_pre)

gen byte high_star_pre = .
replace high_star_pre = 0 if !missing(star_class) & star_class < 3
replace high_star_pre = 1 if !missing(star_class) & star_class > 3

local rule_rating_last "cityy_median_strict"
local rule_rating_acc "cityy_3070"
local rule_volume_last "ym_median"
local rule_volume_acc "ym_median"
local rule_star "star_lt3_gt3"

di as text "Selected pre2019 rules:"
di as text "rating_last         = `rule_rating_last'"
di as text "rating_accumulative = `rule_rating_acc'"
di as text "volume_last         = `rule_volume_last'"
di as text "volume_accumulative = `rule_volume_acc'"
di as text "star                = `rule_star'"

di as text "============================================================"
di as text "1) PRE2019 GROUPED FE"
di as text "============================================================"
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_month_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g1_rating_last_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_month_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g2_rating_last_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_acc_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g3_rating_acc_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_acc_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g4_rating_acc_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_month_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g5_volume_last_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_month_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g6_volume_last_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_acc_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g7_volume_acc_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_acc_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g8_volume_acc_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_star_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g9_star_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_star_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g10_star_high

esttab g1_rating_last_low g2_rating_last_high g3_rating_acc_low g4_rating_acc_high g5_volume_last_low g6_volume_last_high g7_volume_acc_low g8_volume_acc_high g9_star_low g10_star_high ///
    using "`table_dir'/results_pre2019_heterogeneity_group_260407.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

di as text "============================================================"
di as text "2) PRE2019 BINARY INTERACTION FE"
di as text "============================================================"
reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_month_pre `ctrl_base' if !missing(high_rating_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b1_rating_last
reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_acc_pre `ctrl_base' if !missing(high_rating_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b2_rating_acc
reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_month_pre `ctrl_base' if !missing(high_volume_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b3_volume_last
reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_acc_pre `ctrl_base' if !missing(high_volume_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b4_volume_acc
reghdfe ln_RevPAR_clean c.sim_mean##i.high_star_pre `ctrl_base' if !missing(high_star_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b5_star

esttab b1_rating_last b2_rating_acc b3_volume_last b4_volume_acc b5_star ///
    using "`table_dir'/results_pre2019_heterogeneity_interaction_binary_260407.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

di as text "============================================================"
di as text "3) PRE2019 CONTINUOUS INTERACTION FE"
di as text "============================================================"
reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_month_pre `ctrl_base' if !missing(center_rating_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c1_rating_last
reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_acc_pre `ctrl_base' if !missing(center_rating_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c2_rating_acc
reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_month_pre `ctrl_base' if !missing(center_volume_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c3_volume_last
reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_acc_pre `ctrl_base' if !missing(center_volume_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c4_volume_acc

esttab c1_rating_last c2_rating_acc c3_volume_last c4_volume_acc ///
    using "`table_dir'/results_pre2019_heterogeneity_interaction_continuous_260407.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

log close
