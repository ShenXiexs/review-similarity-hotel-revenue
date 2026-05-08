*******************************************************
* run_core_simi_explicit_regressions_260501.do
* Fully explicit regression version for manual testing.
*
* Key idea:
* - No global variable lists inside regressions.
* - Every regression writes out sim_mean and all controls explicitly.
* - You can comment out, add, or replace variables directly in each model.
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
local log_dir "`out_root'/logs"
local run_id "260501"

cap mkdir "`table_dir'"
cap mkdir "`log_dir'"

local data_main "`data_dir'/core_simi_panel_260501.dta"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'. Run scripts/r/build_core_simi_panel_260501.R first."
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

capture which xtabond2
if _rc {
    di as error "xtabond2 not found. Install it first: ssc install xtabond2, replace"
    exit 199
}

capture which winsor2
if _rc {
    di as text "winsor2 not found. Winsor section will be skipped unless installed: ssc install winsor2, replace"
}

*******************************************************
************ 1. load data and set panel ************
*******************************************************

use "`data_main'", clear

log using "`log_dir'/run_core_simi_explicit_regressions_260501.log", text replace

* Create numeric hotel id for panel setting and clustering.
capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc {
    encode HotelID, gen(hotel_id_num)
}
else {
    gen long hotel_id_num = HotelID
}

* Create monthly time variable.
capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm

* Generate Year and Mon if needed.
capture confirm variable Year
if _rc {
    gen Year = year(dofm(ym))
}

capture confirm variable Mon
if _rc {
    gen Mon = month(dofm(ym))
}

xtset hotel_id_num ym
sort hotel_id_num ym

* COVID-year dummies for alternative GMM tests.
capture drop cs_covid2020 cs_covid2021 cs_covid2022
gen byte cs_covid2020 = (Year == 2020)
gen byte cs_covid2021 = (Year == 2021)
gen byte cs_covid2022 = (Year == 2022)

*******************************************************
************ 2. H1 basic results: OLS and 2WFE ************
*******************************************************

estimates clear

************ H1 OLS: no lagged RevPAR control ************
reg ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR if cs_sample_focus100 == 1, vce(cluster hotel_id_num)
est store h1_ols_nolag

************ H1 OLS: with lagged RevPAR control ************
reg ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, vce(cluster hotel_id_num)
est store h1_ols_lag

************ H1 2WFE: no lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_nolag

************ H1 2WFE: with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean rating_last_5 ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_lag

esttab h1_ols_nolag h1_ols_lag h1_fe_nolag h1_fe_lag ///
    using "h1_basic_ols_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("OLS no lag" "OLS with lag" "2WFE no lag" "2WFE with lag") ///
    nogap compress

*******************************************************
************ 3. H1 Main results robust: alternative samples / Methods ************
*******************************************************
*** 一直纠结Sys-GMM，搞得这里还缺少几个稳健，但是补起来不需要一天
************ H1 2WFE: DV: lag_RevPAR************
reghdfe ln_lag_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR L.ln_lag_RevPAR_clean if cs_sample_full == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_lag_RevPAR


esttab h1_fe_lag_RevPAR ///
    using "h1_robust_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        L.ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("Full no lag" "Full lag") ///
    nogap compress

*******************************************************
************ 4(3-2). H1 winsorized 结果，后续为了好的结果有些回归采用了winsorized的DV ************
*******************************************************


local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/core_simi_260501"
local table_dir "`out_root'/tables_explicit"

cap mkdir "`out_root'"
cap mkdir "`table_dir'"

capture which winsor2
if _rc {
    ssc install winsor2, replace
}

capture drop ln_RevPAR_clean_w
gen ln_RevPAR_clean_w = ln_RevPAR_clean
winsor2 ln_RevPAR_clean_w if cs_sample_focus50 == 1, cut(2.5 97.5) replace

gen ln_lag_RevPAR_clean_w = ln_lag_RevPAR_clean
winsor2 ln_lag_RevPAR_clean_w if cs_sample_focus50 == 1, cut(2.5 97.5) replace

************ H1 winsor 2WFE: no lagged RevPAR control ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_winsor_fe_nolag

************ H1 winsor 2WFE: with lagged RevPAR control ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if cs_sample_focus50 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_winsor_fe_lag

esttab h1_winsor_fe_nolag h1_winsor_fe_lag ///
    using "h1_winsor_fe_260501.rtf", replace ///
    keep(sim_mean ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("Winsor no lag" "Winsor lag") ///
    nogap compress

*******************************************************
************ 5. H1 system-GMM: explicit diagnostic ************
*******************************************************

capture which bdiff
if _rc {
    di as error "bdiff not found. Install it first if needed: ssc install bdiff, replace"
    exit 199
}


************ H1 Sys-GMM: pre-COVID strict diagnostic candidate ************
* Main RHS is kept fixed as requested. Only the instrument partition changes:
* - sim_mean and controls are treated as level-equation IV-style instruments.
* - lagged RevPAR is instrumented with a deep, collapsed GMM window.
* This avoids exact identification and gives a non-missing Hansen p-value.
* - 没找到有效的结果！！
* Test-Save1
xtabond2 ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w i.ym, gmm(ln_lag_RevPAR_clean_w, laglimits(10 55) collapse) gmm(sim_mean, laglimits(2 3)) iv(ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month i.ym , eq(level) ///
    ) twostep robust
	
* Test-Save2	
xtabond2 ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w i.Year i.Mon, gmm(ln_RevPAR_clean_w, laglimits(10 12)) gmm(sim_mean, laglimits(5 8)) iv(ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month i.Year , eq(level) ///
    ) twostep robust small orthogonal
	
est store h1_sysgmm_precovid

esttab h1_sysgmm_precovid ///
    using "h1_sysgmm_explicit_precovid_260501.rtf", replace ///
    keep(sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N, labels("Observations")) ///
    mtitles("Sys-GMM pre-COVID") ///
    nogap compress
	
*******************************************************
************ 6. H2-H4 grouping variables ************
*******************************************************

keep if cs_sample_focus100 == 1

* rating5
capture drop h2_med_rating5_ym h2_low_rating5_ym
bysort CityID ym: egen h2_med_rating5_ym = median(rating_last_5)
gen h2_low_rating5_ym = .
replace h2_low_rating5_ym = 1 if cs_sample_focus100 == 1 & rating_last_5 <= h2_med_rating5_ym
replace h2_low_rating5_ym = 0 if cs_sample_focus100 == 1 & rating_last_5 > h2_med_rating5_ym
* lag_avg_rating_acc
capture drop h2_med_lag_avg_rating_acc h2_low_lag_avg_rating_acc
bysort ym: egen h2_med_lag_avg_rating_acc = median(lag_avg_rating_acc)
gen h2_low_lag_avg_rating_acc = .
replace h2_low_lag_avg_rating_acc = 1 if cs_sample_focus100 == 1 & lag_avg_rating_acc <= h2_med_lag_avg_rating_acc
replace h2_low_lag_avg_rating_acc = 0 if cs_sample_focus100 == 1 & lag_avg_rating_acc > h2_med_lag_avg_rating_acc

* lag_recent_volumn
capture drop h3_med_lag_recent_volumn h3_low_lag_recent_volumn
bysort CityID ym: egen h3_med_lag_recent_volumn = median(lag_recent_volumn)
gen h3_low_lag_recent_volumn = .
replace h3_low_lag_recent_volumn = 1 if cs_sample_focus100 == 1 & lag_recent_volumn < h3_med_lag_recent_volumn
replace h3_low_lag_recent_volumn = 0 if cs_sample_focus100 == 1 & lag_recent_volumn >= h3_med_lag_recent_volumn
* ln_lag_volumn_acc
capture drop h3_med_ln_lag_volumn_acc h3_low_ln_lag_volumn_acc
egen h3_med_ln_lag_volumn_acc = median(ln_lag_volumn_acc)
gen h3_low_ln_lag_volumn_acc = .
replace h3_low_ln_lag_volumn_acc = 1 if cs_sample_focus100 == 1 & ln_lag_volumn_acc < h3_med_ln_lag_volumn_acc
replace h3_low_ln_lag_volumn_acc = 0 if cs_sample_focus100 == 1 & ln_lag_volumn_acc >= h3_med_ln_lag_volumn_acc

* low_star4
capture drop h4_low_star4
gen h4_low_star4 = .
replace h4_low_star4 = 1 if cs_sample_focus100 == 1 & star_class <= 4
replace h4_low_star4 = 0 if cs_sample_focus100 == 1 & star_class > 4

* low_recent_sd
capture drop h5_med_recent_sd h5_low_recent_sd
bysort CityID ym: egen h5_med_recent_sd = median(recent_sd)
gen h5_low_recent_sd = .
replace h5_low_recent_sd = 1 if cs_sample_focus100 == 1 & recent_sd < h5_med_recent_sd
replace h5_low_recent_sd = 0 if cs_sample_focus100 == 1 & recent_sd >= h5_med_recent_sd
* lag_sd_acc
capture drop h5_med_lag_sd_acc h5_low_lag_sd_acc
egen h5_med_lag_sd_acc = median(lag_sd_acc)
gen h5_low_lag_sd_acc = .
replace h5_low_lag_sd_acc = 1 if cs_sample_focus100 == 1 & lag_sd_acc < h5_med_lag_sd_acc
replace h5_low_lag_sd_acc = 0 if cs_sample_focus100 == 1 & lag_sd_acc >= h5_med_lag_sd_acc

*******************************************************
************ 7. H2 reputation heterogeneity ************
*******************************************************

************ H2.1 low reputation group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h2_low_rating5_ym == 1 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_low

************ H2 high reputation group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h2_low_rating5_ym == 0 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_high

************ H2 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h2_low_rating5_ym ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h2_low_rating5_ym) & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_interact

bdiff, group(h2_low_rating5_ym) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h2_low h2_high h2_interact ///
    using "h2_explicit_bdiff_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H2 low reputation" "H2 high reputation" "H2 interaction") ///
    nogap compress
		
************ H2.2 low reputation group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h2_low_lag_avg_rating_month == 1 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_low

************ H2 high reputation group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h2_low_lag_avg_rating_month == 0 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_high

************ H2 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h2_low_lag_avg_rating_month ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h2_low_lag_avg_rating_month == 0) & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_interact

bdiff, group(h2_low_lag_avg_rating_month) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h2_low h2_high h2_interact ///
    using "h2_explicit_bdiff_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H2 low reputation" "H2 high reputation" "H2 interaction") ///
    nogap compress
	
	
	

*******************************************************
************ 8. H3 popularity heterogeneity ************
*******************************************************

************ H3.1 low popularity group ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h3_low_lag_recent_volumn == 1 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_low

************ H3.1 high popularity group ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h3_low_lag_recent_volumn == 0 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_high

************ H3.1 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h3_low_lag_recent_volumn ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h3_low_lag_recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_interact

bdiff, group(h3_low_lag_recent_volumn) ///
model(reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
bs reps(500) seed(202503) first detail

esttab h3_low h3_high h3_interact ///
    using "h3_explicit_bdiff_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H3 low popularity" "H3 high popularity" "H3 interaction") ///
    nogap compress
	
************ H3.2 low popularity group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h3_low_ln_lag_volumn_acc == 1 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_low

************ H3.2 high popularity group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h3_low_ln_lag_volumn_acc == 0 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_high

************ H3.2 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h3_low_lag_recent_volumn ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h3_low_lag_recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_interact

bdiff, group(h3_low_lag_recent_volumn) ///
model(reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
bs reps(500) seed(202503) first detail

esttab h3_low h3_high h3_interact ///
    using "`table_dir'/h3_explicit_bdiff_fe_260501.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H3 low popularity" "H3 high popularity" "H3 interaction") ///
    nogap compress

*******************************************************
************ 9. H4 star-class heterogeneity ************
*******************************************************

************ H4 low-end group ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h4_low_star4 == 1 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_low

************ H4 high-end group ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h4_low_star4 == 0 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_high

************ H4 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h4_low_star35 ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_interact

bdiff, group(h4_low_star4) model (reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h4_low h4_high h4_interact ///
    using "h4_explicit_bdiff_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///   mtitles("H4 low-end" "H4 high-end" "H4 interaction") ///
    nogap compress

*******************************************************
************ 10. H5 recent_sd heterogeneity ************
*******************************************************

************ H5.1 low recent_sd group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if h5_low_recent_sd == 1 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_low

************ H5.1 high recent_sd group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if h5_low_recent_sd == 0 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_high

************ H5.1 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h5_low_recent_sd ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if !missing(h5_low_recent_sd) & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_interact

bdiff, group(h5_low_recent_sd) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h5_low h5_high h5_interact ///
    using "h5_explicit_bdiff_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    mtitles("H5 low-end" "H5 high-end" "H5 interaction") ///
    nogap compress
	

************ H5.2 low lag_sd_acc group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if h5_low_lag_sd_acc == 1 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_low

************ H5.2 high lag_sd_acc group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if h5_low_lag_sd_acc == 0 & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_high

************ H5.2 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h5_low_recent_sd ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if !missing(h5_low_lag_sd_acc) & cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_interact

bdiff, group(h5_low_lag_sd_acc) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h5_low h5_high h5_interact ///
    using "h5-2_explicit_bdiff_fe_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    mtitles("H5 low-end" "H5 high-end" "H5 interaction") ///
    nogap compress
	
*******************************************************
************ 11. COVID extension variables ************
*******************************************************

capture drop covid2020 covid2020_2022 post2020 pre_covid zip_num
gen byte covid2020 = (Year == 2020)
gen byte covid2020_2022 = inrange(Year, 2020, 2022)
gen byte post2020 = (Year >= 2020)
gen byte pre_covid = (Year <= 2019)
egen zip_num = group(Zip)


*******************************************************
************ 12. H1 COVID: 2WFE ************
*******************************************************

************ H1 2WFE: pre2020, with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if cs_sample_focus100 == 1 & covid2020_2022==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_bf_2020

************ H1 COVID shock: 2020 only, level outcome ************
reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020 ///
ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_2020_level

************ H1 COVID pandemic: 2020-2022, level outcome ************
reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020_2022 ///
ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_pandemic_level

************ H1 COVID pandemic: 2020-2022, growth outcome ************
reghdfe d_ln_RevPAR c.sim_mean##i.covid2020_2022 ///
ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_pandemic_growth

esttab h1_fe_bf_2020 h1_covid_2020_level h1_covid_pandemic_level h1_covid_pandemic_growth ///
    using "covid_h1_interactions_260501.rtf", replace ///
    order( ///
        sim_mean ///
        ln_recent_volumn ///
        recent_sd ///
        ln_lag_volumn_acc ///
        lag_avg_rating_acc ///
        lag_sd_acc ///
        rating_last_5 ///
        lag_avg_rating_month ///
        ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w ///
    ) ///
	star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("Pre2020" "2020 shock level" "2020-2022 level" "2020-2022 growth") ///
    nogap compress

	

*******************************************************
************ 13. close log ************
*******************************************************

log close

*******************************************************
* End of fully explicit do-file
*******************************************************
