*******************************************************
* run_routeA_market_boundaries_260605.do
* Route A extension: ARS as the main effect, with market
* structure and competitive-position boundaries.
*
* Style rules:
* - No regression wrapper program.
* - Every regression writes the DV, focal variables,
*   controls, FE, and clustering explicitly.
* - Comments explain the research question before each
*   model block.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
mata: mata set matafavor speed
capture log close

*******************************************************
************ 0. paths and required packages ************
*******************************************************

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
if _rc {
    di as error "Cannot find `data_main'."
    exit 601
}

capture which reghdfe
if _rc {
    di as error "reghdfe not found. Install it first: ssc install reghdfe, replace"
    exit 199
}

capture which esttab
if _rc {
    di as error "esttab not found. Install it first: ssc install estout, replace"
    exit 199
}

*******************************************************
************ 1. load data and prepare variables ********
*******************************************************

use "`data_main'", clear
log using "`log_dir'/run_routeA_market_boundaries_`run_id'.log", text replace

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
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

capture drop ln_RevPAR_clean_w199 ln_lag_RevPAR_clean_w199
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

* Center variables so lower-order coefficients are interpretable at the focus100 sample mean.
capture drop sim_mean_c zip_n_full_c city_n_full_c zip_n_review_c city_n_review_c
capture drop ln_comp_zip_full_c ln_comp_city_full_c gap_zip_full_c gap_city_full_c
capture drop gap_zip_review_c gap_city_review_c price_gap_c

quietly summarize sim_mean if cs_sample_focus100 == 1 & !missing(sim_mean)
gen double sim_mean_c = sim_mean - r(mean) if !missing(sim_mean)

quietly summarize zip_n_full if cs_sample_focus100 == 1 & !missing(zip_n_full)
gen double zip_n_full_c = zip_n_full - r(mean) if !missing(zip_n_full)

quietly summarize city_n_full if cs_sample_focus100 == 1 & !missing(city_n_full)
gen double city_n_full_c = city_n_full - r(mean) if !missing(city_n_full)

quietly summarize zip_n_review if cs_sample_focus100 == 1 & !missing(zip_n_review)
gen double zip_n_review_c = zip_n_review - r(mean) if !missing(zip_n_review)

quietly summarize city_n_review if cs_sample_focus100 == 1 & !missing(city_n_review)
gen double city_n_review_c = city_n_review - r(mean) if !missing(city_n_review)

quietly summarize ln_comp_zip_mean_excl_full if cs_sample_focus100 == 1 & !missing(ln_comp_zip_mean_excl_full)
gen double ln_comp_zip_full_c = ln_comp_zip_mean_excl_full - r(mean) if !missing(ln_comp_zip_mean_excl_full)

quietly summarize ln_comp_city_mean_excl_full if cs_sample_focus100 == 1 & !missing(ln_comp_city_mean_excl_full)
gen double ln_comp_city_full_c = ln_comp_city_mean_excl_full - r(mean) if !missing(ln_comp_city_mean_excl_full)

quietly summarize gap_zip_mean_full if cs_sample_focus100 == 1 & !missing(gap_zip_mean_full)
gen double gap_zip_full_c = gap_zip_mean_full - r(mean) if !missing(gap_zip_mean_full)

quietly summarize gap_city_mean_full if cs_sample_focus100 == 1 & !missing(gap_city_mean_full)
gen double gap_city_full_c = gap_city_mean_full - r(mean) if !missing(gap_city_mean_full)

quietly summarize gap_zip_mean_review if cs_sample_focus100 == 1 & !missing(gap_zip_mean_review)
gen double gap_zip_review_c = gap_zip_mean_review - r(mean) if !missing(gap_zip_mean_review)

quietly summarize gap_city_mean_review if cs_sample_focus100 == 1 & !missing(gap_city_mean_review)
gen double gap_city_review_c = gap_city_mean_review - r(mean) if !missing(gap_city_mean_review)

quietly summarize price_gap if cs_sample_focus100 == 1 & !missing(price_gap)
gen double price_gap_c = price_gap - r(mean) if !missing(price_gap)

*******************************************************
************ 2. Route A: market boundaries ************
*******************************************************

estimates clear

* M1. High-competition ZIP boundary.
* This tests whether the ARS slope differs in ZIP markets flagged as highly competitive.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.high_comp_zip_full ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(high_comp_zip_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_highcomp

* M2. High-competition city boundary.
* This asks whether city-level competition intensity changes the ARS revenue slope.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.high_comp_city_full ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(high_comp_city_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_highcomp

* M3. ZIP market thickness.
* More same-ZIP hotels may make ARS more or less useful as a differentiation signal.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.zip_n_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(zip_n_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_n

* M4. City market thickness.
* This uses the broader city choice set to test whether ARS matters differently in thicker city markets.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.city_n_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(city_n_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_n

* M5. ZIP competitor performance.
* Local competitor RevPAR in the same ZIP may alter how strongly consumers rely on review-similarity information.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.ln_comp_zip_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(ln_comp_zip_mean_excl_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_compperf

* M6. City competitor performance.
* This repeats the same logic at the city level rather than ZIP level.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.ln_comp_city_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(ln_comp_city_mean_excl_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_compperf

* M7. Relative ZIP positioning gap.
* Larger positive gaps indicate different positioning versus same-ZIP peers; the interaction tests whether ARS matters more for out-of-line products.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.gap_zip_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(gap_zip_mean_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_gap

* M8. Relative city positioning gap.
* This uses the city benchmark instead of the ZIP benchmark.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.gap_city_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(gap_city_mean_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_gap

* M9. Price-position gap relative to local market.
* This asks whether ARS hurts revenue more when a hotel is priced away from its local market reference.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.price_gap_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(price_gap), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_price_gap

esttab rm_zip_highcomp rm_city_highcomp rm_zip_n rm_city_n rm_zip_compperf rm_city_compperf rm_zip_gap rm_city_gap rm_price_gap ///
    using "`table_dir'/routeA_market_boundaries_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("zip high comp" "city high comp" "zip n" "city n" "zip comp RevPAR" "city comp RevPAR" "zip gap" "city gap" "price gap") ///
    nogap compress

esttab rm_zip_highcomp rm_city_highcomp rm_zip_n rm_city_n rm_zip_compperf rm_city_compperf rm_zip_gap rm_city_gap rm_price_gap ///
    using "`csv_dir'/routeA_market_boundaries_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("zip high comp" "city high comp" "zip n" "city n" "zip comp RevPAR" "city comp RevPAR" "zip gap" "city gap" "price gap") ///
    nogap

log close
