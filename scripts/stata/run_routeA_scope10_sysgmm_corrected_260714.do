************************************************************
* Route A scope-10: corrected system-GMM grid
*
* Corrections relative to the superseded dynamic-y script:
*   1. Uses the precomputed lagged outcome
*      ln_lag_RevPAR_clean (= lnRevenue_lag_month).
*   2. Does not replace that variable with L.y or L2.y.
*   3. Constructs winsorized variables on the full panel before
*      applying the Route-A estimation-sample restriction, so
*      available histories are not destroyed prematurely.
*   4. Uses exact calendar-month effects (i.ym), matching
*      absorb(hotel_id_num ym) more closely than i.Year i.Mon.
*   5. Uses the original sim_mean scale only.
*
* No log, CSV, RTF, XLSX, or DTA is written. Scan results are
* held only in a Stata tempfile and printed to Results.
************************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close _all
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_main "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local controls "recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR"

capture confirm file "`data_main'"
if _rc exit 601
capture which xtabond2
if _rc exit 199

use "`data_main'", clear

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

* Winsor cutoffs are estimated on the Route-A sample, as in the
* main regression, but are applied before restricting the panel.
foreach cut in 199 195 595 {
    if "`cut'" == "199" local plo = 1
    if "`cut'" == "199" local phi = 99
    if "`cut'" == "195" local plo = 1
    if "`cut'" == "195" local phi = 95
    if "`cut'" == "595" local plo = 5
    if "`cut'" == "595" local phi = 95

    quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_RevPAR_clean), p(`plo' `phi')
    local yp_lo = r(r1)
    local yp_hi = r(r2)
    capture drop ln_RevPAR_clean_w`cut'
    gen double ln_RevPAR_clean_w`cut' = min(max(ln_RevPAR_clean, `yp_lo'), `yp_hi') if !missing(ln_RevPAR_clean)

    quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_lag_RevPAR_clean), p(`plo' `phi')
    local lp_lo = r(r1)
    local lp_hi = r(r2)
    capture drop ln_lag_RevPAR_clean_w`cut'
    gen double ln_lag_RevPAR_clean_w`cut' = min(max(ln_lag_RevPAR_clean, `lp_lo'), `lp_hi') if !missing(ln_lag_RevPAR_clean)
}

* All winsor variants have the same missingness. Keep the data in
* memory and mark the common Route-A complete-case sample instead
* of deleting non-sample histories before xtabond2 constructs lags.
egen byte routeA_miss = rowmiss(sim_mean `controls' ///
    ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595 ///
    ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w195 ln_lag_RevPAR_clean_w595 ///
    hotel_id_num ym)
gen byte routeA_cc = cs_sample_focus100 == 1 & !missing(recent_sd_10) & routeA_miss == 0
drop routeA_miss

quietly count if routeA_cc == 1
display as result "Corrected Route-A complete-case observations: " r(N)

tempfile scan
postutil clear
postfile G str4 ywin str4 lagwin str5 simtype str4 transform ///
    int laglo int laghi double beta se p_sim p_ar1 p_ar2 p_hansen ///
    instruments groups observations byte pass_core byte pass_strict ///
    using `scan', replace

local outcomes "199 195 595"
local lagwins  "199 195 595"
local lagsets  "1_3 2_4 3_5 4_6 5_8 8_12"
local simtypes "iv endog"
local transforms "diff orth"

foreach yw of local outcomes {
    foreach lw of local lagwins {
        foreach ls of local lagsets {
            gettoken lo hi : ls, parse("_")
            local hi = subinstr("`hi'", "_", "", 1)

            foreach st of local simtypes {
                foreach tr of local transforms {
                    local tr_opt ""
                    if "`tr'" == "orth" local tr_opt "orthogonal"

                    local sim_instr "iv(sim_mean `controls' i.ym)"
                    if "`st'" == "endog" local sim_instr ///
                        "gmm(sim_mean, laglimits(2 4) collapse) iv(`controls' i.ym)"

                    capture quietly xtabond2 ln_RevPAR_clean_w`yw' ///
                        ln_lag_RevPAR_clean_w`lw' sim_mean `controls' i.ym ///
                        if routeA_cc == 1, ///
                        gmm(ln_lag_RevPAR_clean_w`lw', laglimits(`lo' `hi') collapse) ///
                        `sim_instr' twostep robust small `tr_opt'

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

                        local pc = (`b' < 0 & `pv' < .05 & `ar2' > .05 & ///
                            `han' > .05 & `jj' < `ng')
                        local ps = (`pc' == 1 & `ar1' < .05 & `ar2' > .10 & ///
                            `han' >= .10 & `han' <= .80)

                        post G ("`yw'") ("`lw'") ("`st'") ("`tr'") ///
                            (`lo') (`hi') (`b') (`s') (`pv') (`ar1') (`ar2') ///
                            (`han') (`jj') (`ng') (`nn') (`pc') (`ps')
                    }
                    else display as error "Failed: y=`yw' lag=`lw' sim=`st' transform=`tr' window=`lo'/`hi'; rc=" _rc
                }
            }
        }
    }
}
postclose G

use `scan', clear
format beta se p_sim p_ar1 p_ar2 p_hansen %9.4f
gen byte diagnostics_pass = p_ar2 > .05 & p_hansen > .05 & instruments < groups
gen byte sign_sig = beta < 0 & p_sim < .05
gen byte fail_count = (beta >= 0) + (p_sim >= .05) + (p_ar2 <= .05) + ///
    (p_hansen <= .05 | missing(p_hansen)) + (instruments >= groups)

display as text ""
display as text "=============================================================================================="
display as text "CORRECTED ROUTE-A SYSTEM-GMM GRID: PRECOMPUTED LAGGED OUTCOME; ORIGINAL sim_mean SCALE"
display as text "=============================================================================================="
count
display as result "Successfully estimated specifications: " r(N)
count if sign_sig == 1
display as result "Negative and 5%-significant sim_mean: " r(N)
count if diagnostics_pass == 1
display as result "AR(2)/Hansen diagnostic passes: " r(N)
count if pass_core == 1
display as result "Core passes (significance plus diagnostics): " r(N)
count if pass_strict == 1
display as result "Strict passes: " r(N)

gsort -pass_strict -pass_core fail_count p_sim -p_ar2 -p_hansen
display as text ""
display as text "All core-passing specifications:"
list ywin lagwin simtype transform laglo laghi beta se p_sim p_ar1 p_ar2 ///
    p_hansen instruments groups observations pass_strict if pass_core == 1, ///
    clean noobs abbreviate(14)

display as text ""
display as text "Twenty closest specifications by predeclared pass/fail criteria (not coefficient target):"
list ywin lagwin simtype transform laglo laghi beta se p_sim p_ar1 p_ar2 ///
    p_hansen instruments groups observations pass_core pass_strict in 1/20, ///
    clean noobs abbreviate(14)

display as text "No persistent result files were created."
