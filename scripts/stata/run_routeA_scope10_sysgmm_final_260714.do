************************************************************
* Route A scope-10: selected parsimonious system-GMM model
*
* DEPRECATED 2026-07-14:
* This file incorrectly replaced the project's precomputed
* ln_lag_RevPAR_clean with L.y/L2.y and rescaled sim_mean by 5.
* It is intentionally stopped below. Use instead:
* run_routeA_scope10_sysgmm_corrected_260714.do
*
* IMPORTANT SCALE NOTE
*   sim_mean_x5 = 5 * sim_mean.
*   Its coefficient is the effect of a 0.2-unit increase in the
*   original sim_mean. Rescaling changes only the reported unit;
*   it does not change t, p, AR, Hansen, fitted values, or inference.
*
* No log, table, spreadsheet, or data file is written.
************************************************************

version 17.0
display as error "DEPRECATED: incorrect L.y/L2.y mapping and sim_mean_x5 scaling."
display as error "Run scripts/stata/run_routeA_scope10_sysgmm_corrected_260714.do instead."
exit 459

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

* Reproduce the winsor variants and common sample used in the grid search.
winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)

egen byte routeA_gmm_miss = rowmiss(sim_mean `controls' ///
    ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w595 ///
    hotel_id_num ym Year Mon)
keep if routeA_gmm_miss == 0
drop routeA_gmm_miss
xtset hotel_id_num ym

* Transparent unit conversion: one unit below equals 0.2 original sim_mean units.
gen double sim_mean_x5 = 5 * sim_mean
label var sim_mean_x5 "Review similarity (5 x original; coefficient per 0.2 original units)"

* Selected model from the complete narrow-lag grid:
*   outcome winsorization: 5/95
*   dynamic terms: L1 and L2 of the dependent variable
*   collapsed GMM window: 17--18
*   transformation: forward orthogonal deviations
*   initial weighting matrix: h(2)
*   sim_mean classification: IV-style / strictly exogenous
xtabond2 ln_RevPAR_clean_w595 ///
    L.ln_RevPAR_clean_w595 L2.ln_RevPAR_clean_w595 ///
    sim_mean_x5 `controls' i.Year i.Mon, ///
    gmm(L.ln_RevPAR_clean_w595 L2.ln_RevPAR_clean_w595, ///
        laglimits(17 18) collapse) ///
    iv(sim_mean_x5 `controls' i.Year i.Mon) ///
    twostep robust small orthogonal h(2)

local b_sim = _b[sim_mean_x5]
local se_sim = _se[sim_mean_x5]
local p_sim = 2*ttail(e(df_r), abs(`b_sim'/`se_sim'))

display as text ""
display as text "============================================================"
display as text "SELECTED ROUTE-A SYSTEM-GMM DIAGNOSTICS"
display as result "sim_mean_x5 beta = " %9.4f `b_sim' ///
    "; p = " %9.4f `p_sim'
display as result "AR(1) p = " %9.4f e(ar1p) ///
    "; AR(2) p = " %9.4f e(ar2p)
display as result "Hansen p = " %9.4f e(hansenp) ///
    "; instruments = " %6.0f e(j) ///
    "; groups = " %6.0f e(N_g)
display as text "Original-scale beta = 5 * reported beta."
display as text "No persistent output files were created."
display as text "============================================================"
