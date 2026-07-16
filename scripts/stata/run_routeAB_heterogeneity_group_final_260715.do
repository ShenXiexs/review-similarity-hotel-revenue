************************************************************
* Route A/B heterogeneity: interaction, high group, low group,
* and bdiff group-difference test for every moderator.
* Final deliverables only: one DTA and one RTF.
************************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close _all
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_main "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local profile_csv "`project'/full-data/hotel_profile_TP.csv"
local data_final "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local rtf_final "`project'/outputs/paper/routeAB_heterogeneity_group_interaction_final_260715.rtf"

foreach f in "`data_main'" "`profile_csv'" {
    capture confirm file "`f'"
    if _rc exit 601
}
foreach cmd in reghdfe winsor2 esttab bdiff {
    capture which `cmd'
    if _rc exit 199
}

************************************************************
* 1. Load the Route-A/Route-B panel and the raw profile fields.
************************************************************

tempfile hotel_profile
preserve
    import delimited using "`profile_csv'", varnames(1) ///
        bindquote(loose) maxquotedrows(unlimited) encoding("UTF-8") clear
    keep hotel_id_ta hotel_amenities hotel_style travelers_choice hotel_class
    capture confirm numeric variable hotel_class
    if _rc destring hotel_class, replace force
    rename hotel_id_ta HotelID
    rename hotel_class profile_hotel_class
    capture confirm string variable HotelID
    if _rc tostring HotelID, replace format(%18.0f)
    replace HotelID = strtrim(HotelID)
    duplicates drop HotelID, force
    save `hotel_profile', replace
restore

use "`data_main'", clear
keep if cs_sample_focus100 == 1
merge m:1 HotelID using `hotel_profile', keep(master match) nogen

* Standardize hotel stars to their literal 1.0--5.0 scale.  The panel variable
* star_class is label-coded (1=1.0, 2=1.5, ..., 9=5.0), whereas the profile
* variable hotel_class is already on the literal scale.  Use the profile as
* the authoritative source whenever available; use the panel only as a fallback
* for the few hotels that have no profile hotel_class.
capture drop star_class_panel_raw star_class_final_source
recode star_class ///
    (1 = 1.0) (2 = 1.5) (3 = 2.0) (4 = 2.5) (5 = 3.0) ///
    (6 = 3.5) (7 = 4.0) (8 = 4.5) (9 = 5.0), gen(star_class_panel_raw)
drop star_class
gen double star_class = profile_hotel_class ///
    if inrange(profile_hotel_class, 1, 5)
replace star_class = star_class_panel_raw ///
    if missing(star_class) & inrange(star_class_panel_raw, 1, 5)
gen byte star_class_final_source = .
replace star_class_final_source = 1 if inrange(profile_hotel_class, 1, 5)
replace star_class_final_source = 2 if missing(profile_hotel_class) ///
    & !missing(star_class)
label define star_class_final_source_lbl ///
    1 "Hotel profile (primary source)" 2 "Original panel (profile missing)", replace
label values star_class_final_source star_class_final_source_lbl
label variable star_class_panel_raw "Hotel star class from panel (actual 1.0--5.0)"
label variable star_class_final_source "Source of final hotel star class"
label variable star_class "Hotel star class (profile primary; panel fallback; 1.0--5.0)"

capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
winsor2 ln_lag_RevPAR_clean, cuts(1 95) suffix(_w195)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

egen byte het_missing = rowmiss(ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199)
gen byte het_base_cc = (het_missing == 0)
label variable het_base_cc "Common complete-case sample"

label variable sim_mean "ARS"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable recent_rating_10 "Recent rating"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating"
label variable lag_sd_acc "Accumulated rating SD"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"
label variable ln_lag_RevPAR_clean_w199 "ln(RevPAR), lagged"
label define het_lowhigh 0 "Low" 1 "High", replace

estimates clear

************************************************************
* 2-1. Accumulated rating: construct group, interaction, high,
*    low, then bdiff.
************************************************************

drop het_med_acc_rating
drop het_high_acc_rating
bysort City ym: egen double het_med_acc_rating = median(lag_avg_rating_acc) if het_base_cc
gen byte het_high_acc_rating = (lag_avg_rating_acc > het_med_acc_rating) if het_base_cc

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if lag_avg_rating_acc <= het_med_acc_rating, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_acc_rating


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if lag_avg_rating_acc > het_med_acc_rating, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_acc_rating


bdiff, group(het_high_acc_rating) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260716) first
*** 没有通过！但是比之前的好些


esttab low_acc_rating high_acc_rating using "heterogeneity_acc_rating.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 3-1. Accumulated volume: construct group, interaction, high,
*    low, then bdiff.
************************************************************

drop het_med_acc_volume
drop het_high_acc_volume 
bysort City ym: egen double het_med_acc_volume = median(ln_lag_volumn_acc) if het_base_cc
gen byte het_high_acc_volume = (ln_lag_volumn_acc > het_med_acc_volume) if het_base_cc

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if ln_lag_volumn_acc <= het_med_acc_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_acc_volume


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if ln_lag_volumn_acc > het_med_acc_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_acc_volume


bdiff, group(het_high_acc_volume) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(100) seed(260716) first
* 已经通过！

esttab low_acc_volume high_acc_volume using "heterogeneity_volume.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 3-2. recent volume: construct group, interaction, high,
*    low, then bdiff.
************************************************************

drop het_med_re_volume
drop het_high_re_volume 
bysort City ym: egen double het_med_re_volume = median(ln_recent_volumn_10) if het_base_cc
gen byte het_high_re_volume = (ln_recent_volumn_10 > het_med_re_volume) if het_base_cc

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if ln_recent_volumn_10 <= het_med_re_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_re_volume


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if ln_recent_volumn_10 > het_med_re_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_re_volume


bdiff, group(het_high_re_volume) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first
* 已经通过！

esttab low_re_volume high_re_volume using "heterogeneity_re_volume.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 4-1. Accumulated rating SD: construct group, interaction,
*    high, low, then bdiff.
************************************************************

drop het_med_acc_sd
drop het_high_acc_sd
bysort ym: egen double het_med_acc_sd = median(lag_sd_acc) if het_base_cc
gen byte het_high_acc_sd = (lag_sd_acc > het_med_acc_sd) if het_base_cc


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if lag_sd_acc < het_med_acc_sd, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_acc_sd

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if lag_sd_acc > het_med_acc_sd, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_acc_sd

bdiff, group(het_high_acc_sd) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first
	
esttab low_acc_sd high_acc_sd using "heterogeneity_acc_sd.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress



************************************************************
* 5. HotelOverStar: construct group, interaction,
*    high, low, then bdiff.
************************************************************

* star_class is the completed actual 1.0--5.0 scale prepared above. Profile is
* the primary source; the original panel is retained only where profile is unavailable.
capture drop het_high_star

gen byte het_high_star = .
replace het_high_star = 0 if !missing(star_class) & star_class < 3.5
replace het_high_star = 1 if !missing(star_class) & star_class >= 3.5


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_star == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_star

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_star == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_star

bdiff, group(het_high_star) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_star high_star using "heterogeneity_star.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress
	
************************************************************
* 6. Chain affiliation: interaction, chain, non-chain, then bdiff.
************************************************************

tab chain

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if het_base_cc == 1 & chain == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store result_chain

replace chain = 0 if missing(chain)
tab chain
reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if het_base_cc == 1 & chain == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store result_indep

bdiff, group(chain) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first
	
esttab result_chain result_indep using "heterogeneity_chain.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

