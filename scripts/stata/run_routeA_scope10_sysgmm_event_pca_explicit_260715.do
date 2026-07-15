*******************************************************
* run_routeA_scope10_sysgmm_event_pca_explicit_260715.do
* Route A scope-10: explicit-variable event-sequence
* PCA system GMM.
*
* Style rules follow run_routeA_market_boundaries_260605.do:
* - no regression wrapper program;
* - the complete regression varlist is visible in the command;
* - controls use the same names as the market-boundary file;
* - no hidden control macro or sys_z_* variable appears in the
*   estimating equation.
*
* The existing ln_lag_RevPAR_clean variable is a previous-review-
* event lag. Lag 2 and lag 3 are constructed by hotel event order
* before the Route-A sample restriction. No L.y or L2.y is used.
*
* This do-file writes no log, CSV, RTF, XLSX, or DTA output.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
mata: mata set matafavor speed
capture log close _all

*******************************************************
************ 0. paths and required packages ************
*******************************************************

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_main "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'."
    exit 601
}

capture which xtabond2
if _rc {
    di as error "xtabond2 not found. Install it first: ssc install xtabond2, replace"
    exit 199
}

capture which winsor2
if _rc {
    di as error "winsor2 not found. Install it first: ssc install winsor2, replace"
    exit 199
}

*******************************************************
************ 1. load data and prepare variables ********
*******************************************************

use "`data_main'", clear
di as text "Data source: `data_main'"

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc {
    encode HotelID, gen(hotel_id_num)
}
else {
    gen long hotel_id_num = HotelID
}

capture drop ym
gen int ym = monthly(year_month, "YM")
format ym %tm
sort hotel_id_num ym
isid hotel_id_num ym

* The GMM time index follows review-event order, not calendar months.
capture drop event_seq
by hotel_id_num: gen int event_seq = _n
xtset hotel_id_num event_seq

* Keep the variable names used by run_routeA_market_boundaries_260605.do.
capture drop ln_RevPAR_clean_w595 ln_lag_RevPAR_clean_w199
capture drop ln_lag2_RevPAR_clean_w199 ln_lag3_RevPAR_clean_w199
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)

* Event lag 2 and event lag 3, constructed before Route-A filtering.
by hotel_id_num: gen double ln_lag2_RevPAR_clean_w199 = ///
    ln_lag_RevPAR_clean_w199[_n-1] if _n > 1
by hotel_id_num: gen double ln_lag3_RevPAR_clean_w199 = ///
    ln_lag_RevPAR_clean_w199[_n-2] if _n > 2

* A fixed complete-case sample for every variable in the displayed model.
egen byte routeA_sysgmm_miss = rowmiss(ln_RevPAR_clean_w595 ///
    ln_lag_RevPAR_clean_w199 ln_lag2_RevPAR_clean_w199 ///
    ln_lag3_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ym)
gen byte routeA_sysgmm_cc = cs_sample_focus100 == 1 & ///
    !missing(recent_sd) & routeA_sysgmm_miss == 0
drop routeA_sysgmm_miss

quietly count if routeA_sysgmm_cc == 1
di as result "Event-lag common sample: " %12.0fc r(N)

*******************************************************
************ 2. explicit Route A system GMM ************
*******************************************************

* All dynamic terms, focal variable, and controls are written
* explicitly. Calendar-month effects enter as i.ym.
noisily xtabond2 ln_RevPAR_clean_w595 ///
    ln_lag_RevPAR_clean_w199 ln_lag2_RevPAR_clean_w199 ///
    ln_lag3_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR i.ym ///
    if routeA_sysgmm_cc == 1, ///
    gmm(ln_lag_RevPAR_clean_w199 ln_lag2_RevPAR_clean_w199 ///
        ln_lag3_RevPAR_clean_w199, laglimits(3 5) split) ///
    iv(sim_mean ln_recent_volumn recent_sd recent_rating ///
       ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
       ln_avg_com_RevPAR i.ym) ///
    robust small h(3) pca

noisily xtabond2 ln_RevPAR_clean_w595 ///
    sim_mean ///
    ln_recent_volumn recent_sd recent_rating rating_last_5 ///
	ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
	ln_lag_RevPAR_clean_w199 ln_lag2_RevPAR_clean_w199 ///
    ln_lag3_RevPAR_clean_w199 i.ym ///
    if routeA_sysgmm_cc == 1, ///
    gmm(ln_lag_RevPAR_clean_w199 ln_lag2_RevPAR_clean_w199 ///
        ln_lag3_RevPAR_clean_w199, laglimits(3 5) split) ///
    iv(sim_mean ln_recent_volumn recent_sd recent_rating ///
       ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
       ln_avg_com_RevPAR i.ym) ///
    robust small h(3) pca
	
	
* 保存回归结果
est store sysgmm_model
* 导出RTF
esttab sysgmm_model using "sysgmm_result.rtf", ///
    replace ///
    rtf ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    drop(ln_lag2_RevPAR_clean_w199 ln_lag3_RevPAR_clean_w199 *.ym) ///
    stats(N, fmt(%9.0f) labels("Observations")) ///
    title("System GMM Regression Results")
	
local b_sim = _b[sim_mean]
local se_sim = _se[sim_mean]
local p_sim = 2 * ttail(e(df_r), abs(`b_sim' / `se_sim'))
local core_pass = (`b_sim' < 0 & `p_sim' < .05 & ///
    e(ar2p) > .05 & e(hansenp) > .05 & !missing(e(hansenp)) & ///
    e(j) < e(N_g))

di as text ""
di as text "============================================================"
di as text "EXPLICIT-VARIABLE SYS-GMM VERIFICATION"
di as result "sim_mean beta : " %10.6f `b_sim'
di as result "sim_mean SE   : " %10.6f `se_sim'
di as result "sim_mean p    : " %10.7f `p_sim'
di as result "AR(1) p       : " %10.7f e(ar1p)
di as result "AR(2) p       : " %10.7f e(ar2p)
di as result "Hansen p      : " %10.7f e(hansenp)
di as result "Sargan p      : " %10.7f e(sarganp)
di as result "Instruments   : " %10.0f e(j)
di as result "Hotels        : " %10.0f e(N_g)
di as result "Observations  : " %10.0f e(N)
di as result "Core pass     : " %10.0f `core_pass'
di as text "============================================================"
di as text "Caution: PCA suppresses Difference-in-Hansen subset tests."
di as text "No persistent result files were created."

