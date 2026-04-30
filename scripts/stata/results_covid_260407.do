*******************************************************
* results_covid_260407.do
* Purpose:
*   1) export same-sample FE / OLS covid-year shock results
*   2) rerun the key full-year GMM break specifications
*   3) preserve full raw Stata output for Paper_Results_260407.md
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
local csv_dir "`output_root'/csv"
local table_dir "`output_root'/tables"
local log_dir "`output_root'/logs"
cap mkdir "`output_root'"
cap mkdir "`data_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`table_dir'"
cap mkdir "`log_dir'"
local data_main "`data_dir'/valid_match_review_acc_260407_main.dta"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find valid_match_review_acc_260407_main.dta."
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
log using "`log_dir'/results_covid_260407.log", text replace
build_panel_state

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

quietly levelsof selected_control_family if main_sample_keep == 1, local(selected_ctrl) clean
local ctrl_base
if "`selected_ctrl'" == "rich8_current" {
    local ctrl_base "ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "quality6" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month ln_avg_com_RevPAR review_freshness ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "base4_acc" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "base4_month" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "lean3" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean"
}
else if "`selected_ctrl'" == "momentum_plus" {
    local ctrl_base "ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR rating_momentum volume_momentum review_freshness ln_lag_RevPAR_clean"
}
else {
    di as error "Unknown selected_control_family: `selected_ctrl'"
    exit 198
}

di as text "============================================================"
di as text "1) COVID YEAR-SHOCK FE / OLS"
di as text "============================================================"
reghdfe ln_RevPAR_clean sim_mean `ctrl_base' covid_2020 covid_2021 covid_2022 if main_sample_keep == 1, absorb(hotel_id_num Mon) vce(cluster hotel_id_num)
estimates store c1_fe

reg ln_RevPAR_clean sim_mean `ctrl_base' covid_2020 covid_2021 covid_2022 i.Mon if main_sample_keep == 1, vce(cluster hotel_id_num)
estimates store c2_ols

esttab c1_fe c2_ols ///
    using "`table_dir'/results_covid_fe_260407.txt", replace ///
    se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
    label compress nomtitles nonumber ///
    stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))

postutil clear
tempfile fecov outgmm
postfile hh str8 model str12 term double beta se p N using `fecov', replace

foreach model in c1_fe c2_ols {
    estimates restore `model'
    foreach term in sim_mean covid_2020 covid_2021 covid_2022 {
        capture local beta = _b[`term']
        if !_rc {
            local se = _se[`term']
            local pv = 2*normal(-abs(`beta'/`se'))
            post hh ("`model'") ("`term'") (`beta') (`se') (`pv') (e(N))
        }
    }
}
postclose hh
use `fecov', clear
export delimited using "`csv_dir'/covid_effect_fe_260407.csv", replace

use "`data_main'", clear
keep if main_sample_keep == 1
build_panel_state

postutil clear
postfile gg str14 spec_id str20 ctrl str8 timefe str4 dyn str4 siminst str5 transform str8 breakspec str8 ylag str8 xlag ///
    double beta_main p_main beta_break p_break ar1 ar2 han inst N pass nearpass using `outgmm', replace

di as text "============================================================"
di as text "2) FULL-YEAR GMM COVID BREAKPOINT RERUN"
di as text "============================================================"

* No-break adopted spec
noisily run_gmm_spec, ctrl(base4_month_gmm) timefe(monthfe) dyn(L1) siminst(gmm) ylag1(5) ylag2(8) xlag1(6) xlag2(7) transform(orth) breakspec(none) loud
local pv_main = 2*normal(-abs(_b[sim_mean_std_hotel]/_se[sim_mean_std_hotel]))
post gg ("gmm_none") ("base4_month_gmm") ("monthfe") ("L1") ("gmm") ("orth") ("none") ("5/8") ("6/7") ///
    (_b[sim_mean_std_hotel]) (`pv_main') (.) (.) (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) ///
    ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) & (e(hansenp) >= 0.10) & (e(hansenp) <= 0.80) ) ///
    ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) )

* Best post2020 near-pass
noisily run_gmm_spec, ctrl(lean3_gmm) timefe(covidmon) dyn(L12) siminst(iv) ylag1(7) ylag2(10) transform(plain) breakspec(post2020) loud
local pv_main = 2*normal(-abs(_b[sim_mean_std_hotel]/_se[sim_mean_std_hotel]))
local pv_break = 2*normal(-abs(_b[sim_post2020]/_se[sim_post2020]))
post gg ("gmm_post2020") ("lean3_gmm") ("covidmon") ("L12") ("iv") ("plain") ("post2020") ("7/10") (".") ///
    (_b[sim_mean_std_hotel]) (`pv_main') (_b[sim_post2020]) (`pv_break') (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) ///
    ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) & (e(hansenp) >= 0.10) & (e(hansenp) <= 0.80) ) ///
    ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) )

* Best post2021 near-pass
noisily run_gmm_spec, ctrl(rich8_gmm) timefe(monthfe) dyn(L1) siminst(gmm) ylag1(5) ylag2(8) xlag1(4) xlag2(5) transform(orth) breakspec(post2021) loud
local pv_main = 2*normal(-abs(_b[sim_mean_std_hotel]/_se[sim_mean_std_hotel]))
local pv_break = 2*normal(-abs(_b[sim_post2021]/_se[sim_post2021]))
post gg ("gmm_post2021") ("rich8_gmm") ("monthfe") ("L1") ("gmm") ("orth") ("post2021") ("5/8") ("4/5") ///
    (_b[sim_mean_std_hotel]) (`pv_main') (_b[sim_post2021]) (`pv_break') (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) ///
    ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) & (e(hansenp) >= 0.10) & (e(hansenp) <= 0.80) ) ///
    ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) )

postclose gg
use `outgmm', clear
export delimited using "`csv_dir'/covid_effect_gmm_260407.csv", replace

log close
