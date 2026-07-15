************************************************************
* Route A scope-10: extended, narrow-lag system-GMM grid
*
* No persistent log/table/data output is created. Results are
* held in a tempfile and printed in the Stata Results window.
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
if _rc exit 601
capture which xtabond2
if _rc exit 199
capture which winsor2
if _rc exit 199

use "`data_main'", clear
keep if cs_sample_focus100 == 1 & !missing(recent_sd_10)

capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID

gen int ym = monthly(year_month, "YM")
format ym %tm
sort hotel_id_num ym
isid hotel_id_num ym
xtset hotel_id_num ym

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)

local controls "recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR"

* Common estimation base across all outcome variants.
egen byte routeA_gmm_miss = rowmiss(sim_mean `controls' ///
    ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595 ///
    hotel_id_num ym Year Mon)
keep if routeA_gmm_miss == 0
drop routeA_gmm_miss
xtset hotel_id_num ym

tempfile scan
postutil clear
postfile G str4 ywin str3 dyn str5 transform byte htype int laglo int laghi ///
    double beta se p_ar1 p_ar2 p_hansen instruments groups observations ///
    byte pass_core byte pass_strict using `scan', replace

foreach yw in 199 195 595 {
    foreach dyn in L1 L12 {
        local dyn_rhs "L.ln_RevPAR_clean_w`yw'"
        if "`dyn'" == "L12" local dyn_rhs "L.ln_RevPAR_clean_w`yw' L2.ln_RevPAR_clean_w`yw'"

        foreach tr in diff orth {
            local tr_opt ""
            if "`tr'" == "orth" local tr_opt "orthogonal"

            foreach hh in 2 3 {
                forvalues lo = 2/18 {
                    local hi = `lo' + 1

                    capture quietly xtabond2 ln_RevPAR_clean_w`yw' ///
                        `dyn_rhs' sim_mean `controls' i.Year i.Mon, ///
                        gmm(`dyn_rhs', laglimits(`lo' `hi') collapse) ///
                        iv(sim_mean `controls' i.Year i.Mon) ///
                        twostep robust small `tr_opt' h(`hh')

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

                        local pc = (!missing(`han') & `b' < 0 & `pv' < .05 & ///
                            `ar2' > .05 & `han' > .05 & `jj' < `ng')
                        local ps = (`pc' == 1 & `ar1' < .05 & `ar2' > .10 & ///
                            `han' >= .10 & `han' <= .80)

                        post G ("`yw'") ("`dyn'") ("`tr'") (`hh') (`lo') (`hi') ///
                            (`b') (`s') (`ar1') (`ar2') (`han') (`jj') (`ng') (`nn') (`pc') (`ps')
                    }
                }
            }
        }
    }
}
postclose G

use `scan', clear
gen double p_sim = 2*ttail(groups - 1, abs(beta/se))
gen double target_gap = abs(beta + .30)
gen double hansen_gap = cond(missing(p_hansen), 9, max(0, .05 - p_hansen))
gen byte sign_sig = beta < 0 & p_sim < .05
gen byte serial_ok = p_ar1 < .05 & p_ar2 > .05
gen byte near_pass = sign_sig & serial_ok
format beta se p_sim target_gap p_ar1 p_ar2 p_hansen %9.4f

gsort -pass_strict -pass_core -near_pass target_gap hansen_gap p_sim instruments

display as text ""
display as text "================================================================================================================"
display as text "EXTENDED NARROW-LAG SYSTEM-GMM GRID"
display as text "Coefficient target (-0.30) affects ranking only; it is not a pass condition."
display as text "================================================================================================================"
count
display as result "Estimated models: " r(N)
count if pass_core == 1
local n_core = r(N)
display as result "Core passes: " r(N)
count if pass_strict == 1
local n_strict = r(N)
display as result "Strict passes: " r(N)

display as text ""
display as text "Top 30 models, ranked by diagnostics first and proximity to beta=-0.30 second:"
list ywin dyn transform htype laglo laghi beta se p_sim target_gap p_ar1 p_ar2 p_hansen ///
    instruments groups observations pass_core pass_strict in 1/30, clean noobs abbreviate(16)

if `n_core' > 0 {
    local best_y  = ywin[1]
    local best_d  = dyn[1]
    local best_t  = transform[1]
    local best_h  = htype[1]
    local best_lo = laglo[1]
    local best_hi = laghi[1]
    local best_dyn "L.ln_RevPAR_clean_w`best_y'"
    if "`best_d'" == "L12" local best_dyn "L.ln_RevPAR_clean_w`best_y' L2.ln_RevPAR_clean_w`best_y'"
    local best_tr ""
    if "`best_t'" == "orth" local best_tr "orthogonal"

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

    * Recreate the exact common-sample panel used by the scan before rerunning.
    egen byte routeA_gmm_miss = rowmiss(sim_mean `controls' ///
        ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595 ///
        hotel_id_num ym Year Mon)
    keep if routeA_gmm_miss == 0
    drop routeA_gmm_miss
    xtset hotel_id_num ym

    display as text ""
    display as text "Best passing model rerun with complete xtabond2 output:"
    noisily xtabond2 ln_RevPAR_clean_w`best_y' ///
        `best_dyn' sim_mean `controls' i.Year i.Mon, ///
        gmm(`best_dyn', laglimits(`best_lo' `best_hi') collapse) ///
        iv(sim_mean `controls' i.Year i.Mon) ///
        twostep robust small `best_tr' h(`best_h')
}
else {
    display as error "No extended-lag model passes AR(2) and Hansen jointly. Nothing is adopted."
}

display as text "No persistent output files were created."
