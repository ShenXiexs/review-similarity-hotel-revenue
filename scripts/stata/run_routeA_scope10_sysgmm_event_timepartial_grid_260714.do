************************************************************
* Route A scope-10: event-sequence lag system-GMM with exact
* calendar-month effects partialled out before estimation.
*
* Complete grid; original sim_mean scale; no target sorting.
* No log, CSV, RTF, XLSX, or DTA is written.
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

use "`data_main'", clear
capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID

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
    gen double et_y_`cut' = min(max(ln_RevPAR_clean, r(r1)), r(r2)) if !missing(ln_RevPAR_clean)

    quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_lag_RevPAR_clean), p(`plo' `phi')
    gen double et_l1_`cut' = min(max(ln_lag_RevPAR_clean, r(r1)), r(r2)) if !missing(ln_lag_RevPAR_clean)
    by hotel_id_num: gen double et_l2_`cut' = et_l1_`cut'[_n-1] if _n > 1
    by hotel_id_num: gen double et_l3_`cut' = et_l1_`cut'[_n-2] if _n > 2
}

egen byte routeA_miss = rowmiss(sim_mean `controls' ///
    et_y_199 et_y_195 et_y_595 ///
    et_l1_199 et_l1_195 et_l1_595 ///
    et_l2_199 et_l2_195 et_l2_595 ///
    et_l3_199 et_l3_195 et_l3_595 hotel_id_num ym)
gen byte routeA_cc = cs_sample_focus100 == 1 & !missing(recent_sd_10) & routeA_miss == 0
drop routeA_miss

quietly count if routeA_cc
display as result "Event-lag-3 common sample: " r(N)

* Partial out exact calendar-month effects on the fixed common sample.
foreach v in sim_mean `controls' ///
    et_y_199 et_y_195 et_y_595 ///
    et_l1_199 et_l1_195 et_l1_595 ///
    et_l2_199 et_l2_195 et_l2_595 ///
    et_l3_199 et_l3_195 et_l3_595 {
    bysort ym: egen double et_m_`v' = mean(`v') if routeA_cc
    gen double et_z_`v' = `v' - et_m_`v' if routeA_cc
    drop et_m_`v'
}

local zcontrols "et_z_recent_sd_10 et_z_ln_recent_volumn_10 et_z_recent_rating_10 et_z_ln_lag_volumn_acc et_z_lag_avg_rating_acc et_z_lag_sd_acc et_z_ln_avg_com_RevPAR"

tempfile scan
postutil clear
postfile G str4 ywin str4 lagwin str4 transform int instlag ///
    double beta se p_sim p_ar1 p_ar2 p_hansen p_sargan ///
    instruments groups observations byte pass_core byte pass_strict ///
    using `scan', replace

foreach yw in 199 195 595 {
    foreach lw in 199 195 595 {
        foreach k in 2 3 4 5 6 {
            foreach tr in diff orth {
                local tr_opt ""
                if "`tr'" == "orth" local tr_opt "orthogonal"

                capture quietly xtabond2 et_z_et_y_`yw' ///
                    et_z_et_l1_`lw' et_z_et_l2_`lw' et_z_et_l3_`lw' ///
                    et_z_sim_mean `zcontrols' if routeA_cc, ///
                    gmm(et_z_et_l1_`lw' et_z_et_l2_`lw' et_z_et_l3_`lw', ///
                        laglimits(`k' `k') collapse) ///
                    iv(et_z_sim_mean `zcontrols') ///
                    twostep robust small `tr_opt'

                if _rc == 0 {
                    local b = _b[et_z_sim_mean]
                    local s = _se[et_z_sim_mean]
                    local pv = 2*ttail(e(df_r), abs(`b'/`s'))
                    local pc = (`b' < 0 & `pv' < .05 & e(ar2p) > .05 & ///
                        e(hansenp) > .05 & e(j) < e(N_g))
                    local ps = (`pc' == 1 & e(ar1p) < .05 & e(ar2p) > .10 & ///
                        e(hansenp) >= .10 & e(hansenp) <= .80)
                    post G ("`yw'") ("`lw'") ("`tr'") (`k') ///
                        (`b') (`s') (`pv') (e(ar1p)) (e(ar2p)) ///
                        (e(hansenp)) (e(sarganp)) (e(j)) (e(N_g)) (e(N)) ///
                        (`pc') (`ps')
                }
            }
        }
    }
}
postclose G

use `scan', clear
format beta se p_sim p_ar1 p_ar2 p_hansen p_sargan %9.4f
count
display as result "Estimated cells: " r(N)
count if pass_core
display as result "Core passes: " r(N)
count if pass_strict
display as result "Strict passes: " r(N)

gsort -pass_strict -pass_core p_sim -p_ar2 -p_hansen
list ywin lagwin transform instlag beta se p_sim p_ar1 p_ar2 p_hansen ///
    p_sargan instruments groups observations pass_strict if pass_core, ///
    clean noobs abbreviate(14)

display as text "No persistent result files were created."
