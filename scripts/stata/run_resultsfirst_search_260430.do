*******************************************************
* run_resultsfirst_search_260430.do
* Results-first H1-H4 rebuild.
* Uses reghdfe, clustered SEs, esttab, and xtabond2.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/resultsfirst_260430"
local data_dir "`out_root'/data"
local csv_dir "`out_root'/csv"
local scan_dir "`out_root'/scans"
local table_dir "`out_root'/tables"
local log_dir "`out_root'/logs"
local run_id "260430"

cap mkdir "`out_root'"
cap mkdir "`data_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`scan_dir'"
cap mkdir "`table_dir'"
cap mkdir "`log_dir'"

local data_main "`data_dir'/resultsfirst_panel_`run_id'.dta"
local h1_selected_csv "`csv_dir'/h1_selected_`run_id'.csv"
local hetero_selected_csv "`csv_dir'/heterogeneity_selected_`run_id'.csv"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'. Run scripts/r/build_resultsfirst_panel_260430.R first."
    exit 601
}

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
    capture drop rf_covid2020 rf_covid2021 rf_covid2022
    gen byte rf_covid2020 = (Year == 2020)
    gen byte rf_covid2021 = (Year == 2021)
    gen byte rf_covid2022 = (Year == 2022)
end

program define set_rf_controls, rclass
    syntax, FAMILY(string)
    if "`family'" == "none" {
        return local controls ""
    }
    else if "`family'" == "lean2" {
        return local controls "ln_recent_volumn ln_avg_com_RevPAR"
    }
    else if "`family'" == "lean3" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc ln_avg_com_RevPAR"
    }
    else if "`family'" == "quality_no_lagy" {
        return local controls "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month ln_avg_com_RevPAR"
    }
    else if "`family'" == "rich_lagy" {
        return local controls "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
    }
    else if "`family'" == "rich_gmm" {
        return local controls "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR"
    }
    else {
        di as error "Unknown control family: `family'"
        exit 198
    }
end

program define set_rf_sample, rclass
    syntax, SAMPLE(string)
    if "`sample'" == "full" {
        return local condition "rf_sample_full == 1"
    }
    else if "`sample'" == "pre2020" {
        return local condition "rf_sample_pre2020 == 1"
    }
    else if "`sample'" == "exclude2020" {
        return local condition "rf_sample_exclude2020 == 1"
    }
    else if "`sample'" == "post2013" {
        return local condition "rf_sample_post2013 == 1"
    }
    else if "`sample'" == "focus50" {
        return local condition "rf_sample_focus50 == 1"
    }
    else if "`sample'" == "focus100" {
        return local condition "rf_sample_focus100 == 1"
    }
    else if "`sample'" == "star_observed" {
        return local condition "rf_sample_star_observed == 1"
    }
    else {
        di as error "Unknown sample: `sample'"
        exit 198
    }
end

program define run_rf_gmm
    syntax, DEP(string) XVAR(string) CTRL(string) SAMPLE(string) TIMEFE(string) DYN(string) ///
        YLAG1(integer) YLAG2(integer) XLAG1(integer) XLAG2(integer) [TRANSFORM(string) LOUD]

    set_rf_controls, family("`ctrl'")
    local rhs "`r(controls)'"
    set_rf_sample, sample("`sample'")
    local ifcond "`r(condition)'"

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
        local tf_rhs "rf_covid2020 rf_covid2021 rf_covid2022 i.Mon"
        local tf_iv "rf_covid2020 rf_covid2021 rf_covid2022 i.Mon"
    }
    else {
        error 198
    }

    local lag_rhs "L.`dep'"
    local gmm_y "L.`dep'"
    if "`dyn'" == "L12" {
        local lag_rhs "L.`dep' L2.`dep'"
        local gmm_y "L.`dep' L2.`dep'"
    }

    local transform_opt ""
    if "`transform'" == "orth" {
        local transform_opt "orthogonal"
    }

    local run_prefix "quietly"
    if "`loud'" != "" {
        local run_prefix "noisily"
    }

    `run_prefix' xtabond2 `dep' `lag_rhs' `xvar' `rhs' `tf_rhs' if `ifcond', ///
        gmm(`gmm_y', laglimits(`ylag1' `ylag2') collapse) ///
        gmm(`xvar', laglimits(`xlag1' `xlag2') collapse) ///
        iv(`rhs' `tf_iv') twostep robust small `transform_opt'
end

capture which reghdfe
if _rc {
    di as error "reghdfe not found. Install reghdfe first."
    exit 199
}
capture which esttab
if _rc {
    di as error "esttab not found. Install estout first."
    exit 199
}
capture which xtabond2
if _rc {
    di as error "xtabond2 not found. Install xtabond2 first."
    exit 199
}

tempfile rawdata h1sel heterosel gmmout

import delimited using "`h1_selected_csv'", clear varnames(1) stringcols(_all)
quietly levelsof sample in 1, local(h1_sample) clean
quietly levelsof dep_var in 1, local(h1_dep) clean
quietly levelsof sim_var in 1, local(h1_x) clean
quietly levelsof control_family in 1, local(h1_ctrl) clean
save `h1sel', replace

import delimited using "`hetero_selected_csv'", clear varnames(1) stringcols(_all)
foreach mod in h2_rating_last h2_rating_acc h3_volume_last h3_volume_acc h4_star {
    quietly levelsof dep_var if moderator == "`mod'", local(`mod'_dep) clean
    quietly levelsof sim_var if moderator == "`mod'", local(`mod'_x) clean
    quietly levelsof control_family if moderator == "`mod'", local(`mod'_ctrl) clean
}
save `heterosel', replace

use "`data_main'", clear
log using "`log_dir'/run_resultsfirst_search_`run_id'.log", text replace
build_panel_state
save `rawdata', replace

set_rf_controls, family("`h1_ctrl'")
local h1_controls "`r(controls)'"
set_rf_sample, sample("`h1_sample'")
local h1_if "`r(condition)'"

di as text "============================================================"
di as text "H1 OLS and two-way FE from R-selected results-first spec"
di as text "sample=`h1_sample' dep=`h1_dep' x=`h1_x' controls=`h1_ctrl'"
di as text "============================================================"

reg `h1_dep' `h1_x' `h1_controls' if `h1_if', vce(cluster hotel_id_num)
estimates store rf_h1_ols
reghdfe `h1_dep' `h1_x' `h1_controls' if `h1_if', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h1_fe

esttab rf_h1_ols rf_h1_fe using "`table_dir'/resultsfirst_h1_ols_fe_`run_id'.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("OLS" "2WFE") stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

di as text "============================================================"
di as text "H1 system-GMM results-first scan"
di as text "============================================================"

postutil clear
postfile hh str16 sample str16 dep str28 xvar str18 ctrl str8 timefe str4 dyn str5 transform str8 ylag str8 xlag ///
    double beta se p xsd std_effect ar1 ar2 hansen inst N hotels pass using `gmmout', replace

local gmm_samples "full pre2020 exclude2020 post2013 focus50"
local gmm_deps "`h1_dep' rf_y_clean"
local gmm_xvars "`h1_x' rf_sim rf_sim_lag rf_sim_w199 rf_sim_d rf_hhi rf_inv_entropy rf_sim_zh rf_hhi_zh rf_inv_entropy_zh rf_sim_dcym rf_inv_entropy_dcym"
local gmm_ctrls "lean2 lean3 quality_no_lagy rich_gmm"

foreach sample of local gmm_samples {
    foreach dep of local gmm_deps {
        foreach xvar of local gmm_xvars {
            foreach ctrl of local gmm_ctrls {
                foreach spec in month_L1_orth_5_8_6_7 month_L1_orth_5_8_4_5 yearmon_L12_plain_7_10_6_7 covidmon_L12_plain_7_10_6_7 {
                    local timefe "monthfe"
                    local dyn "L1"
                    local transform "orth"
                    local y1 5
                    local y2 8
                    local x1 6
                    local x2 7
                    if "`spec'" == "month_L1_orth_5_8_4_5" {
                        local x1 4
                        local x2 5
                    }
                    if "`spec'" == "yearmon_L12_plain_7_10_6_7" {
                        local timefe "yearmon"
                        local dyn "L12"
                        local transform "plain"
                        local y1 7
                        local y2 10
                        local x1 6
                        local x2 7
                    }
                    if "`spec'" == "covidmon_L12_plain_7_10_6_7" {
                        local timefe "covidmon"
                        local dyn "L12"
                        local transform "plain"
                        local y1 7
                        local y2 10
                        local x1 6
                        local x2 7
                    }

                    use `rawdata', clear
                    build_panel_state
                    set_rf_sample, sample("`sample'")
                    local ifcond "`r(condition)'"
                    quietly summarize `xvar' if `ifcond', meanonly
                    local xsd = r(sd)
                    capture noisily run_rf_gmm, dep(`dep') xvar(`xvar') ctrl(`ctrl') sample(`sample') timefe(`timefe') dyn(`dyn') ///
                        ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') transform(`transform')
                    if _rc == 0 {
                        local pv = 2 * normal(-abs(_b[`xvar'] / _se[`xvar']))
                        local std_eff = _b[`xvar'] * `xsd'
                        local ok = (_b[`xvar'] < 0 & `pv' < 0.05 & e(ar1p) < 0.05 & e(ar2p) > 0.10 & e(hansenp) >= 0.05 & e(hansenp) <= 0.90 & e(j) < e(N_g))
                        post hh ("`sample'") ("`dep'") ("`xvar'") ("`ctrl'") ("`timefe'") ("`dyn'") ("`transform'") ///
                            ("`y1'/`y2'") ("`x1'/`x2'") ///
                            (_b[`xvar']) (_se[`xvar']) (`pv') (`xsd') (`std_eff') ///
                            (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) (e(N_g)) (`ok')
                    }
                }
            }
        }
    }
}

postclose hh
use `gmmout', clear
gen abs_std_effect = abs(std_effect)
gen hansen_gap = cond(missing(hansen), 9e9, cond(hansen < 0.05, 0.05 - hansen, cond(hansen > 0.90, hansen - 0.90, 0)))
gen ar2_gap = cond(missing(ar2), 9e9, max(0, 0.1001 - ar2))
gsort -pass -abs_std_effect +hansen_gap +ar2_gap +p
export delimited using "`scan_dir'/resultsfirst_h1_gmm_scan_`run_id'.csv", replace
preserve
keep in 1/25
export delimited using "`table_dir'/resultsfirst_h1_gmm_top25_`run_id'.txt", replace
restore
preserve
keep in 1
export delimited using "`csv_dir'/gmm_selected_`run_id'.csv", replace
restore

quietly levelsof sample in 1, local(best_sample) clean
quietly levelsof dep in 1, local(best_dep) clean
quietly levelsof xvar in 1, local(best_x) clean
quietly levelsof ctrl in 1, local(best_ctrl) clean
quietly levelsof timefe in 1, local(best_timefe) clean
quietly levelsof dyn in 1, local(best_dyn) clean
quietly levelsof transform in 1, local(best_transform) clean
quietly levelsof ylag in 1, local(best_ylag) clean
quietly levelsof xlag in 1, local(best_xlag) clean

use `rawdata', clear
build_panel_state
di as text "Best GMM: sample=`best_sample' dep=`best_dep' x=`best_x' ctrl=`best_ctrl' timefe=`best_timefe' dyn=`best_dyn'"
gettoken y1 y2 : best_ylag, parse("/")
local y2 = subinstr("`y2'", "/", "", 1)
gettoken x1 x2 : best_xlag, parse("/")
local x2 = subinstr("`x2'", "/", "", 1)
noisily run_rf_gmm, dep(`best_dep') xvar(`best_x') ctrl(`best_ctrl') sample(`best_sample') timefe(`best_timefe') dyn(`best_dyn') ///
    ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') transform(`best_transform') loud
estimates store rf_h1_gmm

esttab rf_h1_ols rf_h1_fe rf_h1_gmm using "`table_dir'/resultsfirst_h1_models_`run_id'.txt", replace ///
    keep(`h1_x' `best_x' L.`best_dep') ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("OLS" "2WFE" "Sys-GMM") stats(N, fmt(%9.0f) labels("N"))

di as text "============================================================"
di as text "H2-H4 grouped FE from R-selected results-first specs"
di as text "============================================================"

use `rawdata', clear
build_panel_state

foreach mod in h2_rating_last h2_rating_acc h3_volume_last h3_volume_acc h4_star {
    local family_macro "`mod'_ctrl"
    set_rf_controls, family("``family_macro''")
    local `mod'_controls "`r(controls)'"
}

reghdfe `h2_rating_last_dep' `h2_rating_last_x' `h2_rating_last_controls' if rf_group_h2_rating_last == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h2last_low
reghdfe `h2_rating_last_dep' `h2_rating_last_x' `h2_rating_last_controls' if rf_group_h2_rating_last == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h2last_high

reghdfe `h2_rating_acc_dep' `h2_rating_acc_x' `h2_rating_acc_controls' if rf_group_h2_rating_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h2acc_low
reghdfe `h2_rating_acc_dep' `h2_rating_acc_x' `h2_rating_acc_controls' if rf_group_h2_rating_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h2acc_high

reghdfe `h3_volume_last_dep' `h3_volume_last_x' `h3_volume_last_controls' if rf_group_h3_volume_last == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h3last_low
reghdfe `h3_volume_last_dep' `h3_volume_last_x' `h3_volume_last_controls' if rf_group_h3_volume_last == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h3last_high

reghdfe `h3_volume_acc_dep' `h3_volume_acc_x' `h3_volume_acc_controls' if rf_group_h3_volume_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h3acc_low
reghdfe `h3_volume_acc_dep' `h3_volume_acc_x' `h3_volume_acc_controls' if rf_group_h3_volume_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h3acc_high

reghdfe `h4_star_dep' `h4_star_x' `h4_star_controls' if rf_group_h4_star == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h4_low
reghdfe `h4_star_dep' `h4_star_x' `h4_star_controls' if rf_group_h4_star == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store rf_h4_high

esttab rf_h2last_low rf_h2last_high rf_h2acc_low rf_h2acc_high rf_h3last_low rf_h3last_high rf_h3acc_low rf_h3acc_high rf_h4_low rf_h4_high ///
    using "`table_dir'/resultsfirst_h2_h4_grouped_fe_`run_id'.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("H2 last low" "H2 last high" "H2 acc low" "H2 acc high" "H3 last low" "H3 last high" "H3 acc low" "H3 acc high" "H4 low" "H4 high") ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

log close
