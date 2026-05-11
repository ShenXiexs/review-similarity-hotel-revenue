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


cap mkdir "`out_root'"

capture which winsor2
if _rc {
    ssc install winsor2, replace
}

capture drop ln_RevPAR_clean_w
gen ln_RevPAR_clean_w = ln_RevPAR_clean
winsor2 ln_RevPAR_clean_w if cs_sample_focus50 == 1, cut(2.5 97.5) replace

gen ln_lag_RevPAR_clean_w = ln_lag_RevPAR_clean
winsor2 ln_lag_RevPAR_clean_w if cs_sample_focus50 == 1, cut(2.5 97.5) replace


capture drop ln_RevPAR_clean_w199
gen ln_RevPAR_clean_w199 = ln_RevPAR_clean
winsor2 ln_RevPAR_clean_w199, cut(1 99) replace

gen ln_lag_RevPAR_clean_w199 = ln_lag_RevPAR_clean
winsor2 ln_lag_RevPAR_clean_w199, cut(1 99) replace

keep if cs_sample_focus100 == 1

*******************************************************
************ 2. H1 basic results: OLS and 2WFE ************
*******************************************************

estimates clear

************ H1 OLS: v100 with lagged RevPAR control ************
reg ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, vce(cluster hotel_id_num)
est store h1_ols_flag

************ H1 OLS: Full with lagged RevPAR control ************
reg ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, vce(cluster hotel_id_num)
est store h1_ols_lag

************ H1 2WFE: v100 with lagged RevPAR************
reghdfe ln_RevPAR_clean sim_mean rating_last_5 ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_flag

************ H1 2WFE: Full with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean rating_last_5 ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_lag


esttab h1_ols_flag h1_ols_lag h1_fe_flag h1_fe_lag ///
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
************ 3. H1 system-GMM: explicit diagnostic ************
*******************************************************

capture which bdiff
if _rc {
    di as error "bdiff not found. Install it first if needed: ssc install bdiff, replace"
    exit 199
}

************ 4. H1 Sys-GMM: pre-COVID strict diagnostic candidate ************
* Main RHS is kept fixed as requested. Only the instrument partition changes:
* - sim_mean and controls are treated as level-equation IV-style instruments.
* - lagged RevPAR is instrumented with a deep, collapsed GMM window.
* This avoids exact identification and gives a non-missing Hansen p-value.
* - 没找到有效的结果！！
xtabond2 ln_RevPAR_clean sim_mean rating_last_5 ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean i.ym  if cs_sample_focus100 == 1, gmm(ln_lag_RevPAR_clean_w, laglimits(1 5)) gmm(sim_mean, laglimits(2 3)) iv(rating_last_5 ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR i.ym, eq(level)) twostep robust
	
* Trial	
xtabond2 ln_RevPAR_clean sim_mean rating_last_5 ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean i.ym  if cs_sample_focus100 == 1, gmm(ln_lag_RevPAR_clean_w, laglimits(1 5)) iv(sim_mean rating_last_5 ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR i.ym, eq(level)) twostep robust small orthogonal
	
est store h1_sysgmm_precovid

** 尝试控制疫情

esttab h1_sysgmm_precovid using "h1_sysgmm_explicit_precovid_260501.rtf", replace keep(sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean) cells(b(star fmt(3)) se(par fmt(3))) order( ///
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
************ 5. H2-H4(H5) grouping variables ************
*******************************************************
** 如果想看
keep if cs_sample_focus100 == 1


*******************************************************
************ 5.1. H2 reputation heterogeneity ************
*******************************************************
** H2
* recent_rating
capture drop h2_med_recent_rating h2_low_recent_rating
bysort CityID ym: egen h2_med_recent_rating = median(recent_rating)
gen h2_low_recent_rating = .
replace h2_low_recent_rating = 1 if recent_rating < h2_med_recent_rating
replace h2_low_recent_rating = 0 if recent_rating > h2_med_recent_rating
************ H2.0 low reputation group ************
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_recent_rating == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_low
************ H2.0 high reputation group 
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_recent_rating == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_high
************ H2.0 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h2_low_recent_rating ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_interact
************ H2.0 bdiff 已经通过(全样本&最终累计大于100)
bdiff, group(h2_low_recent_rating) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202505) first detail

esttab h2_low h2_high h2_interact using "h2-0_explicit_bdiff_fe_260501.rtf", replace ///
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

* rating5
capture drop h2_med_rating5_ym h2_low_rating5_ym
bysort CityID ym: egen h2_med_rating5_ym = median(rating_last_5)
gen h2_low_rating5_ym = .
replace h2_low_rating5_ym = 1 if rating_last_5 <= h2_med_rating5_ym
replace h2_low_rating5_ym = 0 if rating_last_5 > h2_med_rating5_ym
************ H2.1 low reputation group ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_rating5_ym == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_low
************ H2.1 high reputation group 
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_rating5_ym == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_high
************ H2.1 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h2_low_rating5_ym ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_interact
************ H2.1 bdiff 已经通过(全样本&最终累计大于100)
bdiff, group(h2_low_rating5_ym) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202505) first detail

esttab h2_low h2_high h2_interact using "h2-1_explicit_bdiff_fe_260501.rtf", replace ///
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
	
* lag_avg_rating_acc
capture drop h2_med_lag_avg_rating_acc h2_low_lag_avg_rating_acc
bysort CityID ym: egen h2_med_lag_avg_rating_acc = median(lag_avg_rating_acc)
gen h2_low_lag_avg_rating_acc = .
replace h2_low_lag_avg_rating_acc = 1 if lag_avg_rating_acc <= h2_med_lag_avg_rating_acc
replace h2_low_lag_avg_rating_acc = 0 if lag_avg_rating_acc > h2_med_lag_avg_rating_acc
************ H2.2 low reputation group ************
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_lag_avg_rating_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_low
************ H2.2 high reputation group 
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_lag_avg_rating_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_high
************ H2.2 interaction model ************
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.h2_low_lag_avg_rating_acc ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_interact
************ H2.2 bdiff 不通过
bdiff, group(h2_low_lag_avg_rating_acc) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h2_low h2_high h2_interact using "h2-2_explicit_bdiff_fe_260501.rtf", replace ///
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

* lag_avg_rating_month
capture drop h2_med_lag_avg_rating_month h2_low_lag_avg_rating_month
bysort ym: egen h2_med_lag_avg_rating_month = median(lag_avg_rating_month)
gen h2_low_lag_avg_rating_month = .
replace h2_low_lag_avg_rating_month = 1 if lag_avg_rating_month <= h2_med_lag_avg_rating_month
replace h2_low_lag_avg_rating_month = 0 if lag_avg_rating_month > h2_med_lag_avg_rating_month
************ H2.3 low reputation group ************
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_lag_avg_rating_month == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_low
************ H2.3 high reputation group 
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h2_low_lag_avg_rating_month == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_high
************ H2.3 interaction model ************
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.h2_low_lag_avg_rating_month ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_interact
************ H2.3 bdiff 全样本基本通过
bdiff, group(h2_low_lag_avg_rating_month) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202501) first detail

esttab h2_low h2_high h2_interact using "h2-3_explicit_bdiff_fe_260501.rtf", replace ///
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
************ 5.2 H3 popularity heterogeneity ************
*******************************************************
** H3
* lag_recent_volumn
capture drop h3_med_lag_recent_volumn h3_low_lag_recent_volumn
bysort ym: egen h3_med_lag_recent_volumn = median(lag_recent_volumn)
gen h3_low_lag_recent_volumn = .
replace h3_low_lag_recent_volumn = 1 if lag_recent_volumn < h3_med_lag_recent_volumn
replace h3_low_lag_recent_volumn = 0 if lag_recent_volumn >= h3_med_lag_recent_volumn

************ H3.1 low popularity group ************
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h3_low_lag_recent_volumn == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_low
************ H3.1 high popularity group 
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h3_low_lag_recent_volumn == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_high
************ H3.1 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h3_low_lag_recent_volumn ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if !missing(h3_low_lag_recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_interact
************ H3.1 bdiff 基本通过
bdiff, group(h3_low_lag_recent_volumn) model(reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202506) first detail

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

* ln_lag_volumn_acc
capture drop h3_low_ln_lag_volumn_acc h3_med_ln_lag_volumn_acc
bysort CityID ym:egen h3_med_ln_lag_volumn_acc = median(ln_lag_volumn_acc)
gen h3_low_ln_lag_volumn_acc = .
replace h3_low_ln_lag_volumn_acc = 1 if ln_lag_volumn_acc < h3_med_ln_lag_volumn_acc
replace h3_low_ln_lag_volumn_acc = 0 if ln_lag_volumn_acc >= h3_med_ln_lag_volumn_acc
************ H3.2 low popularity group ************
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h3_low_ln_lag_volumn_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_low_2
************ H3.2 high popularity group 
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h3_low_ln_lag_volumn_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_high
************ H3.2 bdiff 全样本通过
bdiff, group(h3_low_ln_lag_volumn_acc) model(reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h3_low h3_high h3_interact using "h3-2_explicit_bdiff_fe_260501.rtf", replace ///
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


gen ln_lag_volumn_month = log(lag_volumn_month+1)
* ln_lag_volumn_month
capture drop h3_low_ln_lag_volumn_month h3_med_ln_lag_volumn_month
bysort CityID ym: egen h3_med_ln_lag_volumn_month = median(ln_lag_volumn_month)
gen h3_low_ln_lag_volumn_month = .
replace h3_low_ln_lag_volumn_month = 1 if ln_lag_volumn_month < h3_med_ln_lag_volumn_month
replace h3_low_ln_lag_volumn_month = 0 if ln_lag_volumn_month >= h3_med_ln_lag_volumn_month
************ H3.3 low popularity group ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h3_low_ln_lag_volumn_month == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_low_2
************ H3.3 high popularity group 
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h3_low_ln_lag_volumn_month == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_high
************ H3.3 bdiff 全样本通过
bdiff, group(h3_low_ln_lag_volumn_month) model(reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202505) first detail

esttab h3_low h3_high h3_interact using "h3-2_explicit_bdiff_fe_260501.rtf", replace ///
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
************ 5.3. H4 star-class heterogeneity ************
*******************************************************

** H4
* low_star4
capture drop h4_low_star4
gen h4_low_star4 = .
replace h4_low_star4 = 1 if star_class <= 4
replace h4_low_star4 = 0 if star_class > 4

************ H4 low-end group ************
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h4_low_star4 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_low

************ H4 high-end group ************
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h4_low_star4 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_high
************ H4 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h4_low_star4 ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
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
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H4 low-end" "H4 high-end" "H4 interaction") ///
    nogap compress



*******************************************************
************ 5.4. H5 recent_sd heterogeneity ************
*******************************************************
* low_lag_sd_mon
capture drop h5_med_lag_sd_mon h5_low_lag_sd_mon
bysort ym: egen h5_med_lag_sd_mon = median(lag_sd_mon)
gen h5_low_lag_sd_mon = .
replace h5_low_lag_sd_mon = 1 if lag_sd_mon < h5_med_lag_sd_mon
replace h5_low_lag_sd_mon = 0 if lag_sd_mon >= h5_med_lag_sd_mon
************ H5.1 low reputation group ************
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h5_low_lag_sd_mon == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_low
************ H5.1 high reputation group ************
reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h5_low_lag_sd_mon == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_high
************ H5.1 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h5_low_lag_sd_mon ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_interact
************ H5.1 bdiff ************
bdiff, group(h5_low_lag_sd_mon) model (reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h5_low h5_high h5_interact using "h5-0_explicit_bdiff_fe_260501.rtf", replace ///
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
    stats(N r2,labels("Observations" "R-squared")) ///
    mtitles("H5 low-end" "H5 high-end" "H5 interaction") ///
    nogap compress


* low_recent_sd
capture drop h5_med_recent_sd h5_low_recent_sd
bysort City ym: egen h5_med_recent_sd = median(recent_sd)
gen h5_low_recent_sd = .
replace h5_low_recent_sd = 1 if recent_sd <= h5_med_recent_sd
replace h5_low_recent_sd = 0 if recent_sd > h5_med_recent_sd
************ H5.1 low reputation group ************
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h5_low_recent_sd == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_low
************ H5.1 high reputation group ************
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h5_low_recent_sd == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_high
************ H5.1 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h5_low_lag_sd_acc ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_interact
************ H5.1 bdiff ************
bdiff, group(h5_low_recent_sd) model (reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(500) seed(202503) first detail

esttab h5_low h5_high h5_interact using "h5-1_explicit_bdiff_fe_260501.rtf", replace ///
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
    stats(N r2,labels("Observations" "R-squared")) ///
    mtitles("H5 low-end" "H5 high-end" "H5 interaction") ///
    nogap compress

* lag_sd_acc
capture drop h5_med_lag_sd_acc h5_low_lag_sd_acc
bysort CityID ym: egen h5_med_lag_sd_acc = median(lag_sd_acc)
gen h5_low_lag_sd_acc = .
replace h5_low_lag_sd_acc = 1 if lag_sd_acc < h5_med_lag_sd_acc
replace h5_low_lag_sd_acc = 0 if lag_sd_acc >= h5_med_lag_sd_acc
************ H5.2 low reputation group ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h5_low_lag_sd_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_low
************ H5.2 high reputation group ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if h5_low_lag_sd_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_high
************ H5.2 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h5_low_lag_sd_acc ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if !missing(h5_low_lag_sd_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h5_interact
************ H5.2 bdiff ************
bdiff, group(h5_low_lag_sd_acc) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(100) seed(202505) first detail

esttab h5_low h5_high h5_interact using "h5-2_explicit_bdiff_fe_260501.rtf", replace ///
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
    stats(N r2,labels("Observations" "R-squared")) ///
    mtitles("H5 low-end" "H5 high-end" "H5 interaction") ///
    nogap compress



	
*******************************************************
************ 6. COVID extension variables ************
*******************************************************

capture drop covid2020 covid2020_2022 post2020 pre_covid zip_num
gen byte covid2020 = (Year == 2020)
gen byte covid2020_2022 = inrange(Year, 2020, 2022)
gen byte post2020 = (Year >= 2020)
gen byte pre_covid = (Year <= 2019)


*******************************************************
************ 7. H1 COVID: 2WFE ************
*******************************************************

************ H1 2WFE: pre2020, with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w if covid2020_2022==0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_bf_2020


************ H1 COVID shock: 2020 only, level outcome ************
reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020 ///
ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_2020_level

************ H1 COVID pandemic: 2020-2022, level outcome ************
reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020_2022 ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_pandemic_level

************ H1 COVID pandemic: 2020-2022, growth outcome ************
reghdfe d_ln_RevPAR c.sim_mean##i.covid2020_2022 ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_pandemic_growth

esttab h1_fe_bf_2020 h1_covid_2020_level h1_covid_pandemic_level h1_covid_pandemic_growth using "covid_h1_interactions_260501.rtf", replace ///
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
************ 8. H1 alternative ARS robustness ************
*******************************************************

local data_altars "`data_dir'/core_simi_panel_260501_with_altars.dta"

capture confirm file "`data_altars'"
if _rc {
    di as text "Skipping alternative ARS robustness. Run scripts/r/build_alt_ars_260509.R first."
}
else {
    preserve
    use "`data_altars'", clear

    capture drop hotel_id_num
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

    estimates clear

keep if cs_sample_focus100 == 1

************ H1 robustness: lagged core ARS ************
reghdfe ln_RevPAR_clean lag_sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_lag_ars

************ H1 robustness: daily rolling ARS, latest 10 reviews ************
reghdfe ln_RevPAR_clean ars_roll_10 ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_roll_ars

************ H1 robustness: JS-distance ARS transformed to similarity ************
reghdfe ln_RevPAR_clean ars_jsd_sim ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean , absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_jsd_ars

esttab h1_lag_ars h1_roll_ars h1_jsd_ars using "h1_alt_ars_robustness_260501.rtf", replace ///
    order( ///
            lag_sim_mean ///
            ars_roll_10 ///
            ars_jsd_sim ///
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
    stats(N r2,labels("Observations" "R-squared")) ///
    mtitles("Lagged ARS" "Rolling ARS" "JSD ARS") ///
    nogap compress
	restore
}


*******************************************************
************ 9. H1 review-scope ARS robustness ************
*******************************************************

local data_scope "`data_dir'/core_simi_panel_260501_with_scope_ars.dta"

capture confirm file "`data_scope'"
if _rc {
    di as text "Skipping review-scope ARS robustness. Run scripts/r/build_scope_ars_260509.R first."
}
else {
    preserve
    use "`data_scope'", clear

    capture drop hotel_id_num
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

    estimates clear

************ H1 robustness: RRS scope 5 ************
reghdfe ln_RevPAR_clean sim_mean_5 ln_recent_volumn_5 recent_sd_5 rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_scope5

************ H1 robustness: RRS scope 10 ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_scope10

************ H1 robustness: RRS scope 15 ************
reghdfe ln_RevPAR_clean sim_mean_15 ln_recent_volumn_15 recent_sd_15 rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_scope15

************ H1 robustness: RRS scope 20 ************
reghdfe ln_RevPAR_clean sim_mean_20 ln_recent_volumn_20 recent_sd_20 rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_scope20

************ H1 robustness: RRS scope 30 ************
reghdfe ln_RevPAR_clean sim_mean_30 ln_recent_volumn_30 recent_sd_30 rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_scope30

esttab h1_scope5 h1_scope10 h1_scope15 h1_scope20 h1_scope30 using "h1_scope_ars_robustness_260501.rtf", replace ///
        order( ///
            sim_mean_5 ///
            sim_mean_10 ///
            sim_mean_15 ///
            sim_mean_20 ///
            sim_mean_30 ///
            ln_recent_volumn_5 ///
            ln_recent_volumn_10 ///
            ln_recent_volumn_15 ///
            ln_recent_volumn_20 ///
            ln_recent_volumn_30 ///
            recent_sd_5 ///
            recent_sd_10 ///
            recent_sd_15 ///
            recent_sd_20 ///
            recent_sd_30 ///
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
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("5" "10" "15" "20" "30") ///
        nogap compress
    restore
}


*******************************************************
************ 10. descriptive statistics tables ************
*******************************************************

* Table 3 covers all numeric variables used in this explicit do-file.
* Table 4 keeps the main continuous regression variables to avoid an unreadable dummy-heavy matrix.

capture label variable ln_RevPAR_clean "Log RevPAR"
capture label variable ln_RevPAR_clean_w "Winsorized log RevPAR"
capture label variable d_ln_RevPAR "Change in log RevPAR"
capture label variable sim_mean "ARS / review similarity"
capture label variable ln_recent_volumn "Log recent review volume"
capture label variable recent_volumn "Recent review volume"
capture label variable recent_sd "Recent rating dispersion"
capture label variable rating_last_5 "Recent rating, last 5 reviews"
capture label variable ln_lag_volumn_acc "Log lagged cumulative review volume"
capture label variable lag_volumn_acc "Lagged cumulative review volume"
capture label variable lag_recent_volumn "Lagged recent review volume"
capture label variable lag_avg_rating_acc "Lagged cumulative rating"
capture label variable lag_sd_acc "Lagged cumulative rating dispersion"
capture label variable lag_avg_rating_month "Lagged monthly rating"
capture label variable lag_rating_last_5 "Lagged recent rating, last 5 reviews"
capture label variable ln_avg_com_RevPAR "Log competitor RevPAR"
capture label variable ln_lag_RevPAR_clean "Log lagged RevPAR"
capture label variable ln_lag_RevPAR_clean_w "Winsorized log lagged RevPAR"
capture label variable star_class "Hotel star class"
capture label variable covid2020 "COVID shock: 2020"
capture label variable covid2020_2022 "COVID pandemic: 2020-2022"
capture label variable post2020 "Post-2020 period"
capture label variable pre_covid "Pre-COVID period"

local desc_candidates ln_RevPAR_clean ln_RevPAR_clean_w d_ln_RevPAR sim_mean ln_recent_volumn recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_volumn_acc lag_recent_volumn lag_avg_rating_acc lag_sd_acc lag_avg_rating_month lag_rating_last_5 ln_avg_com_RevPAR ln_lag_RevPAR_clean ln_lag_RevPAR_clean_w star_class h2_low_rating5_ym h2_low_lag_avg_rating_acc h2_low_lag_avg_rating_month h3_low_lag_recent_volumn h3_low_ln_lag_volumn_acc h4_low_star35 h4_low_star4 h5_low_recent_sd h5_low_lag_sd_acc covid2020 covid2020_2022 post2020 pre_covid cs_sample_full cs_sample_focus50 cs_sample_focus100 cs_sample_exclude2020 cs_sample_post2013

local desc_vars
foreach v of local desc_candidates {
    capture confirm numeric variable `v'
    if !_rc local desc_vars `desc_vars' `v'
}

estpost summarize `desc_vars' if cs_sample_focus100 == 1, detail
esttab using "table3_descriptive_statistics_allvars_260501.rtf", replace rtf cells("count(fmt(0)) mean(fmt(3)) sd(fmt(3)) min(fmt(3)) p50(fmt(3)) max(fmt(3))") label noobs nonumber nomtitle title("Table 3. Descriptive statistics of all variables used in regressions")

local corr_candidates ln_RevPAR_clean ln_RevPAR_clean_w d_ln_RevPAR sim_mean ln_recent_volumn recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_volumn_acc lag_recent_volumn lag_avg_rating_acc lag_sd_acc lag_avg_rating_month lag_rating_last_5 ln_avg_com_RevPAR ln_lag_RevPAR_clean ln_lag_RevPAR_clean_w star_class

local corr_vars
foreach v of local corr_candidates {
    capture confirm numeric variable `v'
    if !_rc local corr_vars `corr_vars' `v'
}

estpost correlate `corr_vars' if cs_sample_focus100 == 1, matrix
esttab using "table4_correlation_matrix_mainvars_260501.rtf", replace rtf cells("b(fmt(3))") unstack not noobs compress label nonumber nostar title("Table 4. Correlation matrix of main continuous variables")


*******************************************************
************ 11. close log ************
*******************************************************

log close

*******************************************************
* End of fully explicit do-file
*******************************************************
