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
local data_main "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local data_final "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local rtf_final "`project'/outputs/paper/routeAB_heterogeneity_group_interaction_final_260715.rtf"

foreach f in "`data_main'" {
    capture confirm file "`f'"
    if _rc exit 601
}
foreach cmd in reghdfe winsor2 esttab bdiff {
    capture which `cmd'
    if _rc exit 199
}

************************************************************
* 1. Load the prepared Route-A/Route-B analysis panel.
* The input DTA already contains profile fields, the final literal 1.0--5.0
* star scale, the common complete-case flag, and Scope-10 MR variables.
************************************************************

use "`data_main'", clear
keep if cs_sample_focus100 == 1

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
sort hotel_id_num ym

* The prepared panel already has 1--99 winsorized fields.  Construct the
* 1--95 and 5--95 variants only when later modules require them.
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



capture confirm variable ln_RevPAR_clean_w199
if _rc winsor2 ln_RevPAR_clean, cuts(1 99) by(City ym) suffix(_w199)

capture confirm variable ln_lag_RevPAR_clean_w199
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 99) by(City ym) suffix(_w199)

capture confirm variable ln_RevPAR_clean_w195
if _rc winsor2 ln_RevPAR_clean, cuts(1 95) by(City ym) suffix(_w195)

capture confirm variable ln_lag_RevPAR_clean_w195
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 95) by(City ym) suffix(_w195)

capture confirm variable ln_RevPAR_clean_w595
if _rc winsor2 ln_RevPAR_clean, cuts(5 95) by(City ym) suffix(_w595)

capture confirm variable ln_lag_RevPAR_clean_w595
if _rc winsor2 ln_lag_RevPAR_clean, cuts(5 95) by(City ym) suffix(_w595)


capture confirm variable het_base_cc
if _rc {
    egen byte het_missing = rowmiss(ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199)
    gen byte het_base_cc = (het_missing == 0)
}
label variable het_base_cc "Common complete-case sample"

label variable sim_mean "ARS"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable lag_avg_rating_month rating_last_5 "Recent rating"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating"
label variable lag_sd_acc "Accumulated rating SD"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"
label variable ln_lag_RevPAR_clean_w199 "ln(RevPAR), lagged"
label variable star_class "Hotel star class (actual 1.0--5.0 scale)"
label define het_lowhigh 0 "Low" 1 "High", replace

estimates clear





************************************************************
* 2-1. Accumulated rating: construct group, high, low, then bdiff.
************************************************************

capture drop het_med_acc_rating
capture drop het_high_acc_rating
bysort City ym: egen double het_med_acc_rating = median(lag_avg_rating_acc) if het_base_cc
gen byte het_high_acc_rating = .
replace het_high_acc_rating = 0 if lag_avg_rating_acc < het_med_acc_rating & het_base_cc
replace het_high_acc_rating = 1 if lag_avg_rating_acc >= het_med_acc_rating & het_base_cc



reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if lag_avg_rating_acc < het_med_acc_rating, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_acc_rating


reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if lag_avg_rating_acc >= het_med_acc_rating, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_acc_rating


bdiff, group(het_high_acc_rating) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(100) seed(260721) first
*** 没有通过！但是比之前的好些


esttab low_acc_rating high_acc_rating using "heterogeneity_acc_rating_0722.rtf", replace rtf ///
    order(sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress
	
************************************************************
* 2-2. recent rating: construct group, high, low, then bdiff.
************************************************************

capture drop het_med_mon_rating
capture drop het_high_mon_rating
bysort City ym: egen double het_med_mon_rating = median(lag_avg_rating_month) if het_base_cc
gen byte het_high_mon_rating = .
replace het_high_mon_rating = 0 if lag_avg_rating_month < het_med_mon_rating & het_base_cc
replace het_high_mon_rating = 1 if lag_avg_rating_month >= het_med_mon_rating & het_base_cc


reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if lag_avg_rating_month < het_med_mon_rating, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_mon_rating


reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if lag_avg_rating_month >= het_med_mon_rating, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_mon_rating


bdiff, group(het_high_mon_rating) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260721) first
*** 没有通过！但是比之前的好些


esttab low_mon_rating high_mon_rating using "heterogeneity_mon_rating_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


************************************************************
* 3-1. Accumulated volume: construct group, high, low, then bdiff.
************************************************************

capture drop het_med_acc_volume
capture drop het_high_acc_volume
bysort City ym: egen double het_med_acc_volume = median(ln_lag_volumn_acc) if het_base_cc
gen byte het_high_acc_volume = .
replace het_high_acc_volume = 0 if ln_lag_volumn_acc < het_med_acc_volume & het_base_cc
replace het_high_acc_volume = 1 if ln_lag_volumn_acc > het_med_acc_volume & het_base_cc

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if ln_lag_volumn_acc < het_med_acc_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_acc_volume


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if ln_lag_volumn_acc > het_med_acc_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_acc_volume


bdiff, group(het_high_acc_volume) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260716) first
* 已经通过！

esttab low_acc_volume high_acc_volume using "heterogeneity_volume.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 3-2. recent volume: construct group, high, low, then bdiff.
************************************************************

capture drop het_med_re_volume
capture drop het_high_re_volume
bysort City ym: egen double het_med_re_volume = median(ln_recent_volumn_10) if het_base_cc
gen byte het_high_re_volume = .
replace het_high_re_volume = 0 if ln_recent_volumn_10 < het_med_re_volume
replace het_high_re_volume = 1 if ln_recent_volumn_10 > het_med_re_volume


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if ln_recent_volumn_10 < het_med_re_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_re_volume


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if ln_recent_volumn_10 > het_med_re_volume, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_re_volume


bdiff, group(het_high_re_volume) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260721) first
* 已经通过！

esttab low_re_volume high_re_volume using "heterogeneity_re_volume_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 4-1. Accumulated rating SD: construct group, high, low, then bdiff.
************************************************************

capture drop het_med_acc_sd
capture drop het_high_acc_sd
bysort City ym: egen double het_med_acc_sd = median(lag_sd_acc) if het_base_cc
gen byte het_high_acc_sd = .
replace het_high_acc_sd = 0 if lag_sd_acc < het_med_acc_sd
replace het_high_acc_sd = 1 if lag_sd_acc > het_med_acc_sd

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if lag_sd_acc < het_med_acc_sd, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_acc_sd

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if lag_sd_acc > het_med_acc_sd, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_acc_sd

bdiff, group(het_high_acc_sd) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5  ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260720) first
	
esttab low_acc_sd high_acc_sd using "heterogeneity_acc_sd_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 5. HotelOverStar: construct group, high, low, then bdiff.
************************************************************

* star_class is the completed actual 1.0--5.0 scale prepared above. Profile is
* the primary source; the original panel is retained only where profile is unavailable.
capture drop het_high_star

gen byte het_high_star = .
replace het_high_star = 0 if !missing(star_class) & star_class < 4
replace het_high_star = 1 if !missing(star_class) & star_class >= 4
tab star_class

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 ///
    if het_high_star == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_star

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 ///
    if het_high_star == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_star

bdiff, group(het_high_star) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_star high_star using "heterogeneity_star_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress
	
************************************************************
* 6. Chain affiliation: interaction, chain, non-chain, then bdiff.
************************************************************
replace chain = 1 if missing(chain)
* tab chain
tab chain

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_base_cc == 1 & chain == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store result_chain


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_base_cc == 1 & chain == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store result_indep

bdiff, group(chain) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260722) first
	
esttab result_chain result_indep using "heterogeneity_chain_0722.rtf", replace rtf ///
    order(sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress



************************************************************
* 7. Platform rank status
************************************************************

capture drop het_med_rank_status
capture drop het_high_rank_status

bysort City ym: egen double het_med_rank_status = median(hotel_rank_pct) if het_base_cc
gen het_high_rank_status = .
replace het_high_rank_status = 0 if hotel_rank_pct < het_med_rank_status
replace het_high_rank_status = 1 if hotel_rank_pct >= het_med_rank_status


reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if hotel_rank_pct < het_med_rank_status, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_rank_status

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if hotel_rank_pct >= het_med_rank_status, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_rank_status

bdiff, group(het_high_rank_status) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_rank_status high_rank_status using "heterogeneity_rank_status.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


************************************************************
* 8. City ym Amenity breadth
************************************************************

capture drop het_amenity_count
capture drop het_med_amenity_count
capture drop het_high_amenity_count

gen double het_amenity_count = ///
    strlen(hotel_amenities) - strlen(subinstr(hotel_amenities, ",", "", .)) + 1 ///
    if !missing(hotel_amenities)

bysort City ym: egen double het_med_amenity_count = median(het_amenity_count) if het_base_cc
gen het_high_amenity_count = .
replace het_high_amenity_count = 0 if het_amenity_count <= het_med_amenity_count
replace het_high_amenity_count = 1 if het_amenity_count > het_med_amenity_count

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_amenity_count == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_amenity_count

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_amenity_count == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_amenity_count

bdiff, group(het_high_amenity_count) ///
    model(reghdfe ln_RevPAR_clean_w595 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260722) first

esttab low_amenity_count high_amenity_count using "heterogeneity_amenity_count_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


	
************************************************************
* 9. Experience/design-oriented vs functional/value-oriented hotel style
************************************************************

capture drop het_high_experience_style

gen het_high_experience_style = .

* Low group: pure functional/value-oriented positioning.
replace het_high_experience_style = 0 ///
    if regexm(ustrlower(hotel_style), ///
    "budget|value|mid-range|centrally located") & ///
    !regexm(ustrlower(hotel_style), ///
    "modern|trendy|charming|luxury|romantic|city view|great view|river view|park view|lake view|harbor view")

* High group: pure experience/design-oriented positioning.
replace het_high_experience_style = 1 ///
    if regexm(ustrlower(hotel_style), ///
    "modern|trendy|charming|luxury|romantic|city view|great view|river view|park view|lake view|harbor view") & ///
    !regexm(ustrlower(hotel_style), ///
    "budget|value|mid-range|centrally located")

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_experience_style == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_experience_style

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_experience_style == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_experience_style

bdiff, group(het_high_experience_style) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_experience_style high_experience_style ///
    using "heterogeneity_experience_style.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


************************************************************
* 13. Travelers' Choice badge
************************************************************

capture drop het_high_travelers_choice

gen het_high_travelers_choice = .
replace het_high_travelers_choice = 0 ///
    if !missing(travelers_choice) & ///
    !regexm(ustrlower(travelers_choice), "travelers' choice|best of the best")
replace het_high_travelers_choice = 1 ///
    if !missing(travelers_choice) & ///
    regexm(ustrlower(travelers_choice), "travelers' choice|best of the best")
replace het_high_travelers_choice = 0 if missing(travelers_choice)

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_travelers_choice == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_travelers_choice

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_travelers_choice == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_travelers_choice

bdiff, group(het_high_travelers_choice) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_travelers_choice high_travelers_choice using "heterogeneity_travelers_choice.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


************************************************************
* 14. Scope-10 net-positive Bing sentiment
************************************************************

capture drop het_med_sent_net_pos_bing_10
capture drop het_high_sent_net_pos_bing_10

bysort City ym: egen double het_med_sent_net_pos_bing_10 = ///
    median(sent_net_pos_bing_10) if het_base_cc & sent_any_text_10 == 1
gen het_high_sent_net_pos_bing_10 = .
replace het_high_sent_net_pos_bing_10 = 0 ///
    if sent_net_pos_bing_10 < het_med_sent_net_pos_bing_10 & !missing(het_med_sent_net_pos_bing_10)
replace het_high_sent_net_pos_bing_10 = 1 ///
    if sent_net_pos_bing_10 >= het_med_sent_net_pos_bing_10 & !missing(het_med_sent_net_pos_bing_10)

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if sent_net_pos_bing_10 < het_med_sent_net_pos_bing_10, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_sent_net_pos_bing_10

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if sent_net_pos_bing_10 >= het_med_sent_net_pos_bing_10, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_sent_net_pos_bing_10

bdiff, group(het_high_sent_net_pos_bing_10) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_sent_net_pos_bing_10 high_sent_net_pos_bing_10 using "heterogeneity_sent_net_pos_bing_10.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


************************************************************
* 15-1. Lagged management reply rate
************************************************************

capture drop med_lag_mr_rate
capture drop g_hi_rate
bysort Zip ym: egen med_lag_mr_rate = median(lag_mr_rate)
generate g_hi_rate = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_rate) & lag_mr_rate > med_lag_mr_rate
replace g_hi_rate = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_rate) & lag_mr_rate < med_lag_mr_rate

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & g_hi_rate == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store low_mr_rate

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & g_hi_rate == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store high_mr_rate


bdiff, group(g_hi_rate) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_mr_rate high_mr_rate using "heterogeneity_mr_rate.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 15-2. Lagged Scope-10 management reply rate
* Conditional on at least one visible Scope-10 reply.
************************************************************

capture drop het_med_scope10_mr_rate
capture drop het_high_scope10_mr_rate

bysort Zip ym: egen double het_med_scope10_mr_rate = ///
    median(lag_scope10_mr_rate) ///
    if het_base_cc & lag_scope10_mr_reply_n > 0

gen het_high_scope10_mr_rate = .
replace het_high_scope10_mr_rate = 0 ///
    if het_base_cc & lag_scope10_mr_reply_n > 0 & ///
    lag_scope10_mr_rate < het_med_scope10_mr_rate
replace het_high_scope10_mr_rate = 1 ///
    if het_base_cc & lag_scope10_mr_reply_n > 0 & ///
    lag_scope10_mr_rate > het_med_scope10_mr_rate

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_scope10_mr_rate == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_scope10_mr_rate

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if het_high_scope10_mr_rate == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_scope10_mr_rate

bdiff, group(het_high_scope10_mr_rate) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_scope10_mr_rate high_scope10_mr_rate ///
    using "heterogeneity_scope10_mr_rate.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") ///
        fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 16-1. Average management response length
************************************************************
capture drop ln_lag_mr_words
capture drop ln_lag_mr_avg_words
gen double ln_lag_mr_words = ln(lag_mr_text_words + 1) if !missing(lag_mr_text_words)
gen double ln_lag_mr_avg_words = ln(lag_mr_avg_text_words + 1) if !missing(lag_mr_avg_text_words)

capture drop med_ln_lag_mr_words
capture drop g_hi_words
bysort Zip ym: egen med_ln_lag_mr_words = median(ln_lag_mr_words)
generate g_hi_words = 1 if cs_sample_focus100 == 1 & !missing(ln_lag_mr_words) & ln_lag_mr_words > med_ln_lag_mr_words
replace g_hi_words = 0 if cs_sample_focus100 == 1 & !missing(ln_lag_mr_words) & ln_lag_mr_words < med_ln_lag_mr_words

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & g_hi_words == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store low_mr_avg_words

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & g_hi_words == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store high_mr_avg_words

bdiff, group(g_hi_words) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260718) first

esttab low_mr_avg_words high_mr_avg_words using "heterogeneity_mr_avg_words.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 16-2. Lagged Scope-10 average management response length
* Conditional on a visible Scope-10 reply with nonempty text.
************************************************************

capture drop het_med_scope10_mr_avg_words
capture drop het_high_scope10_mr_avg_words

bysort Zip ym: egen double het_med_scope10_mr_avg_words = ///
    median(lag_scope10_mr_avg_text_words) ///
    if het_base_cc & lag_scope10_mr_text_reply_n > 0

gen het_high_scope10_mr_avg_words = .
replace het_high_scope10_mr_avg_words = 0 ///
    if het_base_cc & lag_scope10_mr_text_reply_n > 0 & ///
    lag_scope10_mr_avg_text_words < het_med_scope10_mr_avg_words
replace het_high_scope10_mr_avg_words = 1 ///
    if het_base_cc & lag_scope10_mr_text_reply_n > 0 & ///
    lag_scope10_mr_avg_text_words > het_med_scope10_mr_avg_words

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if het_high_scope10_mr_avg_words == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_scope10_mr_avg_words

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if het_high_scope10_mr_avg_words == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_scope10_mr_avg_words

bdiff, group(het_high_scope10_mr_avg_words) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_scope10_mr_avg_words high_scope10_mr_avg_words ///
    using "heterogeneity_scope10_mr_avg_words.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") ///
        fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 17. Quick management response share
************************************************************

capture drop med_lag_mr_quick30_share
capture drop g_hi_quick30
bysort Zip ym: egen med_lag_mr_quick30_share = median(lag_mr_quick30_share)
generate g_hi_quick30 = 1 if cs_sample_focus100 == 1 & !missing(lag_mr_quick30_share) & lag_mr_quick30_share > med_lag_mr_quick30_share
replace g_hi_quick30 = 0 if cs_sample_focus100 == 1 & !missing(lag_mr_quick30_share) & lag_mr_quick30_share < med_lag_mr_quick30_share

reghdfe ln_RevPAR_clean_w195 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & g_hi_quick30 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store quick30_low

reghdfe ln_RevPAR_clean_w195 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & g_hi_quick30 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store quick30_high

bdiff, group(g_hi_quick30) ///
    model(reghdfe ln_RevPAR_clean_w195 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260718) first

esttab quick30_low quick30_high using "heterogeneity_mr_quick30.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 17-2. Lagged Scope-10 quick management response share
* Conditional on a visible Scope-10 reply with valid response timing.
************************************************************

capture drop het_med_scope10_mr_quick30
capture drop het_high_scope10_mr_quick30

bysort Zip ym: egen double het_med_scope10_mr_quick30 = ///
    median(lag_scope10_mr_quick30_share) ///
    if het_base_cc & lag_scope10_mr_timing_n > 0

gen het_high_scope10_mr_quick30 = .
replace het_high_scope10_mr_quick30 = 0 ///
    if het_base_cc & lag_scope10_mr_timing_n > 0 & ///
    lag_scope10_mr_quick30_share < het_med_scope10_mr_quick30
replace het_high_scope10_mr_quick30 = 1 ///
    if het_base_cc & lag_scope10_mr_timing_n > 0 & ///
    lag_scope10_mr_quick30_share > het_med_scope10_mr_quick30

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_scope10_mr_quick30 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_scope10_mr_quick30

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_scope10_mr_quick30 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_scope10_mr_quick30

bdiff, group(het_high_scope10_mr_quick30) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_scope10_mr_quick30 high_scope10_mr_quick30 ///
    using "heterogeneity_scope10_mr_quick30.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") ///
        fmt(%12.0fc %9.3f)) ///
    label nogap compress
