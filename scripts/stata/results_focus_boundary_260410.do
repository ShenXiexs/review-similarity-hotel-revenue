*******************************************************
* results_focus_boundary_260410.do
* Purpose:
*   Export raw Stata tables for boundary-rescan rules:
*   1) rating_last = cityy_median_strict
*   2) star = <3 vs >3
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
log using "`log_dir'/results_focus_boundary_260410.log", text replace

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

quietly levelsof selected_control_family if main_sample_keep == 1, local(selected_ctrl) clean
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

di as text "============================================================"
di as text "1) BOUNDARY RESCAN GROUPED FE"
di as text "============================================================"

capture drop md_rating_cityy high_rating_last_boundary
bysort CityID Year: egen md_rating_cityy = median(lag_avg_rating_month) if main_sample_keep == 1
gen byte high_rating_last_boundary = .
replace high_rating_last_boundary = 0 if main_sample_keep == 1 & !missing(lag_avg_rating_month, md_rating_cityy) & lag_avg_rating_month < md_rating_cityy
replace high_rating_last_boundary = 1 if main_sample_keep == 1 & !missing(lag_avg_rating_month, md_rating_cityy) & lag_avg_rating_month > md_rating_cityy

capture drop high_star_boundary
gen byte high_star_boundary = .
replace high_star_boundary = 0 if main_sample_keep == 1 & !missing(star_class) & star_class < 3
replace high_star_boundary = 1 if main_sample_keep == 1 & !missing(star_class) & star_class > 3

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_last_boundary == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g1_rating_last_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_last_boundary == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g2_rating_last_high

reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_star_boundary == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g3_star_low
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_star_boundary == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store g4_star_high

esttab g1_rating_last_low g2_rating_last_high g3_star_low g4_star_high ///
    using "`table_dir'/results_focus_boundary_260410_group.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

di as text "============================================================"
di as text "2) BOUNDARY RESCAN INTERACTION FE"
di as text "============================================================"

reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_last_boundary `ctrl_base' if main_sample_keep == 1 & !missing(high_rating_last_boundary), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store i1_rating_last

reghdfe ln_RevPAR_clean c.sim_mean##i.high_star_boundary `ctrl_base' if main_sample_keep == 1 & !missing(high_star_boundary), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store i2_star

esttab i1_rating_last i2_star ///
    using "`table_dir'/results_focus_boundary_260410_interaction.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

log close
