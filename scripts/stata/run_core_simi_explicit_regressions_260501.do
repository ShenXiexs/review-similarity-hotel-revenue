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
reg ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR if cs_sample_focus100 == 1, vce(cluster hotel_id_num)
est store h1_ols_nolag

************ H1 OLS: with lagged RevPAR control ************
reg ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, vce(cluster hotel_id_num)
est store h1_ols_lag

************ H1 2WFE: no lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_nolag

************ H1 2WFE: with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_lag

esttab h1_ols_nolag h1_ols_lag h1_fe_nolag h1_fe_lag ///
    using "`table_dir'/h1_basic_ols_fe_260501.rtf", replace ///
    keep(sim_mean ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("OLS no lag" "OLS with lag" "2WFE no lag" "2WFE with lag") ///
    nogap compress

*******************************************************
************ 3. H1 basic results: alternative samples ************
*******************************************************

************ H1 2WFE: full sample, no lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR if cs_sample_full == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_full_nolag

************ H1 2WFE: full sample, with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_full == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_full_lag

************ H1 2WFE: exclude 2020, no lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ///
    if cs_sample_exclude2020 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_excl2020_nolag

************ H1 2WFE: exclude 2020, with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_exclude2020 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_excl2020_lag

************ H1 2WFE: post 2013, no lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ///
    if cs_sample_post2013 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_post2013_nolag

************ H1 2WFE: post 2013, with lagged RevPAR control ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_post2013 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_fe_post2013_lag


esttab h1_fe_full_nolag h1_fe_full_lag h1_fe_excl2020_nolag h1_fe_excl2020_lag ///
       h1_fe_post2013_nolag h1_fe_post2013_lag ///
    using "`table_dir'/h1_alternative_samples_fe_260501.rtf", replace ///
    keep(sim_mean ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("Full no lag" "Full lag" "Excl2020 no lag" "Excl2020 lag" "Post2013 no lag" "Post2013 lag" "Focus100 no lag" "Focus100 lag") ///
    nogap compress

*******************************************************
************ 4. H1 winsorized dependent variable ************
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

************ H1 winsor 2WFE: no lagged RevPAR control ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_winsor_fe_nolag

************ H1 winsor 2WFE: with lagged RevPAR control ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus50 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_winsor_fe_lag

esttab h1_winsor_fe_nolag h1_winsor_fe_lag ///
    using "`table_dir'/h1_winsor_fe_260501.rtf", replace ///
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

capture drop ln_RevPAR_clean_w
gen ln_RevPAR_clean_w = ln_RevPAR_clean
winsor2 ln_RevPAR_clean_w if cs_sample_focus100 == 1, cut(1 99) replace

************ H1 Sys-GMM: pre-COVID strict diagnostic candidate ************
* Main RHS is kept fixed as requested. Only the instrument partition changes:
* - sim_mean and controls are treated as level-equation IV-style instruments.
* - lagged RevPAR is instrumented with a deep, collapsed GMM window.
* This avoids exact identification and gives a non-missing Hansen p-value.
xtabond2 ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean i.ym ///
    if cs_sample_focus100 == 1 & Year <= 2019, ///
    iv(i.ym, eq(level)) ///
    iv(sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc ///
       lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ///
       ln_avg_com_RevPAR ln_lag_RevPAR_clean, eq(level)) ///
    gmm(ln_lag_RevPAR_clean, lag(10 55) collapse eq(diff)) ///
    h(2) ar(2) cluster(hotel_id_num) twostep robust small orthogonal
est store h1_sysgmm_precovid

esttab h1_sysgmm_precovid ///
    using "`table_dir'/h1_sysgmm_explicit_precovid_260501.rtf", replace ///
    keep(sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N, labels("Observations")) ///
    mtitles("Sys-GMM pre-COVID") ///
    nogap compress

*******************************************************
************ 6. H2-H4 grouping variables ************
*******************************************************

capture drop h2_med_rating5_ym h2_low_rating5_ym
bysort ym: egen h2_med_rating5_ym = median(rating_last_5)
gen h2_low_rating5_ym = .
replace h2_low_rating5_ym = 1 if cs_sample_focus100 == 1 & rating_last_5 < h2_med_rating5_ym
replace h2_low_rating5_ym = 0 if cs_sample_focus100 == 1 & rating_last_5 >= h2_med_rating5_ym

capture drop h3_med_lag_recent_volumn h3_low_lag_recent_volumn
egen h3_med_lag_recent_volumn = median(lag_recent_volumn)
gen h3_low_lag_recent_volumn = .
replace h3_low_lag_recent_volumn = 1 if cs_sample_focus100 == 1 & lag_recent_volumn < h3_med_lag_recent_volumn
replace h3_low_lag_recent_volumn = 0 if cs_sample_focus100 == 1 & lag_recent_volumn >= h3_med_lag_recent_volumn

capture drop h4_low_star35
gen h4_low_star35 = .
replace h4_low_star35 = 1 if cs_sample_focus100 == 1 & Year <= 2019 & star_class <= 3.5
replace h4_low_star35 = 0 if cs_sample_focus100 == 1 & Year <= 2019 & star_class > 3.5

*******************************************************
************ 7. H2 reputation heterogeneity ************
*******************************************************

************ H2 low reputation group ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h2_low_rating5_ym == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_low

************ H2 high reputation group ************
reghdfe ln_RevPAR_clean_w sim_mean ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h2_low_rating5_ym == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_high

************ H2 interaction model ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h2_low_rating5_ym ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h2_low_rating5_ym), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h2_interact

bdiff, group(h2_low_rating5_ym) model (reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

esttab h2_low h2_high h2_interact ///
    using "`table_dir'/h2_explicit_bdiff_fe_260501.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H2 low reputation" "H2 high reputation" "H2 interaction") ///
    nogap compress

*******************************************************
************ 8. H3 popularity heterogeneity ************
*******************************************************

************ H3 low popularity group ************
reghdfe d_ln_RevPAR sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h3_low_lag_recent_volumn == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_low

************ H3 high popularity group ************
reghdfe d_ln_RevPAR sim_mean ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h3_low_lag_recent_volumn == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_high

************ H3 interaction model ************
reghdfe d_ln_RevPAR c.sim_mean##i.h3_low_lag_recent_volumn ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h3_low_lag_recent_volumn), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h3_interact

bdiff, group(h3_low_lag_recent_volumn) model (reghdfe d_ln_RevPAR sim_mean ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

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
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h4_low_star35 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_low

************ H4 high-end group ************
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if h4_low_star35 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_high

************ H4 interaction model ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h4_low_star35 ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h4_low_star35), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h4_interact

bdiff, group(h4_low_star35) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

esttab h4_low h4_high h4_interact ///
    using "`table_dir'/h4_explicit_bdiff_fe_260501.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H4 low-end" "H4 high-end" "H4 interaction") ///
    nogap compress

*******************************************************
************ 10. H2-H4 combined explicit tables ************
*******************************************************

esttab h2_low h2_high h3_low h3_high h4_low h4_high ///
    using "`table_dir'/h2_h4_grouped_explicit_bdiff_260501.rtf", replace ///
    keep(sim_mean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H2 low" "H2 high" "H3 low" "H3 high" "H4 low" "H4 high") ///
    nogap compress

esttab h2_interact h3_interact h4_interact ///
    using "`table_dir'/h2_h4_interactions_explicit_bdiff_260501.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H2 interaction" "H3 interaction" "H4 interaction") ///
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

capture drop h2_covid_med_zipym h2_covid_lowrep
bysort zip_num ym: egen h2_covid_med_zipym = median(lag_rating_last_5)
gen h2_covid_lowrep = .
replace h2_covid_lowrep = 1 if cs_sample_focus100 == 1 & lag_rating_last_5 < h2_covid_med_zipym
replace h2_covid_lowrep = 0 if cs_sample_focus100 == 1 & lag_rating_last_5 >= h2_covid_med_zipym

capture drop h3_covid_med_all h3_covid_lowpop
egen h3_covid_med_all = median(lag_recent_volumn)
gen h3_covid_lowpop = .
replace h3_covid_lowpop = 1 if cs_sample_focus100 == 1 & lag_recent_volumn < h3_covid_med_all
replace h3_covid_lowpop = 0 if cs_sample_focus100 == 1 & lag_recent_volumn >= h3_covid_med_all

capture drop h4_covid_lowstar3
gen h4_covid_lowstar3 = .
replace h4_covid_lowstar3 = 1 if cs_sample_focus100 == 1 & star_class <= 3
replace h4_covid_lowstar3 = 0 if cs_sample_focus100 == 1 & star_class > 3

capture drop h2_pre h2_shock h2_pandemic h3_pre h3_shock h3_pandemic h4_pre h4_shock h4_pandemic
gen h2_pre = h2_covid_lowrep if Year <= 2019
gen h2_shock = h2_covid_lowrep if Year == 2020
gen h2_pandemic = h2_covid_lowrep if inrange(Year, 2020, 2022)
gen h3_pre = h3_covid_lowpop if Year <= 2019
gen h3_shock = h3_covid_lowpop if Year == 2020
gen h3_pandemic = h3_covid_lowpop if inrange(Year, 2020, 2022)
gen h4_pre = h4_covid_lowstar3 if Year <= 2019
gen h4_shock = h4_covid_lowstar3 if Year == 2020
gen h4_pandemic = h4_covid_lowstar3 if inrange(Year, 2020, 2022)

*******************************************************
************ 12. H1 COVID extension: 2WFE ************
*******************************************************

************ H1 COVID shock: 2020 only, level outcome ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.covid2020 ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_2020_level

************ H1 COVID pandemic: 2020-2022, level outcome ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.covid2020_2022 ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_pandemic_level

************ H1 COVID pandemic: 2020-2022, growth outcome ************
reghdfe d_ln_RevPAR c.sim_mean##i.covid2020_2022 ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store h1_covid_pandemic_growth

esttab h1_covid_2020_level h1_covid_pandemic_level h1_covid_pandemic_growth ///
    using "`table_dir'/covid_h1_interactions_260501.rtf", replace ///
    keep(sim_mean 1.covid2020#c.sim_mean 1.covid2020_2022#c.sim_mean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("2020 shock level" "2020-2022 level" "2020-2022 growth") ///
    nogap compress

*******************************************************
************ 13. COVID extension: H2-H4 triple interactions ************
*******************************************************

************ H2 reputation x COVID pandemic ************
reghdfe ln_RevPAR_clean_w c.sim_mean##i.h2_covid_lowrep##i.covid2020_2022 ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h2_covid_lowrep), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store covid_h2_triple

************ H3 popularity x COVID pandemic ************
reghdfe d_ln_RevPAR c.sim_mean##i.h3_covid_lowpop##i.covid2020_2022 ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h3_covid_lowpop), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store covid_h3_triple

************ H4 star class x COVID pandemic ************
reghdfe ln_RevPAR_clean c.sim_mean##i.h4_covid_lowstar3##i.covid2020_2022 ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if !missing(h4_covid_lowstar3), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store covid_h4_triple

esttab covid_h2_triple covid_h3_triple covid_h4_triple ///
    using "`table_dir'/covid_h2_h4_triple_interactions_260501.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("H2 reputation" "H3 popularity" "H4 star class") ///
    nogap compress

*******************************************************
************ 14. COVID extension: period bdiff tests ************
*******************************************************

di as text "COVID BDIFF H2 pre-COVID: low reputation is group 1"
bdiff, group(h2_pre) model (reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H2 2020 shock: low reputation is group 1"
bdiff, group(h2_shock) model (reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H2 2020-2022 pandemic: low reputation is group 1"
bdiff, group(h2_pandemic) model (reghdfe ln_RevPAR_clean_w sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H3 pre-COVID: low popularity is group 1"
bdiff, group(h3_pre) model (reghdfe d_ln_RevPAR sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H3 2020 shock: low popularity is group 1"
bdiff, group(h3_shock) model (reghdfe d_ln_RevPAR sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H3 2020-2022 pandemic: low popularity is group 1"
bdiff, group(h3_pandemic) model (reghdfe d_ln_RevPAR sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H4 pre-COVID: low star is group 1"
bdiff, group(h4_pre) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H4 2020 shock: low star is group 1"
bdiff, group(h4_shock) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

di as text "COVID BDIFF H4 2020-2022 pandemic: low star is group 1"
bdiff, group(h4_pandemic) model (reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean, absorb(hotel_id_num ym) cluster(hotel_id_num)) bs reps(1000) seed(202503) first detail

*******************************************************
************ 15. close log ************
*******************************************************

log close

*******************************************************
* End of fully explicit do-file
*******************************************************
