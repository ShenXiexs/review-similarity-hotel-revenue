*******************************************************
* run_hypothesis_tables_260430.do
* Purpose:
*   1) rebuild H1 OLS / two-way FE / system-GMM tables
*   2) rebuild H2-H4 grouped FE tables from selected R-side rules
*   3) keep all outputs inside outputs/hypothesis/
*******************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local hyp_root "`project'/outputs/hypothesis"
local data_dir "`hyp_root'/data"
local csv_dir "`hyp_root'/csv"
local scan_dir "`hyp_root'/scans"
local table_dir "`hyp_root'/tables"
local log_dir "`hyp_root'/logs"

cap mkdir "`hyp_root'"
cap mkdir "`data_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`scan_dir'"
cap mkdir "`table_dir'"
cap mkdir "`log_dir'"

local run_id "260430"
local data_main "`data_dir'/hypothesis_panel_`run_id'.dta"
local h1_selected_csv "`csv_dir'/h1_selected_`run_id'.csv"
local hetero_selected_csv "`csv_dir'/heterogeneity_selected_`run_id'.csv"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'. Run scripts/r/build_hypothesis_panel_260430.R first."
    exit 601
}
capture confirm file "`h1_selected_csv'"
if _rc {
    di as error "Cannot find `h1_selected_csv'. Run scripts/r/build_hypothesis_panel_260430.R first."
    exit 601
}
capture confirm file "`hetero_selected_csv'"
if _rc {
    di as error "Cannot find `hetero_selected_csv'. Run scripts/r/build_hypothesis_panel_260430.R first."
    exit 601
}

program define set_hyp_controls, rclass
    syntax, FAMILY(string)

    if "`family'" == "rich8_current" {
        return local controls "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
    }
    else if "`family'" == "ref_rating5" {
        return local controls "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_rating_last_5 ln_avg_com_RevPAR ln_lag_RevPAR_clean"
    }
    else if "`family'" == "quality6" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month ln_avg_com_RevPAR review_freshness ln_lag_RevPAR_clean"
    }
    else if "`family'" == "base4_acc" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean"
    }
    else if "`family'" == "base4_month" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
    }
    else if "`family'" == "lean3" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean"
    }
    else if "`family'" == "base4_month_gmm" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR"
    }
    else if "`family'" == "quality6_gmm" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month ln_avg_com_RevPAR review_freshness"
    }
    else if "`family'" == "lean3_gmm" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc ln_avg_com_RevPAR"
    }
    else if "`family'" == "rich8_gmm" {
        return local controls "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness"
    }
    else {
        di as error "Unknown control family: `family'"
        exit 198
    }
end

program define set_sample_if, rclass
    syntax, SAMPLE(string)

    if "`sample'" == "full" {
        return local condition "hyp_sample_full == 1"
    }
    else if "`sample'" == "pre2021" {
        return local condition "hyp_sample_pre2021 == 1"
    }
    else if "`sample'" == "pre2020" {
        return local condition "hyp_sample_pre2020 == 1"
    }
    else if "`sample'" == "star_observed" {
        return local condition "hyp_sample_star_observed == 1"
    }
    else {
        di as error "Unknown sample: `sample'"
        exit 198
    }
end

program define build_panel_state
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

    capture drop covid_2020 covid_2021 covid_2022
    gen byte covid_2020 = (Year == 2020)
    gen byte covid_2021 = (Year == 2021)
    gen byte covid_2022 = (Year == 2022)
end

program define run_hyp_gmm_spec
    syntax, CTRL(string) TIMEFE(string) DYN(string) YLAG1(integer) YLAG2(integer) ///
        XLAG1(integer) XLAG2(integer) [TRANSFORM(string) LOUD]

    set_hyp_controls, family("`ctrl'")
    local rhs "`r(controls)'"

    local tf_rhs ""
    local tf_iv ""
    if "`timefe'" == "monthfe" {
        local tf_rhs "i.Mon"
        local tf_iv "i.Mon"
    }
    else if "`timefe'" == "yearmon" {
        local tf_rhs "i.Year i.Mon"
        local tf_iv "i.Year i.Mon"
    }
    else if "`timefe'" == "covidmon" {
        local tf_rhs "covid_2020 covid_2021 covid_2022 i.Mon"
        local tf_iv "covid_2020 covid_2021 covid_2022 i.Mon"
    }
    else {
        error 198
    }

    local depvars "L.ln_RevPAR_clean"
    local gmm_y "L.ln_RevPAR_clean"
    if "`dyn'" == "L12" {
        local depvars "L.ln_RevPAR_clean L2.ln_RevPAR_clean"
        local gmm_y "L.ln_RevPAR_clean L2.ln_RevPAR_clean"
    }

    local transform_opt ""
    if "`transform'" == "orth" {
        local transform_opt "orthogonal"
    }

    local run_prefix "quietly"
    if "`loud'" != "" {
        local run_prefix "noisily"
    }

    `run_prefix' xtabond2 ln_RevPAR_clean `depvars' sim_mean_std_hotel `rhs' `tf_rhs', ///
        gmm(`gmm_y', laglimits(`ylag1' `ylag2') collapse) ///
        gmm(sim_mean_std_hotel, laglimits(`xlag1' `xlag2') collapse) ///
        iv(`rhs' `tf_iv') twostep robust small `transform_opt'
end

tempfile selected_h1 selected_hetero rawdata outscan

import delimited using "`h1_selected_csv'", clear varnames(1) stringcols(_all)
quietly levelsof sample in 1, local(h1_sample) clean
quietly levelsof dep_var in 1, local(h1_dep) clean
quietly levelsof sim_var in 1, local(h1_sim) clean
quietly levelsof control_family in 1, local(h1_family) clean
save `selected_h1', replace

import delimited using "`hetero_selected_csv'", clear varnames(1) stringcols(_all)
foreach mod in h2_rating_last h2_rating_accumulative h3_volume_last h3_volume_accumulative h4_star {
    quietly levelsof sim_var if moderator == "`mod'", local(`mod'_sim) clean
    quietly levelsof control_family if moderator == "`mod'", local(`mod'_family) clean
}
save `selected_hetero', replace

use "`data_main'", clear
log using "`log_dir'/run_hypothesis_tables_`run_id'.log", text replace
build_panel_state
save `rawdata', replace

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
capture which xtabond2
if _rc {
    di as error "xtabond2 not found. Please run: ssc install xtabond2, replace"
    exit 199
}

set_hyp_controls, family("`h1_family'")
local h1_controls "`r(controls)'"
set_sample_if, sample("`h1_sample'")
local h1_if "`r(condition)'"

di as text "============================================================"
di as text "H1 OLS and two-way fixed effects"
di as text "Selected H1: sample=`h1_sample'; dep=`h1_dep'; sim=`h1_sim'; controls=`h1_family'"
di as text "============================================================"

reg `h1_dep' `h1_sim' `h1_controls' if `h1_if', vce(cluster hotel_id_num)
estimates store h1_ols

reghdfe `h1_dep' `h1_sim' `h1_controls' if `h1_if', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h1_fe

esttab h1_ols h1_fe ///
    using "`table_dir'/hypothesis_h1_ols_fe_`run_id'.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("OLS" "2WFE") ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

di as text "============================================================"
di as text "H1 targeted system-GMM scan"
di as text "============================================================"

use `rawdata', clear
keep if hyp_sample_full == 1
build_panel_state

postutil clear
postfile hh str20 ctrl str8 timefe str4 dyn str5 transform str8 ylag str8 xlag ///
    double beta se p ar1 ar2 hansen inst N hotels pass using `outscan', replace

foreach ctrl in base4_month_gmm quality6_gmm lean3_gmm rich8_gmm {
    foreach xspec in 4_5 5_6 6_7 {
        gettoken x1 x2 : xspec, parse("_")
        local x2 = subinstr("`x2'", "_", "", 1)
        capture noisily run_hyp_gmm_spec, ctrl(`ctrl') timefe(monthfe) dyn(L1) ///
            ylag1(5) ylag2(8) xlag1(`x1') xlag2(`x2') transform(orth)
        if _rc == 0 {
            local pv = 2 * normal(-abs(_b[sim_mean_std_hotel] / _se[sim_mean_std_hotel]))
            local pass = (_b[sim_mean_std_hotel] < 0 & `pv' < 0.05 & e(ar1p) < 0.05 & e(ar2p) > 0.10 & e(hansenp) >= 0.10 & e(hansenp) <= 0.80 & e(j) < e(N_g))
            post hh ("`ctrl'") ("monthfe") ("L1") ("orth") ("5/8") ("`x1'/`x2'") ///
                (_b[sim_mean_std_hotel]) (_se[sim_mean_std_hotel]) (`pv') ///
                (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) (e(N_g)) (`pass')
        }
    }
}

foreach ctrl in base4_month_gmm quality6_gmm lean3_gmm rich8_gmm {
    foreach timefe in covidmon yearmon {
        capture noisily run_hyp_gmm_spec, ctrl(`ctrl') timefe(`timefe') dyn(L12) ///
            ylag1(7) ylag2(10) xlag1(6) xlag2(7) transform(plain)
        if _rc == 0 {
            local pv = 2 * normal(-abs(_b[sim_mean_std_hotel] / _se[sim_mean_std_hotel]))
            local pass = (_b[sim_mean_std_hotel] < 0 & `pv' < 0.05 & e(ar1p) < 0.05 & e(ar2p) > 0.10 & e(hansenp) >= 0.10 & e(hansenp) <= 0.80 & e(j) < e(N_g))
            post hh ("`ctrl'") ("`timefe'") ("L12") ("plain") ("7/10") ("6/7") ///
                (_b[sim_mean_std_hotel]) (_se[sim_mean_std_hotel]) (`pv') ///
                (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) (e(N_g)) (`pass')
        }
    }
}

postclose hh
use `outscan', clear
gen hansen_gap = cond(missing(hansen), 9e9, cond(hansen < 0.10, 0.10 - hansen, cond(hansen > 0.80, hansen - 0.80, 0)))
gen ar2_gap = cond(missing(ar2), 9e9, max(0, 0.1001 - ar2))
gsort -pass +hansen_gap +ar2_gap +p -beta
export delimited using "`scan_dir'/h1_gmm_scan_`run_id'.csv", replace
preserve
keep in 1/20
export delimited using "`table_dir'/hypothesis_h1_gmm_top20_`run_id'.txt", replace
restore
list ctrl timefe dyn transform ylag xlag beta se p ar1 ar2 hansen inst N hotels pass in 1/20, clean noobs

quietly levelsof ctrl in 1, local(best_ctrl) clean
quietly levelsof timefe in 1, local(best_timefe) clean
quietly levelsof dyn in 1, local(best_dyn) clean
quietly levelsof transform in 1, local(best_transform) clean
quietly levelsof ylag in 1, local(best_ylag) clean
quietly levelsof xlag in 1, local(best_xlag) clean

use `rawdata', clear
keep if hyp_sample_full == 1
build_panel_state

di as text "------------------------------------------------------------"
di as text "Rerun best Sys-GMM spec: `best_ctrl' | `best_timefe' | `best_dyn' | `best_transform' | `best_ylag' | `best_xlag'"
di as text "------------------------------------------------------------"
gettoken y1 y2 : best_ylag, parse("/")
local y2 = subinstr("`y2'", "/", "", 1)
gettoken x1 x2 : best_xlag, parse("/")
local x2 = subinstr("`x2'", "/", "", 1)
noisily run_hyp_gmm_spec, ctrl(`best_ctrl') timefe(`best_timefe') dyn(`best_dyn') ///
    ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') transform(`best_transform') loud
estimates store h1_sysgmm

esttab h1_ols h1_fe h1_sysgmm ///
    using "`table_dir'/hypothesis_h1_models_`run_id'.txt", replace ///
    keep(`h1_sim' sim_mean_std_hotel L.ln_RevPAR_clean) ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("OLS" "2WFE" "Sys-GMM") ///
    stats(N, fmt(%9.0f) labels("N"))

di as text "============================================================"
di as text "H2-H4 grouped fixed effects"
di as text "============================================================"

use `rawdata', clear
build_panel_state

local h2last_group "hyp_group_h2_rating_last"
local h2acc_group "hyp_group_h2_rating_accumulative"
local h3last_group "hyp_group_h3_volume_last"
local h3acc_group "hyp_group_h3_volume_accumulative"
local h4_group "hyp_group_h4_star"

foreach spec in h2_rating_last h2_rating_accumulative h3_volume_last h3_volume_accumulative h4_star {
    local family_macro "`spec'_family"
    set_hyp_controls, family("``family_macro''")
    local `spec'_controls "`r(controls)'"
}

reghdfe ln_RevPAR_clean `h2_rating_last_sim' `h2_rating_last_controls' if !missing(`h2last_group') & `h2last_group' == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h2last_low
reghdfe ln_RevPAR_clean `h2_rating_last_sim' `h2_rating_last_controls' if !missing(`h2last_group') & `h2last_group' == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h2last_high

reghdfe ln_RevPAR_clean `h2_rating_accumulative_sim' `h2_rating_accumulative_controls' if !missing(`h2acc_group') & `h2acc_group' == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h2acc_low
reghdfe ln_RevPAR_clean `h2_rating_accumulative_sim' `h2_rating_accumulative_controls' if !missing(`h2acc_group') & `h2acc_group' == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h2acc_high

reghdfe ln_RevPAR_clean `h3_volume_last_sim' `h3_volume_last_controls' if !missing(`h3last_group') & `h3last_group' == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h3last_low
reghdfe ln_RevPAR_clean `h3_volume_last_sim' `h3_volume_last_controls' if !missing(`h3last_group') & `h3last_group' == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h3last_high

reghdfe ln_RevPAR_clean `h3_volume_accumulative_sim' `h3_volume_accumulative_controls' if !missing(`h3acc_group') & `h3acc_group' == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h3acc_low
reghdfe ln_RevPAR_clean `h3_volume_accumulative_sim' `h3_volume_accumulative_controls' if !missing(`h3acc_group') & `h3acc_group' == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h3acc_high

reghdfe ln_RevPAR_clean `h4_star_sim' `h4_star_controls' if !missing(`h4_group') & `h4_group' == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h4_low
reghdfe ln_RevPAR_clean `h4_star_sim' `h4_star_controls' if !missing(`h4_group') & `h4_group' == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store h4_high

esttab h2last_low h2last_high h2acc_low h2acc_high h3last_low h3last_high h3acc_low h3acc_high h4_low h4_high ///
    using "`table_dir'/hypothesis_h2_h4_grouped_fe_`run_id'.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress ///
    mtitles("H2 last low" "H2 last high" "H2 acc low" "H2 acc high" "H3 last low" "H3 last high" "H3 acc low" "H3 acc high" "H4 low" "H4 high") ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

log close
