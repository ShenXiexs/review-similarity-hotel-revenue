************************************************************
* Route A scope-10: transparent system-GMM sensitivity grid
*
* Focal specification carried over from the Route A FE model:
*   y = sim_mean + recent_sd_10 + ln_recent_volumn_10
*       + recent_rating_10 + ln_lag_volumn_acc
*       + lag_avg_rating_acc + lag_sd_acc
*       + ln_avg_com_RevPAR + lagged y + hotel/month structure
*
* This script intentionally writes no log, CSV, RTF, XLSX, or DTA.
* Scan results live only in a Stata tempfile and are printed to Results.
************************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close _all
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_main "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"

capture confirm file "`data_main'"
if _rc {
    display as error "Data not found: `data_main'"
    exit 601
}

capture which xtabond2
if _rc {
    display as error "xtabond2 is required. Install once with: ssc install xtabond2, replace"
    exit 199
}

capture which winsor2
if _rc {
    display as error "winsor2 is required. Install once with: ssc install winsor2, replace"
    exit 199
}

use "`data_main'", clear
keep if cs_sample_focus100 == 1 & !missing(recent_sd_10)

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID

capture drop ym
gen int ym = monthly(year_month, "YM")
format ym %tm
sort hotel_id_num ym
isid hotel_id_num ym
xtset hotel_id_num ym

* Generate the three outcome and three precomputed-lag variants requested.
capture drop ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595
capture drop ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w195 ln_lag_RevPAR_clean_w595
winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(1 95) suffix(_w195)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

local controls "recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR"

* Keep a common complete-case sample across all 3x3 combinations.
egen byte routeA_gmm_miss = rowmiss(sim_mean `controls' ///
    ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595 ///
    ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w195 ln_lag_RevPAR_clean_w595 ///
    hotel_id_num ym Year Mon)
keep if routeA_gmm_miss == 0
drop routeA_gmm_miss
xtset hotel_id_num ym

tempfile scan
postutil clear
postfile G str4 ywin str4 lagwin str5 transform int laglo int laghi ///
    double beta se p_ar1 p_ar2 p_hansen instruments groups observations ///
    byte pass_core byte pass_strict using `scan', replace

local outcomes "199 195 595"
local lagvars  "199 195 595"
local lagsets  "2_3 3_4 4_5 5_7"

foreach yw of local outcomes {
    foreach lw of local lagvars {
        foreach ls of local lagsets {
            gettoken lo hi : ls, parse("_")
            local hi = subinstr("`hi'", "_", "", 1)

            foreach tr in diff orth {
                local tr_opt ""
                if "`tr'" == "orth" local tr_opt "orthogonal"

                capture quietly xtabond2 ln_RevPAR_clean_w`yw' ///
                    ln_lag_RevPAR_clean_w`lw' sim_mean `controls' i.Year i.Mon, ///
                    gmm(ln_lag_RevPAR_clean_w`lw', laglimits(`lo' `hi') collapse) ///
                    gmm(sim_mean, laglimits(`lo' `hi') collapse) ///
                    iv(`controls' i.Year i.Mon) ///
                    twostep robust small `tr_opt'

                if _rc == 0 {
                    local b  = _b[sim_mean]
                    local s  = _se[sim_mean]
                    local pv = 2*ttail(e(df_r), abs(`b'/`s'))
                    local ar1 = e(ar1p)
                    local ar2 = e(ar2p)
                    local han = e(hansenp)
                    local jj  = e(j)
                    local ng  = e(N_g)
                    local nn  = e(N)

                    * Core: requested sign/significance + AR(2) and Hansen at 5%.
                    local pc = (`b' < 0 & `pv' < .05 & `ar2' > .05 & `han' > .05 & `jj' < `ng')
                    * Strict: additionally expected AR(1), conservative test bounds.
                    local ps = (`pc' == 1 & `ar1' < .05 & `ar2' > .10 & `han' >= .10 & `han' <= .80)

                    post G ("`yw'") ("`lw'") ("`tr'") (`lo') (`hi') ///
                        (`b') (`s') (`ar1') (`ar2') (`han') (`jj') (`ng') (`nn') (`pc') (`ps')
                }
                else {
                    display as error "Skipped failed model: y=`yw', lag=`lw', transform=`tr', lags=`lo'/`hi'; rc=" _rc
                }
            }
        }
    }
}
postclose G

use `scan', clear
gen double p_sim = 2*ttail(groups - 1, abs(beta/se))
format beta se p_sim p_ar1 p_ar2 p_hansen %9.4f
label var ywin       "winsor(y)"
label var lagwin     "winsor(lag y)"
label var p_sim      "p(sim_mean)"
label var p_ar1      "AR(1) p"
label var p_ar2      "AR(2) p"
label var p_hansen   "Hansen p"
label var pass_core  "requested pass"
label var pass_strict "strict pass"

gsort -pass_strict -pass_core p_sim -p_ar2 -p_hansen instruments

display as text ""
display as text "================================================================================================================"
display as text "ROUTE A SCOPE-10 SYSTEM-GMM: COMPLETE TRANSPARENT GRID"
display as text "Core pass: beta<0, p<.05, AR(2) p>.05, Hansen p>.05, instruments<groups"
display as text "Strict pass also requires AR(1) p<.05, AR(2) p>.10, and .10<=Hansen p<=.80"
display as text "================================================================================================================"
count
display as result "Successfully estimated specifications: " r(N)
count if pass_core == 1
local n_core_stage1 = r(N)
display as result "Core passes: " r(N)
count if pass_strict == 1
display as result "Strict passes: " r(N)

list ywin lagwin transform laglo laghi beta se p_sim p_ar1 p_ar2 p_hansen instruments groups observations pass_core pass_strict, ///
    clean noobs abbreviate(16)

if `n_core_stage1' > 0 {
    display as text ""
    display as text "Best passing Stage-1 specification rerun below with full xtabond2 output:"
    local best_y  = ywin[1]
    local best_l  = lagwin[1]
    local best_tr = transform[1]
    local best_lo = laglo[1]
    local best_hi = laghi[1]
    local best_opt ""
    if "`best_tr'" == "orth" local best_opt "orthogonal"

    use "`data_main'", clear
    keep if cs_sample_focus100 == 1 & !missing(recent_sd_10)
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
    gen int ym = monthly(year_month, "YM")
    format ym %tm
    sort hotel_id_num ym
    xtset hotel_id_num ym

    capture drop ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595
    capture drop ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w195 ln_lag_RevPAR_clean_w595
    winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
    winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
    winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
    winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
    winsor2 ln_lag_RevPAR_clean, cuts(1 95) suffix(_w195)
    winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

    egen byte routeA_gmm_miss = rowmiss(sim_mean `controls' ///
        ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595 ///
        ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w195 ln_lag_RevPAR_clean_w595 ///
        hotel_id_num ym Year Mon)
    keep if routeA_gmm_miss == 0
    drop routeA_gmm_miss
    xtset hotel_id_num ym

    noisily xtabond2 ln_RevPAR_clean_w`best_y' ///
        ln_lag_RevPAR_clean_w`best_l' sim_mean `controls' i.Year i.Mon, ///
        gmm(ln_lag_RevPAR_clean_w`best_l', laglimits(`best_lo' `best_hi') collapse) ///
        gmm(sim_mean, laglimits(`best_lo' `best_hi') collapse) ///
        iv(`controls' i.Year i.Mon) ///
        twostep robust small `best_opt'

    display as text "Selected Stage-1 grid cell: outcome winsor=`best_y'; lagged outcome winsor=`best_l'; transform=`best_tr'; GMM lags=`best_lo'/`best_hi'."
}
else {
    display as error "No Stage-1 specification passes the requested AR(2)/Hansen criteria. Nothing is adopted."
    use "`data_main'", clear
    keep if cs_sample_focus100 == 1 & !missing(recent_sd_10)
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
    gen int ym = monthly(year_month, "YM")
    format ym %tm
    sort hotel_id_num ym
    xtset hotel_id_num ym
    winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
    winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
    winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
}

************************************************************
* Stage 2: conventional dynamic-y system GMM.
*
* The direct precomputed-lag mapping above is retained as a
* diagnostic.  Here the dynamic terms are L.y and L2.y.  The
* focal variable and the original controls enter the standard
* instrument set (the strict-exogeneity implementation already
* used as one branch in the project's prior GMM code).  The grid
* is fixed ex ante below; no sample-period search is performed.
************************************************************

capture drop covid_2020 covid_2021 covid_2022
gen byte covid_2020 = (Year == 2020)
gen byte covid_2021 = (Year == 2021)
gen byte covid_2022 = (Year == 2022)

tempfile targeted_scan
postutil clear
postfile T str4 ywin str8 timefe str5 transform int laglo int laghi ///
    double beta se p_ar1 p_ar2 p_hansen instruments groups observations ///
    byte pass_core byte pass_strict using `targeted_scan', replace

local ylagsets "5_8 6_9 7_10"
local timefes "yearfe yearmon covidmon monthfe exactym"

foreach yw of local outcomes {
    foreach tf of local timefes {
        local tf_rhs ""
        if "`tf'" == "yearfe"   local tf_rhs "i.Year"
        if "`tf'" == "yearmon"  local tf_rhs "i.Year i.Mon"
        if "`tf'" == "covidmon" local tf_rhs "covid_2020 covid_2021 covid_2022 i.Mon"
        if "`tf'" == "monthfe"  local tf_rhs "i.Mon"
        if "`tf'" == "exactym"  local tf_rhs "i.ym"

        foreach ls of local ylagsets {
            gettoken lo hi : ls, parse("_")
            local hi = subinstr("`hi'", "_", "", 1)

            foreach tr in diff orth {
                local tr_opt ""
                if "`tr'" == "orth" local tr_opt "orthogonal"

                capture quietly xtabond2 ln_RevPAR_clean_w`yw' ///
                    L.ln_RevPAR_clean_w`yw' L2.ln_RevPAR_clean_w`yw' ///
                    sim_mean `controls' `tf_rhs', ///
                    gmm(L.ln_RevPAR_clean_w`yw' L2.ln_RevPAR_clean_w`yw', ///
                        laglimits(`lo' `hi') collapse) ///
                    iv(sim_mean `controls' `tf_rhs') ///
                    twostep robust small `tr_opt'

                if _rc == 0 {
                    local b   = _b[sim_mean]
                    local s   = _se[sim_mean]
                    local pv  = 2*ttail(e(df_r), abs(`b'/`s'))
                    local ar1 = e(ar1p)
                    local ar2 = e(ar2p)
                    local han = e(hansenp)
                    local jj  = e(j)
                    local ng  = e(N_g)
                    local nn  = e(N)
                    local pc  = (`b' < 0 & `pv' < .05 & `ar2' > .05 & `han' > .05 & `jj' < `ng')
                    local ps  = (`pc' == 1 & `ar1' < .05 & `ar2' > .10 & `han' >= .10 & `han' <= .80)

                    post T ("`yw'") ("`tf'") ("`tr'") (`lo') (`hi') ///
                        (`b') (`s') (`ar1') (`ar2') (`han') (`jj') (`ng') (`nn') (`pc') (`ps')
                }
                else {
                    display as error "Skipped Stage-2 model: y=`yw', time=`tf', transform=`tr', lags=`lo'/`hi'; rc=" _rc
                }
            }
        }
    }
}
postclose T

use `targeted_scan', clear
gen double p_sim = 2*ttail(groups - 1, abs(beta/se))
format beta se p_sim p_ar1 p_ar2 p_hansen %9.4f
gsort -pass_strict -pass_core p_sim -p_ar2 -p_hansen instruments

display as text ""
display as text "================================================================================================================"
display as text "STAGE 2: L.y/L2.y SYSTEM-GMM TARGETED GRID"
display as text "sim_mean classification: standard IV-style (strict exogeneity); dynamic y: collapsed GMM-style"
display as text "================================================================================================================"
count
display as result "Successfully estimated Stage-2 specifications: " r(N)
count if pass_core == 1
local n_core = r(N)
display as result "Stage-2 core passes: " r(N)
count if pass_strict == 1
local n_strict = r(N)
display as result "Stage-2 strict passes: " r(N)

list ywin timefe transform laglo laghi beta se p_sim p_ar1 p_ar2 p_hansen instruments groups observations pass_core pass_strict, ///
    clean noobs abbreviate(16)

if `n_core' > 0 {
    local final_y  = ywin[1]
    local final_tf = timefe[1]
    local final_tr = transform[1]
    local final_lo = laglo[1]
    local final_hi = laghi[1]
    local final_opt ""
    if "`final_tr'" == "orth" local final_opt "orthogonal"
    local final_tf_rhs ""
    if "`final_tf'" == "yearfe"   local final_tf_rhs "i.Year"
    if "`final_tf'" == "yearmon"  local final_tf_rhs "i.Year i.Mon"
    if "`final_tf'" == "covidmon" local final_tf_rhs "covid_2020 covid_2021 covid_2022 i.Mon"
    if "`final_tf'" == "monthfe"  local final_tf_rhs "i.Mon"
    if "`final_tf'" == "exactym"  local final_tf_rhs "i.ym"

    display as text ""
    display as text "Best passing Stage-2 specification rerun with full xtabond2 output:"
    noisily xtabond2 ln_RevPAR_clean_w`final_y' ///
        L.ln_RevPAR_clean_w`final_y' L2.ln_RevPAR_clean_w`final_y' ///
        sim_mean `controls' `final_tf_rhs', ///
        gmm(L.ln_RevPAR_clean_w`final_y' L2.ln_RevPAR_clean_w`final_y', ///
            laglimits(`final_lo' `final_hi') collapse) ///
        iv(sim_mean `controls' `final_tf_rhs') ///
        twostep robust small `final_opt'
}
else {
    display as error "No Stage-2 specification passes the requested AR(2)/Hansen criteria. Nothing is adopted."
}

display as text "No persistent output files were created."
