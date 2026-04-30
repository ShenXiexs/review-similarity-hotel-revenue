*******************************************************
* results_focus_interaction_260407.do
* Purpose:
*   1) run binary interaction FE for the five paper moderators
*   2) run continuous interaction FE for rating / volume moderators
*   3) preserve full raw Stata output in a dedicated log
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
log using "`log_dir'/results_focus_interaction_260407.log", text replace

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

di as text "Selected interaction control family: `selected_ctrl'"

di as text "============================================================"
di as text "1) BINARY INTERACTION FE"
di as text "============================================================"
reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_month `ctrl_base' if main_sample_keep == 1 & !missing(high_rating_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b1_rating_last
reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_acc `ctrl_base' if main_sample_keep == 1 & !missing(high_rating_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b2_rating_acc
reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_month `ctrl_base' if main_sample_keep == 1 & !missing(high_volume_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b3_volume_last
reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_acc `ctrl_base' if main_sample_keep == 1 & !missing(high_volume_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b4_volume_acc
reghdfe ln_RevPAR_clean c.sim_mean##i.star_ge3 `ctrl_base' if main_sample_keep == 1 & !missing(star_ge3), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store b5_star

esttab b1_rating_last b2_rating_acc b3_volume_last b4_volume_acc b5_star ///
    using "`table_dir'/results_focus260407_interaction_binary.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

di as text "============================================================"
di as text "2) CONTINUOUS INTERACTION FE"
di as text "============================================================"
reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_month `ctrl_base' if main_sample_keep == 1 & !missing(center_rating_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c1_rating_last
reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_acc `ctrl_base' if main_sample_keep == 1 & !missing(center_rating_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c2_rating_acc
reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_month `ctrl_base' if main_sample_keep == 1 & !missing(center_volume_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c3_volume_last
reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_acc `ctrl_base' if main_sample_keep == 1 & !missing(center_volume_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store c4_volume_acc

esttab c1_rating_last c2_rating_acc c3_volume_last c4_volume_acc ///
    using "`table_dir'/results_focus260407_interaction_continuous.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

log close
