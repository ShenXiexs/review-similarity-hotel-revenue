************************************************************
* Route A scope-10: final event-sequence PCA system GMM
*
* Key definitions:
*   - The first revenue lag is the existing
*     ln_lag_RevPAR_clean variable.
*   - Lag 2 and lag 3 are constructed by hotel event order on
*     the full panel before the Route-A sample is marked.
*   - xtset uses event_seq. No calendar-time L.y/L2.y is used.
*   - sim_mean remains on its original scale.
*   - Calendar-month common components are removed by
*     cross-sectional demeaning within ym on the fixed common
*     estimation sample.
*
* Final selected specification:
*   outcome winsor: 5/95
*   revenue-lag winsor: 1/99
*   event revenue lags in the equation: 1, 2, and 3
*   GMM instrument window: event lags 3 through 5
*   instrument reduction: xtabond2's default PCA rule
*   estimator: one-step system GMM, robust small-sample VCE
*
* Reproducibility cautions:
*   - The verified run retained 371 instruments for 556 hotels.
*   - PCA mode does not report Difference-in-Hansen subset tests.
*   - Cross-sectional ym demeaning is not algebraically identical
*     to jointly estimating i.ym inside an unbalanced system GMM.
*   - The non-robust Sargan test rejects; inference below uses
*     the heteroskedasticity-robust Hansen test requested for the
*     core diagnostic.
*
* This do-file creates no log, CSV, RTF, XLSX, or DTA output.
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
if _rc {
    display as error "Data not found: `data_main'"
    exit 601
}

capture which xtabond2
if _rc {
    display as error "xtabond2 is required. Install it once before running this file."
    exit 199
}

use "`data_main'", clear

* Panel identifiers and the correct review-event clock.
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID

gen int ym = monthly(year_month, "YM")
format ym %tm
sort hotel_id_num ym
isid hotel_id_num ym
by hotel_id_num: gen int event_seq = _n
xtset hotel_id_num event_seq

* Estimate the requested winsor cutoffs on the Route-A sample,
* then apply them without deleting earlier panel histories.
quietly _pctile ln_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_RevPAR_clean), ///
    p(5 95)
local y_lo = r(r1)
local y_hi = r(r2)
gen double sys_y595 = min(max(ln_RevPAR_clean, `y_lo'), `y_hi') ///
    if !missing(ln_RevPAR_clean)

quietly _pctile ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_lag_RevPAR_clean), ///
    p(1 99)
local lag_lo = r(r1)
local lag_hi = r(r2)
gen double sys_lag1_199 = min(max(ln_lag_RevPAR_clean, `lag_lo'), `lag_hi') ///
    if !missing(ln_lag_RevPAR_clean)

* These are review-event lags, not calendar-month L. operators.
by hotel_id_num: gen double sys_lag2_199 = sys_lag1_199[_n-1] if _n > 1
by hotel_id_num: gen double sys_lag3_199 = sys_lag1_199[_n-2] if _n > 2

* One fixed common sample for all transformations and moments.
egen byte routeA_sysgmm_miss = rowmiss(sys_y595 ///
    sys_lag1_199 sys_lag2_199 sys_lag3_199 ///
    sim_mean `controls' hotel_id_num ym)
gen byte routeA_sysgmm_cc = cs_sample_focus100 == 1 & ///
    !missing(recent_sd_10) & routeA_sysgmm_miss == 0
drop routeA_sysgmm_miss

quietly count if routeA_sysgmm_cc == 1
local routeA_N = r(N)
display as result "Fixed event-lag common sample N = " %12.0fc `routeA_N'
if `routeA_N' != 32435 {
    display as error "Warning: verified run used N=32,435; current data give N=`routeA_N'."
}

* Remove exact calendar-month means on that fixed sample.
foreach v in sys_y595 sys_lag1_199 sys_lag2_199 sys_lag3_199 ///
    sim_mean `controls' {
    bysort ym: egen double sys_m_`v' = mean(`v') if routeA_sysgmm_cc == 1
    gen double sys_z_`v' = `v' - sys_m_`v' if routeA_sysgmm_cc == 1
    drop sys_m_`v'
}

local zcontrols sys_z_recent_sd_10 sys_z_ln_recent_volumn_10 ///
    sys_z_recent_rating_10 sys_z_ln_lag_volumn_acc ///
    sys_z_lag_avg_rating_acc sys_z_lag_sd_acc ///
    sys_z_ln_avg_com_RevPAR

display as text ""
display as text "Running the final event-sequence PCA system-GMM specification..."

noisily xtabond2 sys_z_sys_y595 ///
    sys_z_sys_lag1_199 sys_z_sys_lag2_199 sys_z_sys_lag3_199 ///
    sys_z_sim_mean `zcontrols' if routeA_sysgmm_cc == 1, ///
    gmm(sys_z_sys_lag1_199 sys_z_sys_lag2_199 sys_z_sys_lag3_199, ///
        laglimits(3 5) split) ///
    iv(sys_z_sim_mean `zcontrols') ///
    robust small h(3) pca

* Compact verification block in the Results window only.
local b_sim = _b[sys_z_sim_mean]
local se_sim = _se[sys_z_sim_mean]
local p_sim = 2 * ttail(e(df_r), abs(`b_sim' / `se_sim'))
local core_pass = (`b_sim' < 0 & `p_sim' < .05 & ///
    e(ar2p) > .05 & e(hansenp) > .05 & !missing(e(hansenp)) & ///
    e(j) < e(N_g))

display as text ""
display as text "============================================================"
display as text "FINAL VERIFICATION (sim_mean is on its original scale)"
display as result "sim_mean beta : " %10.6f `b_sim'
display as result "sim_mean SE   : " %10.6f `se_sim'
display as result "sim_mean p    : " %10.7f `p_sim'
display as result "AR(1) p       : " %10.7f e(ar1p)
display as result "AR(2) p       : " %10.7f e(ar2p)
display as result "Hansen p      : " %10.7f e(hansenp)
display as result "Sargan p      : " %10.7f e(sarganp)
display as result "Instruments   : " %10.0f e(j)
display as result "Hotels        : " %10.0f e(N_g)
display as result "Observations  : " %10.0f e(N)
display as result "Core pass     : " %10.0f `core_pass'
display as text "============================================================"
display as text "Caution: PCA suppresses Difference-in-Hansen subset tests."
display as text "No persistent result files were created."
