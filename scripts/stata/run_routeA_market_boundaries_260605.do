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

quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local y_p1 = r(r1)
local y_p99 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local ly_p1 = r(r1)
local ly_p99 = r(r2)

replace ln_RevPAR_clean = `y_p1' if ln_RevPAR_clean < `y_p1' & !missing(ln_RevPAR_clean)
replace ln_RevPAR_clean = `y_p99' if ln_RevPAR_clean > `y_p99' & !missing(ln_RevPAR_clean)
replace ln_lag_RevPAR_clean = `ly_p1' if ln_lag_RevPAR_clean < `ly_p1' & !missing(ln_lag_RevPAR_clean)
replace ln_lag_RevPAR_clean = `ly_p99' if ln_lag_RevPAR_clean > `ly_p99' & !missing(ln_lag_RevPAR_clean)

* Center variables so lower-order coefficients are interpretable at the focus100 sample mean.
capture drop sim_mean zip_n_full_c city_n_full_c zip_n_review_c city_n_review_c
capture drop ln_comp_zip_full_c ln_comp_city_full_c gap_zip_full_c gap_city_full_c
capture drop gap_zip_review_c gap_city_review_c revenue_gap_c


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

generate revenue_gap = price_gap
quietly summarize revenue_gap if cs_sample_focus100 == 1 & !missing(revenue_gap)
gen double revenue_gap_c = revenue_gap - r(mean) if !missing(revenue_gap)

* Median cutoffs for grouped regressions.
quietly summarize ln_avg_com_RevPAR if cs_sample_focus100 == 1 & !missing(high_comp_zip_full), detail
local med_compavg = r(p50)
capture drop hi_compavg_focus100
gen byte hi_compavg_focus100 = (ln_avg_com_RevPAR > `med_compavg') if cs_sample_focus100 == 1 & !missing(high_comp_zip_full) & !missing(ln_avg_com_RevPAR)

quietly summarize zip_n_full if cs_sample_focus100 == 1 & !missing(zip_n_full), detail
local med_zip_n = r(p50)
capture drop hi_zip_n_focus100
gen byte hi_zip_n_focus100 = (zip_n_full > `med_zip_n') if cs_sample_focus100 == 1 & !missing(zip_n_full)

quietly summarize city_n_full if cs_sample_focus100 == 1 & !missing(city_n_full), detail
local med_city_n = r(p50)
capture drop hi_city_n_focus100
gen byte hi_city_n_focus100 = (city_n_full > `med_city_n') if cs_sample_focus100 == 1 & !missing(city_n_full)

quietly summarize gap_zip_mean_full if cs_sample_focus100 == 1 & !missing(gap_zip_mean_full), detail
local med_zip_gap = r(p50)
capture drop hi_zip_gap_focus100
gen byte hi_zip_gap_focus100 = (gap_zip_mean_full > `med_zip_gap') if cs_sample_focus100 == 1 & !missing(gap_zip_mean_full)

quietly summarize gap_city_mean_full if cs_sample_focus100 == 1 & !missing(gap_city_mean_full), detail
local med_city_gap = r(p50)
capture drop hi_city_gap_focus100
gen byte hi_city_gap_focus100 = (gap_city_mean_full > `med_city_gap') if cs_sample_focus100 == 1 & !missing(gap_city_mean_full)

quietly summarize revenue_gap if cs_sample_focus100 == 1 & !missing(revenue_gap), detail
local med_revenue_gap = r(p50)
capture drop hi_revenue_gap_focus100
gen byte hi_revenue_gap_focus100 = (revenue_gap > `med_revenue_gap') if cs_sample_focus100 == 1 & !missing(revenue_gap)

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

*******************************************************
************ 2. Route A: market boundaries ************
*******************************************************

estimates clear

* M0.1 Baseline on the market-boundary sample.
* This anchors the comparison before adding any moderator term.
reghdfe ln_RevPAR_clean c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(high_comp_zip_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_base_market

* M0.2 Competitor RevPAR interaction.
* This asks whether ARS hurts more when the surrounding competitor RevPAR level is higher.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.ln_avg_com_RevPAR ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(high_comp_zip_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_compavg

* M0.2a-M0.2b Grouped competitor RevPAR regressions.
* Split the sample at the median competitor RevPAR and estimate the ARS slope separately.
reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(high_comp_zip_full) & hi_compavg_focus100 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_compavg_low

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(high_comp_zip_full) & hi_compavg_focus100 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_compavg_high

* M1. High-competition ZIP boundary.
* This tests whether the ARS slope differs in ZIP markets flagged as highly competitive,
* where the high/low split is rebuilt within the focus100 sample.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.high_comp_zip_focus100 ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(high_comp_zip_focus100), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_highcomp

* M1a-M1b Grouped ZIP competition regressions.
* Estimate the ARS slope separately in low- and high-competition ZIP markets.
reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_comp_zip_focus100 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_zip_highcomp_low

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_comp_zip_focus100 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_zip_highcomp_high

* M2. High-competition city boundary.
* This asks whether city-level competition intensity changes the ARS revenue slope,
* where the high/low split is rebuilt within the focus100 sample.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.high_comp_city_focus100 ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(high_comp_city_focus100), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_highcomp

* M2a-M2b Grouped city competition regressions.
* Estimate the ARS slope separately in low- and high-competition city markets.
reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_comp_city_focus100 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_city_highcomp_low

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_comp_city_focus100 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_city_highcomp_high

* M3. ZIP market thickness.
* More same-ZIP hotels may make ARS more or less useful as a differentiation signal.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.zip_n_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(zip_n_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_n


* M4. City market thickness.
* This uses the broader city choice set to test whether ARS matters differently in thicker city markets.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.city_n_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(city_n_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_n


* M5. ZIP competitor performance.
* Local competitor RevPAR in the same ZIP may alter how strongly consumers rely on review-similarity information.
* Use the raw ZIP competitor RevPAR moderator directly and split groups at the focus100 sample median.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.ln_comp_zip_mean_excl_full ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(ln_comp_zip_mean_excl_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_compperf


* M5a-M5b Grouped ZIP competitor-RevPAR regressions.
* Split the sample at the focus100 median of the raw ZIP competitor RevPAR variable.
capture drop temp_med
bysort Zip ym: egen temp_med = median(ln_comp_zip_mean_excl_full)

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & ln_comp_zip_mean_excl_full < temp_med, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_zip_compperf_low

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & ln_comp_zip_mean_excl_full > temp_med, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_zip_compperf_high

* M6. City competitor performance.
* This repeats the same logic at the city level rather than ZIP level.
* Use the raw city competitor RevPAR moderator directly and split groups at the focus100 sample median.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.ln_comp_city_mean_excl_full ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(ln_comp_city_mean_excl_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_compperf

* M6a-M6b Grouped city competitor-RevPAR regressions.
* Split the sample at the focus100 median of the raw city competitor RevPAR variable.
capture drop temp_med
bysort City ym: egen temp_med = median(ln_comp_city_mean_excl_full)

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & ln_comp_city_mean_excl_full < temp_med, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_city_compperf_low

reghdfe ln_RevPAR_clean_w595 c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & ln_comp_city_mean_excl_full > temp_med, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_city_compperf_high

* M7. Relative ZIP positioning gap.
* Larger positive gaps indicate different positioning versus same-ZIP peers; the interaction tests whether ARS matters more for out-of-line products.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.gap_zip_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(gap_zip_mean_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_zip_gap

* M7a-M7b Grouped ZIP gap regressions.
* Split the sample at the median ZIP positioning gap and estimate separate ARS slopes.
capture drop temp_med
bysort Zip ym: egen temp_med = median(ln_comp_city_mean_excl_full)

reghdfe ln_RevPAR_clean c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(gap_zip_mean_full) & hi_zip_gap_focus100 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_zip_gap_low

reghdfe ln_RevPAR_clean c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(gap_zip_mean_full) & hi_zip_gap_focus100 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_zip_gap_high

* M8. Relative city positioning gap.
* This uses the city benchmark instead of the ZIP benchmark.
reghdfe ln_RevPAR_clean c.sim_mean##c.gap_city_full_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(gap_city_mean_full), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_city_gap

* M8a-M8b Grouped city gap regressions.
* Split the sample at the median city positioning gap and estimate separate ARS slopes.
reghdfe ln_RevPAR_clean c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(gap_city_mean_full) & hi_city_gap_focus100 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_city_gap_low

reghdfe ln_RevPAR_clean c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(gap_city_mean_full) & hi_city_gap_focus100 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_city_gap_high

* M9. Price-position gap relative to local market.
* This asks whether ARS hurts revenue more when a hotel is priced away from its local market reference.
reghdfe ln_RevPAR_clean c.sim_mean##c.revenue_gap_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(revenue_gap), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store rm_revenue_gap

* M9a-M9b Grouped price-gap regressions.
* Split the sample at the median price gap and estimate separate ARS slopes.
reghdfe ln_RevPAR_clean c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(revenue_gap) & hi_revenue_gap_focus100 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_revenue_gap_low

reghdfe ln_RevPAR_clean c.sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc  ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(revenue_gap) & hi_revenue_gap_focus100 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store grp_revenue_gap_high

esttab rm_base_market rm_compavg rm_zip_highcomp rm_city_highcomp rm_zip_n rm_city_n rm_zip_compperf rm_city_compperf rm_zip_gap rm_city_gap rm_revenue_gap ///
    using "`table_dir'/routeA_market_boundaries_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("baseline" "comp RevPAR" "zip high comp" "city high comp" "zip n" "city n" "zip comp RevPAR" "city comp RevPAR" "zip gap" "city gap" "price gap") ///
    nogap compress

esttab rm_base_market rm_compavg rm_zip_highcomp rm_city_highcomp rm_zip_n rm_city_n rm_zip_compperf rm_city_compperf rm_zip_gap rm_city_gap rm_revenue_gap ///
    using "`csv_dir'/routeA_market_boundaries_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("baseline" "comp RevPAR" "zip high comp" "city high comp" "zip n" "city n" "zip comp RevPAR" "city comp RevPAR" "zip gap" "city gap" "price gap") ///
    nogap

esttab grp_compavg_low grp_compavg_high ///
    grp_zip_highcomp_low grp_zip_highcomp_high ///
    grp_city_highcomp_low grp_city_highcomp_high ///
    grp_zip_n_low grp_zip_n_high ///
    grp_city_n_low grp_city_n_high ///
    grp_zip_compperf_low grp_zip_compperf_high ///
    grp_city_compperf_low grp_city_compperf_high ///
    grp_zip_gap_low grp_zip_gap_high ///
    grp_city_gap_low grp_city_gap_high ///
    grp_revenue_gap_low grp_revenue_gap_high ///
    using "`table_dir'/routeA_market_boundaries_grouped_`run_id'.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("comp low" "comp high" "zip comp low" "zip comp high" "city comp low" "city comp high" "zip n low" "zip n high" "city n low" "city n high" "zip rvpar low" "zip rvpar high" "city rvpar low" "city rvpar high" "zip gap low" "zip gap high" "city gap low" "city gap high" "price low" "price high") ///
    nogap compress

esttab grp_compavg_low grp_compavg_high ///
    grp_zip_highcomp_low grp_zip_highcomp_high ///
    grp_city_highcomp_low grp_city_highcomp_high ///
    grp_zip_n_low grp_zip_n_high ///
    grp_city_n_low grp_city_n_high ///
    grp_zip_compperf_low grp_zip_compperf_high ///
    grp_city_compperf_low grp_city_compperf_high ///
    grp_zip_gap_low grp_zip_gap_high ///
    grp_city_gap_low grp_city_gap_high ///
    grp_revenue_gap_low grp_revenue_gap_high ///
    using "`csv_dir'/routeA_market_boundaries_grouped_`run_id'.csv", replace csv ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("comp low" "comp high" "zip comp low" "zip comp high" "city comp low" "city comp high" "zip n low" "zip n high" "city n low" "city n high" "zip rvpar low" "zip rvpar high" "city rvpar low" "city rvpar high" "zip gap low" "zip gap high" "city gap low" "city gap high" "price low" "price high") ///
    nogap

log close
