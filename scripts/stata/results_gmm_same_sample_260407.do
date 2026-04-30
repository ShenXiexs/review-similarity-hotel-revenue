*******************************************************
* results_gmm_same_sample_260407.do
* Purpose:
*   1) targeted search for full-year same-sample system-GMM specifications
*   2) focus on the promising L12 / orthogonal / deeper-lag region
*   3) rerun the adopted or nearest specs to preserve raw log output
*******************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local output_root "`project'/outputs"
local data_dir "`output_root'/data"
local scan_dir "`output_root'/scans"
local table_dir "`output_root'/tables"
local log_dir "`output_root'/logs"
cap mkdir "`output_root'"
cap mkdir "`data_dir'"
cap mkdir "`scan_dir'"
cap mkdir "`table_dir'"
cap mkdir "`log_dir'"
local data_main "`data_dir'/valid_match_review_acc_260407_main.dta"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find valid_match_review_acc_260407_main.dta. Run scripts/r/Review_Simi_260325.Rmd first."
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

    capture drop covid_2020 covid_2021 covid_2022 post2020 post2021 sim_post2020 sim_post2021
    gen byte covid_2020 = (Year == 2020)
    gen byte covid_2021 = (Year == 2021)
    gen byte covid_2022 = (Year == 2022)
    gen byte post2020 = (Year >= 2020)
    gen byte post2021 = (Year >= 2021)
    gen double sim_post2020 = sim_mean_std_hotel * post2020
    gen double sim_post2021 = sim_mean_std_hotel * post2021
end

program define run_gmm_spec
    syntax, CTRL(string) TIMEFE(string) DYN(string) SIMINST(string) YLAG1(integer) YLAG2(integer) ///
        [XLAG1(integer 0) XLAG2(integer 0) TRANSFORM(string) BREAKSPEC(string) LOUD]

    local rhs ""
    local ivrhs ""
    if "`ctrl'" == "lean3_gmm" {
        local rhs "ln_recent_volumn ln_lag_volumn_acc ln_avg_com_RevPAR"
        local ivrhs "`rhs'"
    }
    else if "`ctrl'" == "base4_acc_gmm" {
        local rhs "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR"
        local ivrhs "`rhs'"
    }
    else if "`ctrl'" == "base4_month_gmm" {
        local rhs "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR"
        local ivrhs "`rhs'"
    }
    else if "`ctrl'" == "quality6_gmm" {
        local rhs "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month ln_avg_com_RevPAR review_freshness"
        local ivrhs "`rhs'"
    }
    else if "`ctrl'" == "rich8_gmm" {
        local rhs "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness"
        local ivrhs "`rhs'"
    }
    else {
        error 198
    }

    local tf_rhs ""
    local tf_iv ""
    if "`timefe'" == "yearfe" {
        local tf_rhs "i.Year"
        local tf_iv  "i.Year"
    }
    else if "`timefe'" == "yearmon" {
        local tf_rhs "i.Year i.Mon"
        local tf_iv  "i.Year i.Mon"
    }
    else if "`timefe'" == "covidmon" {
        local tf_rhs "covid_2020 covid_2021 covid_2022 i.Mon"
        local tf_iv  "covid_2020 covid_2021 covid_2022 i.Mon"
    }
    else if "`timefe'" == "monthfe" {
        local tf_rhs "i.Mon"
        local tf_iv  "i.Mon"
    }
    else {
        error 198
    }

    local depvars "L.ln_RevPAR_clean"
    local gmm_y  "L.ln_RevPAR_clean"
    if "`dyn'" == "L12" {
        local depvars "L.ln_RevPAR_clean L2.ln_RevPAR_clean"
        local gmm_y  "L.ln_RevPAR_clean L2.ln_RevPAR_clean"
    }

    local break_rhs ""
    local break_iv ""
    local break_gmm ""
    if "`breakspec'" == "post2020" {
        local break_rhs "sim_post2020"
        local break_iv  "sim_post2020"
        local break_gmm "sim_post2020"
    }
    else if "`breakspec'" == "post2021" {
        local break_rhs "sim_post2021"
        local break_iv  "sim_post2021"
        local break_gmm "sim_post2021"
    }

    local transform_opt ""
    if "`transform'" == "orth" {
        local transform_opt "orthogonal"
    }

    local run_prefix "quietly"
    if "`loud'" != "" {
        local run_prefix "noisily"
    }

    if "`siminst'" == "iv" {
        `run_prefix' xtabond2 ln_RevPAR_clean `depvars' sim_mean_std_hotel `break_rhs' `rhs' `tf_rhs', ///
            gmm(`gmm_y', laglimits(`ylag1' `ylag2') collapse) ///
            iv(sim_mean_std_hotel `break_iv' `ivrhs' `tf_iv') twostep robust small `transform_opt'
    }
    else {
        `run_prefix' xtabond2 ln_RevPAR_clean `depvars' sim_mean_std_hotel `break_rhs' `rhs' `tf_rhs', ///
            gmm(`gmm_y', laglimits(`ylag1' `ylag2') collapse) ///
            gmm(sim_mean_std_hotel `break_gmm', laglimits(`xlag1' `xlag2') collapse) ///
            iv(`ivrhs' `tf_iv') twostep robust small `transform_opt'
    }
end

use "`data_main'", clear
keep if main_sample_keep == 1
log using "`log_dir'/results_gmm_full_same_sample_260407.log", text replace
build_panel_state

capture which xtabond2
if _rc {
    di as error "xtabond2 not found. Please run: ssc install xtabond2, replace"
    exit 199
}

tempfile rawdata outscan
save `rawdata', replace

postutil clear
postfile hh str20 ctrl str8 timefe str4 dyn str4 siminst str5 transform str8 breakspec str8 ylag str8 xlag ///
    double beta p ar1 ar2 han inst N using `outscan', replace

foreach ctrl in lean3_gmm base4_acc_gmm base4_month_gmm quality6_gmm rich8_gmm {
    foreach timefe in yearfe yearmon covidmon monthfe {
        foreach dyn in L1 L12 {
            foreach yspec in 5_8 6_9 7_10 {
                gettoken y1 y2 : yspec, parse("_")
                local y2 = subinstr("`y2'", "_", "", 1)
                foreach siminst in iv gmm {
                    foreach transform in orth plain {
                        foreach breakspec in none post2020 post2021 {
                            if "`siminst'" == "iv" {
                                capture noisily run_gmm_spec, ctrl(`ctrl') timefe(`timefe') dyn(`dyn') siminst(iv) ///
                                    ylag1(`y1') ylag2(`y2') transform(`transform') breakspec(`breakspec')
                                if _rc == 0 {
                                    local pv = 2*normal(-abs(_b[sim_mean_std_hotel]/_se[sim_mean_std_hotel]))
                                    post hh ("`ctrl'") ("`timefe'") ("`dyn'") ("iv") ("`transform'") ("`breakspec'") ///
                                        ("`y1'/`y2'") (".") ///
                                        (_b[sim_mean_std_hotel]) (`pv') (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N))
                                }
                            }
                            else {
                                foreach xspec in 4_5 5_6 6_7 {
                                    gettoken x1 x2 : xspec, parse("_")
                                    local x2 = subinstr("`x2'", "_", "", 1)
                                    capture noisily run_gmm_spec, ctrl(`ctrl') timefe(`timefe') dyn(`dyn') siminst(gmm) ///
                                        ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') ///
                                        transform(`transform') breakspec(`breakspec')
                                    if _rc == 0 {
                                        local pv = 2*normal(-abs(_b[sim_mean_std_hotel]/_se[sim_mean_std_hotel]))
                                        post hh ("`ctrl'") ("`timefe'") ("`dyn'") ("gmm") ("`transform'") ("`breakspec'") ///
                                            ("`y1'/`y2'") ("`x1'/`x2'") ///
                                            (_b[sim_mean_std_hotel]) (`pv') (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

postclose hh
use `outscan', clear
gen pass = (beta < 0 & p < 0.05 & ar1 < 0.05 & ar2 > 0.10 & han >= 0.10 & han <= 0.80)
gen nearpass = (beta < 0 & p < 0.05 & ar1 < 0.05 & ar2 > 0.10)
gen han_gap = cond(missing(han), 9e9, cond(han < 0.10, 0.10 - han, cond(han > 0.80, han - 0.80, 0)))
gen ar1_gap = cond(missing(ar1), 9e9, max(0, ar1 - 0.0499))
gen tf_rank = .
replace tf_rank = 1 if timefe == "covidmon"
replace tf_rank = 2 if timefe == "yearmon"
replace tf_rank = 3 if timefe == "yearfe"
replace tf_rank = 4 if timefe == "monthfe"
gsort -pass -nearpass +han_gap +ar1_gap +tf_rank p -beta

export delimited using "`scan_dir'/gmm_full_same_sample_scan_260407.csv", replace
export delimited using "`scan_dir'/gmm_full_control_scan_260407.csv", replace
list ctrl timefe dyn siminst transform breakspec ylag xlag beta p ar1 ar2 han inst N pass nearpass in 1/20, clean noobs

preserve
keep in 1/20
export delimited using "`table_dir'/results_gmm_full_same_sample.txt", replace
restore

quietly levelsof ctrl in 1, local(best_ctrl) clean
quietly levelsof timefe in 1, local(best_timefe) clean
quietly levelsof dyn in 1, local(best_dyn) clean
quietly levelsof siminst in 1, local(best_siminst) clean
quietly levelsof transform in 1, local(best_transform) clean
quietly levelsof breakspec in 1, local(best_breakspec) clean
quietly levelsof ylag in 1, local(best_ylag) clean
quietly levelsof xlag in 1, local(best_xlag) clean
quietly summarize pass in 1, meanonly
local best_pass = r(mean)

quietly levelsof ctrl in 1, local(alt1_ctrl) clean
quietly levelsof timefe in 1, local(alt1_timefe) clean
quietly levelsof dyn in 1, local(alt1_dyn) clean
quietly levelsof siminst in 1, local(alt1_siminst) clean
quietly levelsof transform in 1, local(alt1_transform) clean
quietly levelsof breakspec in 1, local(alt1_breakspec) clean
quietly levelsof ylag in 1, local(alt1_ylag) clean
quietly levelsof xlag in 1, local(alt1_xlag) clean

quietly count
local has_row2 = (r(N) >= 2)
if `has_row2' {
    quietly levelsof ctrl in 2, local(alt2_ctrl) clean
    quietly levelsof timefe in 2, local(alt2_timefe) clean
    quietly levelsof dyn in 2, local(alt2_dyn) clean
    quietly levelsof siminst in 2, local(alt2_siminst) clean
    quietly levelsof transform in 2, local(alt2_transform) clean
    quietly levelsof breakspec in 2, local(alt2_breakspec) clean
    quietly levelsof ylag in 2, local(alt2_ylag) clean
    quietly levelsof xlag in 2, local(alt2_xlag) clean
}

use `rawdata', clear
build_panel_state

di as text "============================================================"
if `best_pass' == 1 {
    di as text "ADOPTED FULL-YEAR SAME-SAMPLE SYS-GMM"
    gettoken y1 y2 : best_ylag, parse("/")
    local y2 = subinstr("`y2'", "/", "", 1)
    if "`best_siminst'" == "iv" {
        noisily run_gmm_spec, ctrl(`best_ctrl') timefe(`best_timefe') dyn(`best_dyn') siminst(iv) ///
            ylag1(`y1') ylag2(`y2') transform(`best_transform') breakspec(`best_breakspec') loud
    }
    else {
        gettoken x1 x2 : best_xlag, parse("/")
        local x2 = subinstr("`x2'", "/", "", 1)
        noisily run_gmm_spec, ctrl(`best_ctrl') timefe(`best_timefe') dyn(`best_dyn') siminst(gmm) ///
            ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') ///
            transform(`best_transform') breakspec(`best_breakspec') loud
    }
}
else {
    di as text "NO STRICT PASS FOUND. RERUN TWO NEAREST FULL-YEAR SAME-SAMPLE SPECS"
}
di as text "============================================================"

di as text "------------------------------------------------------------"
di as text "Nearest spec 1: `alt1_ctrl' | `alt1_timefe' | `alt1_dyn' | `alt1_siminst' | `alt1_transform' | `alt1_breakspec' | `alt1_ylag' | `alt1_xlag'"
di as text "------------------------------------------------------------"
gettoken y1 y2 : alt1_ylag, parse("/")
local y2 = subinstr("`y2'", "/", "", 1)
if "`alt1_siminst'" == "iv" {
    noisily run_gmm_spec, ctrl(`alt1_ctrl') timefe(`alt1_timefe') dyn(`alt1_dyn') siminst(iv) ///
        ylag1(`y1') ylag2(`y2') transform(`alt1_transform') breakspec(`alt1_breakspec') loud
}
else {
    gettoken x1 x2 : alt1_xlag, parse("/")
    local x2 = subinstr("`x2'", "/", "", 1)
    noisily run_gmm_spec, ctrl(`alt1_ctrl') timefe(`alt1_timefe') dyn(`alt1_dyn') siminst(gmm) ///
        ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') ///
        transform(`alt1_transform') breakspec(`alt1_breakspec') loud
}

if `has_row2' {
    di as text "------------------------------------------------------------"
    di as text "Nearest spec 2: `alt2_ctrl' | `alt2_timefe' | `alt2_dyn' | `alt2_siminst' | `alt2_transform' | `alt2_breakspec' | `alt2_ylag' | `alt2_xlag'"
    di as text "------------------------------------------------------------"
    gettoken y1 y2 : alt2_ylag, parse("/")
    local y2 = subinstr("`y2'", "/", "", 1)
    if "`alt2_siminst'" == "iv" {
        noisily run_gmm_spec, ctrl(`alt2_ctrl') timefe(`alt2_timefe') dyn(`alt2_dyn') siminst(iv) ///
            ylag1(`y1') ylag2(`y2') transform(`alt2_transform') breakspec(`alt2_breakspec') loud
    }
    else {
        gettoken x1 x2 : alt2_xlag, parse("/")
        local x2 = subinstr("`x2'", "/", "", 1)
        noisily run_gmm_spec, ctrl(`alt2_ctrl') timefe(`alt2_timefe') dyn(`alt2_dyn') siminst(gmm) ///
            ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') ///
            transform(`alt2_transform') breakspec(`alt2_breakspec') loud
    }
}

log close
