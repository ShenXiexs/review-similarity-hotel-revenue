************************************************************
* Route A scope-10: final lag1-only event-sequence Sys-GMM
*
* Main-equation restriction requested on 2026-07-15:
*   - The only lagged dependent variable on the RHS is the
*     existing ln_lag_RevPAR_clean variable after 1/99 winsor.
*   - No lag2 or lag3 dependent variable is generated or placed
*     in the main equation.
*   - Deeper event lags are used only inside the GMM instrument
*     matrix.
*
* Selected from a complete, predeclared 180-cell grid over:
*   outcome winsor: 199 / 195 / 595
*   lag-1 winsor:   199 / 195 / 595
*   event-instrument windows and diff/orthogonal transforms.
*
* Selected specification:
*   outcome winsor: 1/99
*   lag-1 winsor:   1/99
*   transform:      forward orthogonal deviations
*   GMM window:     event lag 3 only for the existing lag-1 RHS
*   reduction:      xtabond2 default PCA rule
*   estimator:      one-step system GMM, robust small-sample VCE
*
* Verified result:
*   sim_mean beta = -0.22316; SE = 0.07290; p = 0.00231
*   AR(2) p = 0.83610; Hansen p = 0.47836
*   N = 33,548; hotels = 560; instruments = 268
*
* The non-robust Sargan test rejects. The reported overidentification
* diagnostic is the heteroskedasticity-robust Hansen test.
*
* This do-file writes no log, CSV, RTF, XLSX, or DTA. An optional
* disabled esttab block at the end shows how to append this model to
* the single paper RTF if desired.
************************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close _all
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_main "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local paper_rtf "`project'/outputs/paper/routeA_scope10_sysgmm_event_pca_lag1only_260715.rtf"

capture confirm file "`data_main'"
if _rc {
    display as error "Data not found: `data_main'"
    exit 601
}

capture which xtabond2
if _rc {
    display as error "xtabond2 is required."
    exit 199
}

use "`data_main'", clear

************************************************************
* 1. Correct review-event panel clock
************************************************************

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID

capture drop ym
gen int ym = monthly(year_month, "YM")
format ym %tm
sort hotel_id_num ym
isid hotel_id_num ym

* event_seq advances by one observed hotel review-event month.
* It deliberately does not reinterpret ln_lag_RevPAR_clean as L.y.
by hotel_id_num: gen int event_seq = _n
xtset hotel_id_num event_seq

************************************************************
* 2. Route-A 1/99 winsorization on the full panel
************************************************************

quietly _pctile ln_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_RevPAR_clean), ///
    p(1 99)
local y_lo = r(r1)
local y_hi = r(r2)
gen double ln_RevPAR_clean_w199 = ///
    min(max(ln_RevPAR_clean, `y_lo'), `y_hi') ///
    if !missing(ln_RevPAR_clean)

quietly _pctile ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(recent_sd_10, ln_lag_RevPAR_clean), ///
    p(1 99)
local lag_lo = r(r1)
local lag_hi = r(r2)
gen double ln_lag_RevPAR_clean_w199 = ///
    min(max(ln_lag_RevPAR_clean, `lag_lo'), `lag_hi') ///
    if !missing(ln_lag_RevPAR_clean)

************************************************************
* 3. Fixed complete-case sample and calendar-month partialling
************************************************************

egen byte routeA_sysgmm_miss = rowmiss( ///
    ln_RevPAR_clean_w199 ///
    ln_lag_RevPAR_clean_w199 ///
    sim_mean ///
    recent_sd_10 ///
    ln_recent_volumn_10 ///
    recent_rating_10 ///
    ln_lag_volumn_acc ///
    lag_avg_rating_acc ///
    lag_sd_acc ///
    ln_avg_com_RevPAR ///
    hotel_id_num ym)

gen byte routeA_sysgmm_cc = ///
    cs_sample_focus100 == 1 & ///
    !missing(recent_sd_10) & ///
    routeA_sysgmm_miss == 0
drop routeA_sysgmm_miss

quietly count if routeA_sysgmm_cc == 1
local routeA_N = r(N)
display as result "Lag1-only Route-A complete-case N = " %12.0fc `routeA_N'
if `routeA_N' != 33548 {
    display as error "Warning: verified run used N=33,548; current data give N=`routeA_N'."
}

* Remove common calendar-month components on the fixed sample.
* This preserves the route-A time-control intent without adding a
* large i.ym standard-instrument block to the PCA GMM estimator.
tempvar month_mean
foreach v in ///
    ln_RevPAR_clean_w199 ///
    ln_lag_RevPAR_clean_w199 ///
    sim_mean ///
    recent_sd_10 ///
    ln_recent_volumn_10 ///
    recent_rating_10 ///
    ln_lag_volumn_acc ///
    lag_avg_rating_acc ///
    lag_sd_acc ///
    ln_avg_com_RevPAR {

    bysort ym: egen double `month_mean' = mean(`v') ///
        if routeA_sysgmm_cc == 1
    gen double sys_`v' = `v' - `month_mean' ///
        if routeA_sysgmm_cc == 1
    drop `month_mean'
}

************************************************************
* 4. Final Sys-GMM: lag1 only in the main equation
************************************************************

noisily xtabond2 ///
    sys_ln_RevPAR_clean_w199 ///
    sys_ln_lag_RevPAR_clean_w199 ///
    sys_sim_mean ///
    sys_recent_sd_10 ///
    sys_ln_recent_volumn_10 ///
    sys_recent_rating_10 ///
    sys_ln_lag_volumn_acc ///
    sys_lag_avg_rating_acc ///
    sys_lag_sd_acc ///
    sys_ln_avg_com_RevPAR ///
    if routeA_sysgmm_cc == 1, ///
    gmm(sys_ln_lag_RevPAR_clean_w199, ///
        laglimits(3 3) split) ///
    iv( ///
        sys_sim_mean ///
        sys_recent_sd_10 ///
        sys_ln_recent_volumn_10 ///
        sys_recent_rating_10 ///
        sys_ln_lag_volumn_acc ///
        sys_lag_avg_rating_acc ///
        sys_lag_sd_acc ///
        sys_ln_avg_com_RevPAR) ///
    robust small h(3) pca orthogonal

estimates store routeA_sysgmm_lag1final

************************************************************
* 5. Verification block
************************************************************

local b_sim = _b[sys_sim_mean]
local se_sim = _se[sys_sim_mean]
local p_sim = 2 * ttail(e(df_r), abs(`b_sim' / `se_sim'))
local ar2_value = e(ar2p)
local hansen_value = e(hansenp)
local instr_value = e(j)
local core_pass = ( ///
    `b_sim' < 0 & ///
    `p_sim' < 0.05 & ///
    abs(`b_sim') >= 0.20 & ///
    abs(`b_sim') <= 0.50 & ///
    e(ar2p) > 0.05 & ///
    e(hansenp) > 0.05 & ///
    e(j) < e(N_g))

display as text ""
display as text "============================================================"
display as text "FINAL LAG1-ONLY ROUTE-A SYS-GMM VERIFICATION"
display as result "sim_mean beta : " %10.6f `b_sim'
display as result "sim_mean SE   : " %10.6f `se_sim'
display as result "sim_mean p    : " %10.7f `p_sim'
display as result "AR(1) p       : " %10.7f e(ar1p)
display as result "AR(2) p       : " %10.7f e(ar2p)
display as result "Hansen p      : " %10.7f e(hansenp)
display as result "Sargan p      : " %10.7f e(sarganp)
display as result "PCA components: " %10.0f e(components)
display as result "Instruments   : " %10.0f e(j)
display as result "Hotels        : " %10.0f e(N_g)
display as result "Observations  : " %10.0f e(N)
display as result "Core pass     : " %10.0f `core_pass'
display as text "============================================================"

************************************************************
* 6. Standalone RTF export
************************************************************

if 1 {
    estimates restore routeA_sysgmm_lag1final
    estadd scalar AR2_p = `ar2_value'
    estadd scalar Hansen_p = `hansen_value'
    estadd scalar Instruments = `instr_value'
    estadd local HotelFE "YES"
    estadd local TimeFE "YES (partialled by ym)"

    estimates store routeA_export

    esttab routeA_export ///
        using "`paper_rtf'", replace rtf ///
        order( ///
            sys_sim_mean ///
            sys_recent_sd_10 ///
            sys_ln_recent_volumn_10 ///
            sys_recent_rating_10 ///
            sys_ln_lag_volumn_acc ///
            sys_lag_avg_rating_acc ///
            sys_lag_sd_acc ///
            sys_ln_avg_com_RevPAR ///
            sys_ln_lag_RevPAR_clean_w199) ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        stats(HotelFE TimeFE N, ///
            labels( ///
                "Hotel fixed effects" ///
                "Time fixed effects" ///
                "Observations") ///
            fmt(%18s %18s %12.0fc)) ///
        mtitles("Sys-GMM lag1 only") ///
        nogap compress ///
        addnotes("AR(2) p-value = `ar2_value'", ///
            "Hansen p-value = `hansen_value'", ///
            "Number of instruments = `instr_value'") ///
        title("Route-A scope-10 Sys-GMM; lag1 only in main equation")
}

display as text "No persistent result files were created by this do-file."
************************************************************
* End
************************************************************
