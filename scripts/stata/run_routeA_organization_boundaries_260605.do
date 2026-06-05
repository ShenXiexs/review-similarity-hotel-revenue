*******************************************************
* run_routeA_organization_boundaries_260605.do
* Route A extension: ARS as the main effect, with
* organization-form boundaries from chain structure.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
mata: mata set matafavor speed
capture log close

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/core_simi_260501"
local data_dir "`out_root'/data"
local table_dir "`out_root'/tables_explicit"
local csv_dir "`out_root'/csv"
local log_dir "`out_root'/logs"
local run_id "260605"
local data_main "`data_dir'/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"

cap mkdir "`table_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`log_dir'"

capture confirm file "`data_main'"
if _rc exit 601
capture which reghdfe
if _rc exit 199
capture which esttab
if _rc exit 199

use "`data_main'", clear
log using "`log_dir'/run_routeA_organization_boundaries_`run_id'.log", text replace

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

capture drop ln_RevPAR_clean_w199 ln_lag_RevPAR_clean_w199 sim_mean_c
gen double ln_RevPAR_clean_w199 = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w199 = ln_lag_RevPAR_clean
quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local y_p1 = r(r1)
local y_p99 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local ly_p1 = r(r1)
local ly_p99 = r(r2)
replace ln_RevPAR_clean_w199 = `y_p1' if ln_RevPAR_clean_w199 < `y_p1' & !missing(ln_RevPAR_clean_w199)
replace ln_RevPAR_clean_w199 = `y_p99' if ln_RevPAR_clean_w199 > `y_p99' & !missing(ln_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p1' if ln_lag_RevPAR_clean_w199 < `ly_p1' & !missing(ln_lag_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p99' if ln_lag_RevPAR_clean_w199 > `ly_p99' & !missing(ln_lag_RevPAR_clean_w199)
quietly summarize sim_mean if cs_sample_focus100 == 1 & !missing(sim_mean)
gen double sim_mean_c = sim_mean - r(mean) if !missing(sim_mean)

estimates clear

* O1. Chain versus non-chain boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.chain ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(chain), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chain

* O2. Independent-hotel boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.independent ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(independent), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_indep

* O3. Small-chain boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.chain_small ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(chain_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_chsmall

* O4. Three-property chain boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.chain3_small ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(chain3_small), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store org_ch3

esttab org_chain org_indep org_chsmall org_ch3 using "`table_dir'/routeA_organization_boundaries_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("chain" "independent" "chain small" "chain3 small") nogap compress
esttab org_chain org_indep org_chsmall org_ch3 using "`csv_dir'/routeA_organization_boundaries_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("chain" "independent" "chain small" "chain3 small") nogap

log close
