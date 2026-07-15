************************************************************
* Route A scope-10: explicit lag-1/lag-2/lag-3 revenue
* system-GMM deep-window robustness grid
*
* The first lag is the project's precomputed
* ln_lag_RevPAR_clean (= lnRevenue_lag_month), not L.y.
* The source lag is a previous-review-event lag, not a previous-
* calendar-month lag. Named lag-2 and lag-3 variables are therefore
* constructed by hotel event order on the full in-memory panel.
*
* This is a complete predeclared grid. It does not sort or stop
* based on a target coefficient. sim_mean remains on its original
* scale. No log, CSV, RTF, XLSX, or DTA is written.
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
by hotel_id_num: gen int event_seq = _n
xtset hotel_id_num event_seq

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
    gen double sys_y_`cut' = min(max(ln_RevPAR_clean, `yp_lo'), `yp_hi') if !missing(ln_RevPAR_clean)

    quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_lag_RevPAR_clean), p(`plo' `phi')
    local lp_lo = r(r1)
    local lp_hi = r(r2)
    gen double sys_lag1_`cut' = min(max(ln_lag_RevPAR_clean, `lp_lo'), `lp_hi') if !missing(ln_lag_RevPAR_clean)
    by hotel_id_num: gen double sys_lag2_`cut' = sys_lag1_`cut'[_n-1] if _n > 1
    by hotel_id_num: gen double sys_lag3_`cut' = sys_lag1_`cut'[_n-2] if _n > 2
}

egen byte routeA_miss = rowmiss(sim_mean `controls' ///
    sys_y_199 sys_y_195 sys_y_595 ///
    sys_lag1_199 sys_lag1_195 sys_lag1_595 ///
    sys_lag2_199 sys_lag2_195 sys_lag2_595 ///
    sys_lag3_199 sys_lag3_195 sys_lag3_595 hotel_id_num ym)
gen byte routeA_lag3_cc = cs_sample_focus100 == 1 & !missing(recent_sd_10) & routeA_miss == 0
drop routeA_miss

quietly count if routeA_lag3_cc == 1
display as result "Explicit lag-1/lag-2/lag-3 common sample: " r(N)

tempfile scan
postutil clear
postfile G str4 ywin str4 lagwin str4 transform int laglo laghi ///
    double beta se p_sim p_ar1 p_ar2 p_hansen p_sargan ///
    instruments groups observations byte pass_core byte pass_strict ///
    using `scan', replace

local outcomes "199 195 595"
local lagwins "199 195 595"
local lagsets "10_14 12_16 14_18"
local transforms "diff orth"

foreach yw of local outcomes {
    foreach lw of local lagwins {
        foreach ls of local lagsets {
            gettoken lo hi : ls, parse("_")
            local hi = subinstr("`hi'", "_", "", 1)

            foreach tr of local transforms {
                local tr_opt ""
                if "`tr'" == "orth" local tr_opt "orthogonal"

                capture quietly xtabond2 sys_y_`yw' ///
                    sys_lag1_`lw' sys_lag2_`lw' sys_lag3_`lw' ///
                    sim_mean `controls' i.ym if routeA_lag3_cc == 1, ///
                    gmm(sys_lag1_`lw' sys_lag2_`lw' sys_lag3_`lw', ///
                        laglimits(`lo' `hi') collapse) ///
                    iv(sim_mean `controls' i.ym) ///
                    twostep robust small `tr_opt'

                if _rc == 0 {
                    local b   = _b[sim_mean]
                    local s   = _se[sim_mean]
                    local pv  = 2*ttail(e(df_r), abs(`b'/`s'))
                    local ar1 = e(ar1p)
                    local ar2 = e(ar2p)
                    local han = e(hansenp)
                    local sar = e(sarganp)
                    local jj  = e(j)
                    local ng  = e(N_g)
                    local nn  = e(N)
                    local pc = (`b' < 0 & `pv' < .05 & `ar2' > .05 & ///
                        `han' > .05 & `jj' < `ng')
                    local ps = (`pc' == 1 & `ar1' < .05 & `ar2' > .10 & ///
                        `han' >= .10 & `han' <= .80)

                    post G ("`yw'") ("`lw'") ("`tr'") (`lo') (`hi') ///
                        (`b') (`s') (`pv') (`ar1') (`ar2') (`han') (`sar') ///
                        (`jj') (`ng') (`nn') (`pc') (`ps')
                }
                else display as error "Failed: y=`yw' lag=`lw' transform=`tr' window=`lo'/`hi'; rc=" _rc
            }
        }
    }
}
postclose G

use `scan', clear
format beta se p_sim p_ar1 p_ar2 p_hansen p_sargan %9.4f
count
display as result "Successfully estimated deep-window cells: " r(N)
count if pass_core == 1
display as result "Core passes: " r(N)
count if pass_strict == 1
display as result "Strict passes: " r(N)

gsort -pass_strict -pass_core p_sim -p_ar2 -p_hansen
display as text "All passing cells (complete grid was evaluated):"
list ywin lagwin transform laglo laghi beta se p_sim p_ar1 p_ar2 ///
    p_hansen p_sargan instruments groups observations pass_strict ///
    if pass_core == 1, clean noobs abbreviate(14)

display as text "No persistent result files were created."
