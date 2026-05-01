*******************************************************
* run_core_simi_tables_260501.do
* Core-simi H1-H4 rebuild.
* H1-H4 main similarity variable is always sim_mean.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/core_simi_260501"
local data_dir "`out_root'/data"
local csv_dir "`out_root'/csv"
local scan_dir "`out_root'/scans"
local table_dir "`out_root'/tables"
local log_dir "`out_root'/logs"
local run_id "260501"

cap mkdir "`out_root'"
cap mkdir "`data_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`scan_dir'"
cap mkdir "`table_dir'"
cap mkdir "`log_dir'"

local data_main "`data_dir'/core_simi_panel_`run_id'.dta"
local gmm_candidates_csv "`csv_dir'/h1_gmm_candidates_`run_id'.csv"
local hetero_selected_csv "`csv_dir'/heterogeneity_selected_`run_id'.csv"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'. Run scripts/r/build_core_simi_panel_260501.R first."
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
    capture drop cs_covid2020 cs_covid2021 cs_covid2022
    gen byte cs_covid2020 = (Year == 2020)
    gen byte cs_covid2021 = (Year == 2021)
    gen byte cs_covid2022 = (Year == 2022)
end

program define set_cs_controls, rclass
    syntax, FAMILY(string)
    if "`family'" == "rich8_current" {
        return local controls "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
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
    else if "`family'" == "momentum_plus" {
        return local controls "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR rating_momentum volume_momentum review_freshness ln_lag_RevPAR_clean"
    }
    else {
        di as error "Unknown control family: `family'"
        exit 198
    }
end

program define set_cs_sample, rclass
    syntax, SAMPLE(string)
    if "`sample'" == "full" {
        return local condition "cs_sample_full == 1"
    }
    else if "`sample'" == "pre2020" {
        return local condition "cs_sample_pre2020 == 1"
    }
    else if "`sample'" == "exclude2020" {
        return local condition "cs_sample_exclude2020 == 1"
    }
    else if "`sample'" == "post2013" {
        return local condition "cs_sample_post2013 == 1"
    }
    else if "`sample'" == "post2013_excl2020" {
        return local condition "cs_sample_post2013_excl2020 == 1"
    }
    else if "`sample'" == "focus50" {
        return local condition "cs_sample_focus50 == 1"
    }
    else if "`sample'" == "focus100" {
        return local condition "cs_sample_focus100 == 1"
    }
    else if "`sample'" == "star_observed" {
        return local condition "cs_sample_star_observed == 1"
    }
    else {
        di as error "Unknown sample: `sample'"
        exit 198
    }
end

program define run_cs_gmm
    syntax, DEP(string) CTRL(string) SAMPLE(string) TIMEFE(string) DYN(string) ///
        YLAG1(integer) YLAG2(integer) XLAG1(integer) XLAG2(integer) XSTYLE(string) [TRANSFORM(string) LOUD]

    set_cs_controls, family("`ctrl'")
    local rhs "`r(controls)'"
    set_cs_sample, sample("`sample'")
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
        local tf_rhs "cs_covid2020 cs_covid2021 cs_covid2022 i.Mon"
        local tf_iv "cs_covid2020 cs_covid2021 cs_covid2022 i.Mon"
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

    local x_gmm ""
    local x_iv "`rhs' `tf_iv'"
    if "`xstyle'" == "gmm" {
        local x_gmm "gmm(sim_mean, laglimits(`xlag1' `xlag2') collapse)"
    }
    else if "`xstyle'" == "iv" {
        local x_iv "sim_mean `rhs' `tf_iv'"
    }
    else {
        error 198
    }

    `run_prefix' xtabond2 `dep' `lag_rhs' sim_mean `rhs' `tf_rhs' if `ifcond', ///
        gmm(`gmm_y', laglimits(`ylag1' `ylag2') collapse) ///
        `x_gmm' ///
        iv(`x_iv') twostep robust small `transform_opt'
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

tempfile rawdata cand heterosel gmmout h1final

use "`data_main'", clear
log using "`log_dir'/run_core_simi_tables_`run_id'.log", text replace
build_panel_state
save `rawdata', replace

import delimited using "`gmm_candidates_csv'", clear varnames(1) stringcols(_all)
gen long cand_id = _n
save `cand', replace

di as text "============================================================"
di as text "Core-simi H1 system-GMM scan: sim_mean only"
di as text "============================================================"

postutil clear
postfile gg str16 sample str24 dep str18 ctrl str8 timefe str4 dyn str5 transform str5 xstyle str8 ylag str8 xlag ///
    double beta se p sim_sd std_effect ar1 ar2 hansen inst N hotels pass using `gmmout', replace

quietly count
local n_cand = r(N)
forvalues k = 1/`n_cand' {
    use `cand', clear
    local sample "`=sample[`k']'"
    local dep "`=dep_var[`k']'"
    local ctrl "`=control_family[`k']'"

    foreach xstyle in gmm iv {
    foreach spec in month_L1_orth_4_7_3_5 month_L1_orth_5_8_4_5 month_L1_orth_5_8_6_7 month_L1_orth_6_10_4_6 month_L1_orth_7_11_5_8 month_L1_plain_4_7_3_5 month_L1_plain_5_8_4_5 yearmon_L1_plain_5_8_4_5 yearmon_L1_orth_5_8_4_5 month_L12_plain_5_8_4_5 month_L12_orth_5_8_4_5 yearmon_L12_plain_7_10_6_7 covidmon_L12_plain_7_10_6_7 {
        local timefe "monthfe"
        local dyn "L1"
        local transform "orth"
        local y1 4
        local y2 7
        local x1 3
        local x2 5
        if "`spec'" == "month_L1_orth_5_8_4_5" {
            local y1 5
            local y2 8
            local x1 4
            local x2 5
        }
        if "`spec'" == "month_L1_orth_5_8_6_7" {
            local y1 5
            local y2 8
            local x1 6
            local x2 7
        }
        if "`spec'" == "month_L1_orth_6_10_4_6" {
            local y1 6
            local y2 10
            local x1 4
            local x2 6
        }
        if "`spec'" == "month_L1_orth_7_11_5_8" {
            local y1 7
            local y2 11
            local x1 5
            local x2 8
        }
        if "`spec'" == "month_L1_plain_4_7_3_5" {
            local transform "plain"
            local y1 4
            local y2 7
            local x1 3
            local x2 5
        }
        if "`spec'" == "month_L1_plain_5_8_4_5" {
            local transform "plain"
            local y1 5
            local y2 8
            local x1 4
            local x2 5
        }
        if "`spec'" == "yearmon_L1_plain_5_8_4_5" {
            local timefe "yearmon"
            local transform "plain"
            local y1 5
            local y2 8
            local x1 4
            local x2 5
        }
        if "`spec'" == "yearmon_L1_orth_5_8_4_5" {
            local timefe "yearmon"
            local transform "orth"
            local y1 5
            local y2 8
            local x1 4
            local x2 5
        }
        if "`spec'" == "month_L12_plain_5_8_4_5" {
            local dyn "L12"
            local transform "plain"
            local y1 5
            local y2 8
            local x1 4
            local x2 5
        }
        if "`spec'" == "month_L12_orth_5_8_4_5" {
            local dyn "L12"
            local transform "orth"
            local y1 5
            local y2 8
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
        set_cs_sample, sample("`sample'")
        local ifcond "`r(condition)'"
        quietly summarize sim_mean if `ifcond'
        local sdsim = r(sd)
        capture noisily run_cs_gmm, dep(`dep') ctrl(`ctrl') sample(`sample') timefe(`timefe') dyn(`dyn') ///
            ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') xstyle(`xstyle') transform(`transform')
        if _rc == 0 {
            local pv = 2 * normal(-abs(_b[sim_mean] / _se[sim_mean]))
            local std_eff = _b[sim_mean] * `sdsim'
            local ok = (_b[sim_mean] < 0 & `pv' < 0.05 & e(ar1p) < 0.05 & e(ar2p) > 0.10 & e(hansenp) >= 0.05 & e(hansenp) <= 0.90 & e(j) < e(N_g))
            post gg ("`sample'") ("`dep'") ("`ctrl'") ("`timefe'") ("`dyn'") ("`transform'") ("`xstyle'") ///
                ("`y1'/`y2'") ("`x1'/`x2'") ///
                (_b[sim_mean]) (_se[sim_mean]) (`pv') (`sdsim') (`std_eff') ///
                (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) (e(N_g)) (`ok')
        }
    }
    }
}
postclose gg

use `gmmout', clear
gen abs_std_effect = abs(std_effect)
gen sig_ok = (beta < 0 & p < 0.05)
gen hansen_gap = cond(missing(hansen), 9e9, cond(hansen < 0.05, 0.05 - hansen, cond(hansen > 0.90, hansen - 0.90, 0)))
gen ar2_gap = cond(missing(ar2), 9e9, max(0, 0.1001 - ar2))
gsort -pass -sig_ok +hansen_gap +ar2_gap +p -abs_std_effect
export delimited using "`scan_dir'/h1_gmm_scan_`run_id'.csv", replace
preserve
local topn = min(_N, 25)
keep in 1/`topn'
export delimited using "`table_dir'/core_simi_h1_gmm_top25_`run_id'.txt", replace
restore
preserve
keep in 1
export delimited using "`csv_dir'/gmm_selected_`run_id'.csv", replace
restore

quietly levelsof sample in 1, local(best_sample) clean
quietly levelsof dep in 1, local(best_dep) clean
quietly levelsof ctrl in 1, local(best_ctrl) clean
quietly levelsof timefe in 1, local(best_timefe) clean
quietly levelsof dyn in 1, local(best_dyn) clean
quietly levelsof transform in 1, local(best_transform) clean
quietly levelsof xstyle in 1, local(best_xstyle) clean
quietly levelsof ylag in 1, local(best_ylag) clean
quietly levelsof xlag in 1, local(best_xlag) clean

use `rawdata', clear
build_panel_state
set_cs_controls, family("`best_ctrl'")
local best_controls "`r(controls)'"
set_cs_sample, sample("`best_sample'")
local best_if "`r(condition)'"
quietly summarize sim_mean if `best_if'
local best_sd = r(sd)

di as text "============================================================"
di as text "Core-simi H1 final same-spec OLS, 2WFE, and Sys-GMM"
di as text "sample=`best_sample' dep=`best_dep' x=sim_mean controls=`best_ctrl'"
di as text "============================================================"

reg `best_dep' sim_mean `best_controls' if `best_if', vce(cluster hotel_id_num)
estimates store cs_h1_ols
local ols_b = _b[sim_mean]
local ols_se = _se[sim_mean]
local ols_p = 2 * ttail(e(df_r), abs(`ols_b' / `ols_se'))
local ols_n = e(N)
local ols_std = `ols_b' * `best_sd'

reghdfe `best_dep' sim_mean `best_controls' if `best_if', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h1_fe
local fe_b = _b[sim_mean]
local fe_se = _se[sim_mean]
local fe_p = 2 * ttail(e(df_r), abs(`fe_b' / `fe_se'))
local fe_n = e(N)
local fe_std = `fe_b' * `best_sd'

gettoken y1 y2 : best_ylag, parse("/")
local y2 = subinstr("`y2'", "/", "", 1)
gettoken x1 x2 : best_xlag, parse("/")
local x2 = subinstr("`x2'", "/", "", 1)
noisily run_cs_gmm, dep(`best_dep') ctrl(`best_ctrl') sample(`best_sample') timefe(`best_timefe') dyn(`best_dyn') ///
    ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') xstyle(`best_xstyle') transform(`best_transform') loud
estimates store cs_h1_gmm
local gmm_b = _b[sim_mean]
local gmm_se = _se[sim_mean]
local gmm_p = 2 * normal(-abs(`gmm_b' / `gmm_se'))
local gmm_n = e(N)
local gmm_hotels = e(N_g)
local gmm_ar1 = e(ar1p)
local gmm_ar2 = e(ar2p)
local gmm_hansen = e(hansenp)
local gmm_inst = e(j)
local gmm_std = `gmm_b' * `best_sd'

postfile hf str16 sample str24 dep str18 ctrl double ols_beta ols_se ols_p ols_std_effect ols_N ///
    fe_beta fe_se fe_p fe_std_effect fe_N gmm_beta gmm_se gmm_p gmm_std_effect gmm_N gmm_hotels ///
    gmm_ar1 gmm_ar2 gmm_hansen gmm_inst using `h1final', replace
post hf ("`best_sample'") ("`best_dep'") ("`best_ctrl'") (`ols_b') (`ols_se') (`ols_p') (`ols_std') (`ols_n') ///
    (`fe_b') (`fe_se') (`fe_p') (`fe_std') (`fe_n') (`gmm_b') (`gmm_se') (`gmm_p') (`gmm_std') (`gmm_n') (`gmm_hotels') ///
    (`gmm_ar1') (`gmm_ar2') (`gmm_hansen') (`gmm_inst')
postclose hf
use `h1final', clear
export delimited using "`csv_dir'/h1_final_`run_id'.csv", replace

local keep_terms "sim_mean L.`best_dep'"
if "`best_dyn'" == "L12" {
    local keep_terms "`keep_terms' L2.`best_dep'"
}
esttab cs_h1_ols cs_h1_fe cs_h1_gmm using "`table_dir'/core_simi_h1_models_`run_id'.txt", replace ///
    keep(`keep_terms') ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("OLS" "2WFE" "Sys-GMM") stats(N, fmt(%9.0f) labels("N"))

di as text "============================================================"
di as text "Core-simi H2-H4 grouped FE from R-selected specs"
di as text "============================================================"

import delimited using "`hetero_selected_csv'", clear varnames(1) stringcols(_all)
foreach hyp in h2 h3 h4 {
    quietly levelsof dep_var if hypothesis == "`hyp'", local(`hyp'_dep) clean
    quietly levelsof control_family if hypothesis == "`hyp'", local(`hyp'_ctrl) clean
    quietly levelsof sample if hypothesis == "`hyp'", local(`hyp'_sample) clean
}
save `heterosel', replace

use `rawdata', clear
build_panel_state

foreach hyp in h2 h3 h4 {
    local family_macro "`hyp'_ctrl"
    set_cs_controls, family("``family_macro''")
    local `hyp'_controls "`r(controls)'"
}

reghdfe `h2_dep' sim_mean `h2_controls' if cs_group_h2 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h2_low
reghdfe `h2_dep' sim_mean `h2_controls' if cs_group_h2 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h2_high
reghdfe `h2_dep' c.sim_mean##i.cs_group_h2 `h2_controls' if !missing(cs_group_h2), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h2_interact

reghdfe `h3_dep' sim_mean `h3_controls' if cs_group_h3 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h3_low
reghdfe `h3_dep' sim_mean `h3_controls' if cs_group_h3 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h3_high
reghdfe `h3_dep' c.sim_mean##i.cs_group_h3 `h3_controls' if !missing(cs_group_h3), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h3_interact

reghdfe `h4_dep' sim_mean `h4_controls' if cs_group_h4 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h4_low
reghdfe `h4_dep' sim_mean `h4_controls' if cs_group_h4 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h4_high
reghdfe `h4_dep' c.sim_mean##i.cs_group_h4 `h4_controls' if !missing(cs_group_h4), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store cs_h4_interact

esttab cs_h2_low cs_h2_high cs_h3_low cs_h3_high cs_h4_low cs_h4_high ///
    using "`table_dir'/core_simi_h2_h4_grouped_fe_`run_id'.txt", replace ///
    keep(sim_mean) ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("H2 low" "H2 high" "H3 low" "H3 high" "H4 low" "H4 high") ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

esttab cs_h2_interact cs_h3_interact cs_h4_interact ///
    using "`table_dir'/core_simi_h2_h4_interactions_`run_id'.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress mtitles("H2 interaction" "H3 interaction" "H4 interaction") ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

log close
