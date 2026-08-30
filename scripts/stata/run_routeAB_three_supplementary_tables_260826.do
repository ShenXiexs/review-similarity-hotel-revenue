************************************************************
* Three supplementary Route A/B regression tables:
* 1. Review-count threshold sensitivity.
* 2. Accumulated rating x accumulated rating-SD four groups.
* 3. Lagged accumulated mean helpfulness groups (focus100).
************************************************************

version 17.0
clear all
set more off
set linesize 255

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_full "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_scope10mr_260717.dta"
local data_main "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local outdir "`project'/outputs/paper/rtf-0826"
local rtf "`outdir'/routeAB_three_supplementary_tables_260826.rtf"

capture mkdir "`outdir'"
foreach file in "`data_full'" "`data_main'" {
    capture confirm file "`file'"
    if _rc exit 601
}
foreach cmd in reghdfe winsor2 esttab bdiff {
    capture which `cmd'
    if _rc exit 199
}

local controls "recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR"

************************************************************
* Table 1. Main effect across review-count thresholds.
************************************************************

use "`data_full'", clear

capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
capture confirm variable ym
if _rc gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym

label variable sim_mean "ARS"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable lag_avg_rating_month "Rating month, t-1"
label variable rating_last_5 "Rating last 5, t"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating, t-1"
label variable lag_sd_acc "Accumulated rating SD, t-1"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"
label variable ln_lag_RevPAR_clean "ln(RevPAR), t-1"

estimates clear

reghdfe ln_RevPAR_clean sim_mean `controls' ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store threshold_full

foreach cutoff in 25 50 75 100 125 150 {
    reghdfe ln_RevPAR_clean sim_mean `controls' ln_lag_RevPAR_clean ///
        if revtot_final >= `cutoff', ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store threshold_`cutoff'
}

esttab threshold_full threshold_25 threshold_50 threshold_75 ///
    threshold_100 threshold_125 threshold_150 using "`rtf'", replace rtf ///
    keep(sim_mean `controls' ln_lag_RevPAR_clean) ///
    order(sim_mean `controls' ln_lag_RevPAR_clean) ///
    mtitles("Full" ">=25" ">=50" ">=75" ">=100" ">=125" ">=150") ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N N_clust r2_a, ///
        labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
        fmt(%12.0fc %12.0fc %9.3f)) ///
    title("Table 1. ARS Main Effect Across Review-Count Thresholds") ///
    addnotes("Hotel and calendar-month fixed effects are included." ///
        "Standard errors are clustered at the hotel level." ///
        "Thresholds use each hotel's final cumulative review count.") ///
    label nogap compress

************************************************************
* Table 2. Accumulated rating x accumulated rating-SD groups.
************************************************************

use "`data_main'", clear
keep if revtot_final >= 100

capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
capture confirm variable ym
if _rc gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym

label variable sim_mean "ARS"

capture confirm variable ln_RevPAR_clean_w199
if _rc winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
capture confirm variable ln_lag_RevPAR_clean_w595
if _rc winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)
label variable ln_lag_RevPAR_clean_w595 "Lagged ln(RevPAR), w595"

capture drop four_missing four_base_cc
egen byte four_missing = rowmiss(ln_RevPAR_clean_w199 sim_mean ///
    `controls' ln_lag_RevPAR_clean_w595)
gen byte four_base_cc = (four_missing == 0)

capture drop med_acc_rating med_acc_sd high_acc_rating high_acc_sd rating_sd_group
bysort CityID ym: egen double med_acc_rating = ///
    median(lag_avg_rating_acc) if four_base_cc
bysort CityID ym: egen double med_acc_sd = ///
    median(lag_sd_acc) if four_base_cc

gen byte high_acc_rating = .
replace high_acc_rating = 0 if lag_avg_rating_acc < med_acc_rating & four_base_cc
replace high_acc_rating = 1 if lag_avg_rating_acc >= med_acc_rating & four_base_cc
gen byte high_acc_sd = .
replace high_acc_sd = 0 if lag_sd_acc < med_acc_sd & four_base_cc
replace high_acc_sd = 1 if lag_sd_acc >= med_acc_sd & four_base_cc

gen byte rating_sd_group = .
replace rating_sd_group = 1 if high_acc_rating == 0 & high_acc_sd == 0
replace rating_sd_group = 2 if high_acc_rating == 0 & high_acc_sd == 1
replace rating_sd_group = 3 if high_acc_rating == 1 & high_acc_sd == 0
replace rating_sd_group = 4 if high_acc_rating == 1 & high_acc_sd == 1

label define rating_sd_group_lbl ///
    1 "Low rating / Low SD" 2 "Low rating / High SD" ///
    3 "High rating / Low SD" 4 "High rating / High SD", replace
label values rating_sd_group rating_sd_group_lbl

forvalues group = 1/4 {
    reghdfe ln_RevPAR_clean_w199 sim_mean `controls' ///
        ln_lag_RevPAR_clean_w595 if rating_sd_group == `group', ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store rating_sd_`group'
}

esttab rating_sd_1 rating_sd_2 rating_sd_3 rating_sd_4 ///
    using "`rtf'", append rtf ///
    keep(sim_mean `controls' ln_lag_RevPAR_clean_w595) ///
    order(sim_mean `controls' ln_lag_RevPAR_clean_w595) ///
    mtitles("Low rating / Low SD" "Low rating / High SD" ///
        "High rating / Low SD" "High rating / High SD") ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N N_clust r2_a, ///
        labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
        fmt(%12.0fc %12.0fc %9.3f)) ///
    title("Table 2. Accumulated Rating and Rating-SD Four Groups") ///
    addnotes("Groups are defined using City x month medians." ///
        "The outcome is winsorized at 1-99; lagged outcome at 5-95." ///
        "Hotel and calendar-month fixed effects are included; standard errors are clustered by hotel.") ///
    label nogap compress

************************************************************
* Table 3. Lagged accumulated average helpfulness groups.
************************************************************

use "`data_main'", clear
keep if revtot_final >= 100

capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
capture confirm variable ym
if _rc gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym

label variable sim_mean "ARS"

capture confirm variable ln_RevPAR_clean_w199
if _rc winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
capture confirm variable ln_lag_RevPAR_clean_w199
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
capture confirm variable ln_RevPAR_clean_w195
if _rc winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
capture confirm variable ln_lag_RevPAR_clean_w195
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 95) suffix(_w195)
capture confirm variable ln_RevPAR_clean_w595
if _rc winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
capture confirm variable ln_lag_RevPAR_clean_w595
if _rc winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

label variable ln_lag_RevPAR_clean_w199 "Lagged ln(RevPAR), w199"
label variable ln_lag_RevPAR_clean_w195 "Lagged ln(RevPAR), w195"
label variable ln_lag_RevPAR_clean_w595 "Lagged ln(RevPAR), w595"

label variable lag_avg_helpfulness_acc "Accumulated mean helpful votes, t-1"

capture drop helpful_missing helpful_base_cc med_helpfulness high_helpfulness
egen byte helpful_missing = rowmiss(ln_RevPAR_clean_w199 sim_mean ///
    `controls' ln_lag_RevPAR_clean_w595 lag_avg_helpfulness_acc)
gen byte helpful_base_cc = (helpful_missing == 0)

bysort CityID ym: egen double med_helpfulness = ///
    median(lag_avg_helpfulness_acc) if helpful_base_cc
gen byte high_helpfulness = .
replace high_helpfulness = 0 if lag_avg_helpfulness_acc < med_helpfulness & helpful_base_cc
replace high_helpfulness = 1 if lag_avg_helpfulness_acc >= med_helpfulness & helpful_base_cc

reghdfe ln_RevPAR_clean_w199 sim_mean `controls' ///
    lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w595 ///
    if high_helpfulness == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store helpful_low

reghdfe ln_RevPAR_clean_w199 sim_mean `controls' ///
    lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w595 ///
    if high_helpfulness == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store helpful_high

reghdfe ln_RevPAR_clean_w195 sim_mean `controls' ///
    lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w195 ///
    if high_helpfulness == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store helpful_low_195

reghdfe ln_RevPAR_clean_w195 sim_mean `controls' ///
    lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w195 ///
    if high_helpfulness == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store helpful_high_195

reghdfe ln_RevPAR_clean_w595 sim_mean `controls' ///
    lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w595 ///
    if high_helpfulness == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store helpful_low_595

reghdfe ln_RevPAR_clean_w595 sim_mean `controls' ///
    lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w595 ///
    if high_helpfulness == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store helpful_high_595

bdiff, group(high_helpfulness) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean `controls' ///
        lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(100) seed(260826) first

bdiff, group(high_helpfulness) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean `controls' ///
        lag_avg_helpfulness_acc ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(100) seed(260827) first

esttab helpful_low helpful_high helpful_low_195 helpful_high_195 ///
    helpful_low_595 helpful_high_595 using "`rtf'", append rtf ///
    keep(sim_mean `controls' lag_avg_helpfulness_acc ///
        ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w195 ln_lag_RevPAR_clean_w595) ///
    order(sim_mean `controls' lag_avg_helpfulness_acc ///
        ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w195 ln_lag_RevPAR_clean_w595) ///
    mtitles("w199/Lw595 Low" "w199/Lw595 High" ///
        "w195/Lw195 Low" "w195/Lw195 High" ///
        "w595/Lw595 Low" "w595/Lw595 High") ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N N_clust r2_a, ///
        labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
        fmt(%12.0fc %12.0fc %9.3f)) ///
    title("Table 3. Heterogeneity by Average Review Helpfulness") ///
    addnotes("The focus100 sample is used." ///
        "Helpfulness is the accumulated mean number of helpful votes through the prior month." ///
        "Groups are defined using City x month medians." ///
        "Columns report the reference w199/Lw595 specification and two matched-cut specifications." ///
        "Hotel and calendar-month fixed effects are included; standard errors are clustered by hotel.") ///
    label nogap compress
