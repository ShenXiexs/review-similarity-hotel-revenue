************************************************************
* Route A/B heterogeneity: interaction, high group, low group,
* and bdiff group-difference test for every moderator.
* Final deliverables only: one DTA and one RTF.
************************************************************

************************************************************
* 1. Load the prepared Route-A/Route-B analysis panel.
* The input DTA already contains profile fields, the final literal 1.0--5.0
* star scale, the common complete-case flag, and Scope-10 MR variables.
************************************************************


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
******method1*********
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


******method2*********
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
label variable lag_avg_rating_month"Recent rating"
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


reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.ln_recent_volumn_10 ///
    recent_sd_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
   , absorb(hotel_id_num ym) vce(cluster hotel_id_num)

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
    reps(500) seed(260722) first

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
* 10-1. Platform rank status
************************************************************

capture drop het_med_rank_status
capture drop het_high_rank_status

bysort City ym: egen double het_med_rank_status = median(hotel_rank_pct) if het_base_cc
gen het_high_rank_status = .
replace het_high_rank_status = 0 if hotel_rank_pct < het_med_rank_status
replace het_high_rank_status = 1 if hotel_rank_pct >= het_med_rank_status


reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 ///
    if hotel_rank_pct < het_med_rank_status, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_rank_status

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 ///
    if hotel_rank_pct >= het_med_rank_status, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_rank_status

bdiff, group(het_high_rank_status) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) first

esttab low_rank_status high_rank_status using "heterogeneity_rank_status_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

	
************************************************************
* 10-2. Travelers' Choice badge
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
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 ///
    if het_high_travelers_choice == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store low_travelers_choice

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 ///
    if het_high_travelers_choice == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store high_travelers_choice

bdiff, group(het_high_travelers_choice) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260722) first

esttab low_travelers_choice high_travelers_choice using "heterogeneity_travelers_choice_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


************************************************************
* 11. Scope-10 net-positive Bing sentiment
************************************************************

capture drop het_med_sent_net_pos_bing_10
capture drop het_high_sent_net_pos_bing_10

bysort City ym: egen double het_med_sent_net_pos_bing_10 = ///
    median(sent_net_pos_bing_10) if sent_any_text_10 == 1
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
    if sent_net_pos_bing_10 > het_med_sent_net_pos_bing_10, ///
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
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress


************************************************************
* 12. Management response rate
************************************************************

capture drop med_t14_response_rate
capture drop g_hi_rate

egen double med_t14_response_rate = ///
    median(t14_response_rate) if t14_common_cc == 1

gen byte g_hi_rate = .
replace g_hi_rate = 0 if t14_common_cc == 1 & ///
    t14_response_rate < med_t14_response_rate
replace g_hi_rate = 1 if t14_common_cc == 1 & ///
    t14_response_rate >= med_t14_response_rate

reghdfe ln_RevPAR_clean_w195 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 t14_response_rate ///
    if t14_common_cc == 1 & t14_high_response_rate == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store low_mr_rate

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if t14_common_cc == 1 & t14_high_response_rate == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store high_mr_rate

bdiff, group(t14_high_response_rate) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260718) first

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
* 13. Average management response length: group construction
************************************************************

capture drop med_t14_response_length
capture drop g_hi_words

egen double med_t14_response_length = ///
    median(t14_response_length) if t14_common_cc == 1

gen byte g_hi_words = .
replace g_hi_words = 0 if t14_common_cc == 1 & ///
    t14_response_length < med_t14_response_length
replace g_hi_words = 1 if t14_common_cc == 1 & ///
    t14_response_length >= med_t14_response_length

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 t14_response_rate ///
    if t14_common_cc == 1 & t14_high_response_length == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store low_mr_avg_words

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 t14_response_rate ///
    if t14_common_cc == 1 & t14_high_response_length == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store high_mr_avg_words

bdiff, group(t14_high_response_length) ///
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
* 14. Quick management response share
************************************************************

capture drop med_t14_response_speed
capture drop g_hi_quick30

egen double med_t14_response_speed = ///
    median(t14_response_speed) if t14_common_cc == 1

gen byte g_hi_quick30 = .
replace g_hi_quick30 = 0 if t14_common_cc == 1 & ///
    t14_response_speed < med_t14_response_speed
replace g_hi_quick30 = 1 if t14_common_cc == 1 & ///
    t14_response_speed >= med_t14_response_speed

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if t14_common_cc == 1 & t14_high_response_speed == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store quick30_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if t14_common_cc == 1 & t14_high_response_speed == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store quick30_high

bdiff, group(t14_high_response_speed) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260718) first

esttab quick30_low quick30_high using "heterogeneity_mr_quick30.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 15-1. ZIP full-market HHI
************************************************************

* gen double hhi_zip_full_pct = hhi_zip_full / 100
label variable hhi_zip_full_pct "HHI (percentage points)"

capture drop med_hhi_zip_full
capture drop g_hi_hhi_zip_full

egen double med_hhi_zip_full = median(hhi_zip_full_pct)

gen byte g_hi_hhi_zip_full = .
replace g_hi_hhi_zip_full = 0 if !missing(hhi_zip_full) & hhi_zip_full_pct < med_hhi_zip_full
replace g_hi_hhi_zip_full = 1 if !missing(hhi_zip_full) & hhi_zip_full_pct >= med_hhi_zip_full

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if g_hi_hhi_zip_full == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_zip_full_low

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if g_hi_hhi_zip_full == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_zip_full_high

bdiff, group(g_hi_hhi_zip_full) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260720) first

esttab hhi_zip_full_low hhi_zip_full_high using "heterogeneity_hhi_zip_full_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress
	

************************************************************
* 15-2. ZIP full-market HHI with HHI
************************************************************

* gen double hhi_zip_full_pct = hhi_zip_full / 100
label variable hhi_zip_full_pct "HHI (percentage points)"

capture drop med_hhi_zip_full
capture drop g_hi_hhi_zip_full

egen double med_hhi_zip_full = median(hhi_zip_full_pct)

gen byte g_hi_hhi_zip_full = .
replace g_hi_hhi_zip_full = 0 if !missing(hhi_zip_full) & hhi_zip_full_pct < med_hhi_zip_full
replace g_hi_hhi_zip_full = 1 if !missing(hhi_zip_full) & hhi_zip_full_pct >= med_hhi_zip_full

reghdfe ln_RevPAR_clean sim_mean hhi_zip_full_pct ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if g_hi_hhi_zip_full == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_zip_full_low

reghdfe ln_RevPAR_clean sim_mean hhi_zip_full_pct ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 hhi_zip_full ///
    if g_hi_hhi_zip_full == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_zip_full_high

bdiff, group(g_hi_hhi_zip_full) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260722) first

esttab hhi_zip_full_low hhi_zip_full_high using "heterogeneity_hhi_zip_withhhi_0722.rtf", replace rtf ///
    order(sim_mean hhi_zip_full_pct ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 15-3. Zip full-market HHI Inter
************************************************************	

reghdfe ln_RevPAR_clean c.sim_mean##c.hhi_zip_full_pct ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_zip_full_Inter

esttab hhi_zip_full_Inter using "heterogeneity_hhi_zip_inter_0722.rtf", replace rtf ///
    order(sim_mean hhi_zip_full_pct c.sim_mean#c.hhi_zip_full_pct ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

************************************************************
* 16-1. City full-market HHI
************************************************************

capture drop med_hhi_city_full
capture drop g_hi_hhi_city_full

egen double med_hhi_city_full = median(hhi_city_full)

gen byte g_hi_hhi_city_full = .
replace g_hi_hhi_city_full = 0 if !missing(hhi_city_full) & hhi_city_full < med_hhi_city_full
replace g_hi_hhi_city_full = 1 if !missing(hhi_city_full) & hhi_city_full >= med_hhi_city_full

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if g_hi_hhi_city_full == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_city_full_low

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if g_hi_hhi_city_full == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_city_full_high

bdiff, group(g_hi_hhi_city_full) ///
    model(reghdfe ln_RevPAR_clean sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260722) first

esttab hhi_city_full_low hhi_city_full_high using "heterogeneity_hhi_city_full_0722.rtf", replace rtf ///
    order(sim_mean ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress

	
************************************************************
* 16-2. City full-market HHI with HHI
************************************************************

gen double hhi_city_full_pct = hhi_city_full / 100
label variable hhi_city_full_pct "HHI (percentage points)"

capture drop med_hhi_city_full
capture drop g_hi_hhi_city_full

egen double med_hhi_city_full = median(hhi_city_full_pct)

gen byte g_hi_hhi_city_full = .
replace g_hi_hhi_city_full = 0 if !missing(hhi_city_full_pct) & hhi_city_full_pct < med_hhi_city_full
replace g_hi_hhi_city_full = 1 if !missing(hhi_city_full_pct) & hhi_city_full_pct >= med_hhi_city_full

reghdfe ln_RevPAR_clean sim_mean hhi_city_full_pct ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if g_hi_hhi_city_full == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_city_full_low

reghdfe ln_RevPAR_clean sim_mean hhi_city_full_pct ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if g_hi_hhi_city_full == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_city_full_high

bdiff, group(g_hi_hhi_city_full) ///
    model(reghdfe ln_RevPAR_clean sim_mean hhi_city_full_pct ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260722) first

esttab hhi_city_full_low hhi_city_full_high using "heterogeneity_hhi_city_full_0722.rtf", replace rtf ///
    order(sim_mean hhi_city_full_pct ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress
	
	
************************************************************
* 16-3. City full-market HHI Inter
************************************************************	

reghdfe ln_RevPAR_clean c.sim_mean##c.hhi_city_full_pct ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store hhi_city_full_Inter

esttab hhi_city_full_Inter using "heterogeneity_hhi_city_inter_0722.rtf", replace rtf ///
    order(sim_mean hhi_city_full_pct c.sim_mean#c.hhi_city_full_pct ///
        ln_recent_volumn_10 recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    label nogap compress
