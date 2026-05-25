*******************************************************
* run_core_simi_story_exploration_260524.do
* ARS, review volume, and management-response story tests.
*
* Style follows run_core_simi_explicit_regressions_260501.do:
* - No regression wrapper program.
* - No candidate-model loop.
* - Every reported model writes the DV, focal variables,
*   controls, FE, and clustering explicitly.
* - Interactions use raw/log variables. Centered variables are
*   used only to make lower-order coefficients interpretable at
*   the sample mean; they are not standardized.
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
local run_id "260524"

local data_main "`data_dir'/core_simi_panel_260501_with_mr_text_260524.dta"

cap mkdir "`table_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`log_dir'"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'. Run scripts/r/build_management_response_text_panel_260524.R first."
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
log using "`log_dir'/run_core_simi_story_exploration_260524.log", text replace

di as text "Data source: `data_main'"

* Create numeric hotel id for FE, panel setting, and clustering.
capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc {
    encode HotelID, gen(hotel_id_num)
}
else {
    gen long hotel_id_num = HotelID
}

* Create monthly time variable.
capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm

capture confirm variable Year
if _rc {
    gen Year = year(dofm(ym))
}

capture confirm variable Mon
if _rc {
    gen Mon = month(dofm(ym))
}

xtset hotel_id_num ym
sort hotel_id_num ym

capture drop covid2020 covid2020_2022 post2020 pre_covid
gen byte covid2020 = (Year == 2020)
gen byte covid2020_2022 = inrange(Year, 2020, 2022)
gen byte post2020 = (Year >= 2020)
gen byte pre_covid = (Year <= 2019)

*******************************************************
************ 1.1 winsorized revenue outcomes **********
*******************************************************

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

capture drop ln_RevPAR_clean_w195 ln_lag_RevPAR_clean_w195
gen double ln_RevPAR_clean_w195 = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w195 = ln_lag_RevPAR_clean

quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 95)
local y_p1 = r(r1)
local y_p95 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 95)
local ly_p1 = r(r1)
local ly_p95 = r(r2)

replace ln_RevPAR_clean_w195 = `y_p1' if ln_RevPAR_clean_w195 < `y_p1' & !missing(ln_RevPAR_clean_w195)
replace ln_RevPAR_clean_w195 = `y_p95' if ln_RevPAR_clean_w195 > `y_p95' & !missing(ln_RevPAR_clean_w195)
replace ln_lag_RevPAR_clean_w195 = `ly_p1' if ln_lag_RevPAR_clean_w195 < `ly_p1' & !missing(ln_lag_RevPAR_clean_w195)
replace ln_lag_RevPAR_clean_w195 = `ly_p95' if ln_lag_RevPAR_clean_w195 > `ly_p95' & !missing(ln_lag_RevPAR_clean_w195)

capture drop ln_RevPAR_clean_w025975 ln_lag_RevPAR_clean_w025975
gen double ln_RevPAR_clean_w025975 = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w025975 = ln_lag_RevPAR_clean

quietly _pctile ln_RevPAR_clean if cs_sample_focus50 == 1, p(2.5 97.5)
local y_p025 = r(r1)
local y_p975 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus50 == 1, p(2.5 97.5)
local ly_p025 = r(r1)
local ly_p975 = r(r2)

replace ln_RevPAR_clean_w025975 = `y_p025' if ln_RevPAR_clean_w025975 < `y_p025' & !missing(ln_RevPAR_clean_w025975)
replace ln_RevPAR_clean_w025975 = `y_p975' if ln_RevPAR_clean_w025975 > `y_p975' & !missing(ln_RevPAR_clean_w025975)
replace ln_lag_RevPAR_clean_w025975 = `ly_p025' if ln_lag_RevPAR_clean_w025975 < `ly_p025' & !missing(ln_lag_RevPAR_clean_w025975)
replace ln_lag_RevPAR_clean_w025975 = `ly_p975' if ln_lag_RevPAR_clean_w025975 > `ly_p975' & !missing(ln_lag_RevPAR_clean_w025975)

*******************************************************
************ 1.2 story variables and centering ********
*******************************************************

* Market-relative review flow: hotel review flow minus city-month average.
capture drop mean_recent_cym mean_lagvol_cym rel_ln_recent_volumn rel_ln_lag_volumn_acc
bysort CityID ym: egen mean_recent_cym = mean(ln_recent_volumn)
bysort CityID ym: egen mean_lagvol_cym = mean(ln_lag_volumn_acc)
gen double rel_ln_recent_volumn = ln_recent_volumn - mean_recent_cym
gen double rel_ln_lag_volumn_acc = ln_lag_volumn_acc - mean_lagvol_cym

* Volume nonlinearity: extra recent reviews above 10 and accumulated volume above log threshold 5.8.
capture drop recent_above10 ln_recent_above10 recent_growth lagvol_over58 low_lagvol_58 high_lagvol_58 ln_recent_volumn_sq
gen double recent_above10 = max(recent_volumn - 10, 0) if !missing(recent_volumn)
gen double ln_recent_above10 = ln(recent_above10 + 1)
gen double recent_growth = ln((recent_volumn + 1) / (lag_recent_volumn + 1)) if !missing(recent_volumn, lag_recent_volumn)
gen double lagvol_over58 = max(ln_lag_volumn_acc - 5.8, 0) if !missing(ln_lag_volumn_acc)
gen byte low_lagvol_58 = (ln_lag_volumn_acc < 5.8) if !missing(ln_lag_volumn_acc)
gen byte high_lagvol_58 = (ln_lag_volumn_acc >= 5.8) if !missing(ln_lag_volumn_acc)
gen double ln_recent_volumn_sq = ln_recent_volumn^2 if !missing(ln_recent_volumn)

* Missing management-response values are zero because no lagged response activity is observed.
foreach v of varlist lag_mr_any lag_mr_count lag_mr_rate lag_mr_text_chars lag_mr_text_words lag_mr_avg_resp_days lag_mr_med_resp_days lag_mr_quick7_share lag_mr_quick30_share lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_contact_share lag_mr_personal_share lag_mr_positive_share lag_mr_negtone_share lag_mr_template_share lag_mr_mgr_share lag_mr_neg_review_share lag_mr_neg_response_rate lag_mr_avg_text_chars lag_mr_avg_text_words {
    replace `v' = 0 if missing(`v')
}

capture drop ln_lag_mr_words ln_lag_mr_avg_words ln_lag_mr_chars
gen double ln_lag_mr_words = ln(lag_mr_text_words + 1)
gen double ln_lag_mr_avg_words = ln(lag_mr_avg_text_words + 1)
gen double ln_lag_mr_chars = ln(lag_mr_text_chars + 1)

* Centering keeps the original unit but makes main effects interpretable at the sample mean.
foreach v of varlist sim_mean sim_mean_10 sim_mean_20 sim_mean_std_hotel ars_jsd_sim recent_sd rating_recent_gap rating_momentum ln_lag_avg_com_RevPAR price_gap ln_recent_volumn ln_recent_above10 recent_growth rel_ln_recent_volumn ln_lag_volumn_acc lagvol_over58 ln_words_acc ln_recent_volumn_sq ln_lag_mr_words ln_lag_mr_avg_words ln_lag_mr_chars lag_mr_rate lag_mr_count lag_mr_quick7_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_contact_share lag_mr_personal_share lag_mr_positive_share lag_mr_negtone_share lag_mr_template_share lag_mr_thanks_share lag_mr_mgr_share {
    capture drop `v'_centered
    quietly summarize `v' if cs_sample_focus100 == 1 & !missing(`v')
    gen double `v'_centered = `v' - r(mean) if !missing(`v')
}

* Store raw-scale distribution facts used later to translate coefficients into economic effects.
tempname sumhandle
tempfile sumdata
postfile `sumhandle' str40 variable double mean sd p25 p75 using `sumdata', replace
foreach v of varlist sim_mean sim_mean_10 sim_mean_20 sim_mean_std_hotel ars_jsd_sim ln_recent_volumn ln_lag_volumn_acc ln_words_acc lagvol_over58 lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share {
    quietly summarize `v' if cs_sample_focus100 == 1, detail
    post `sumhandle' ("`v'") (r(mean)) (r(sd)) (r(p25)) (r(p75))
}
postclose `sumhandle'
preserve
use `sumdata', clear
export delimited using "`csv_dir'/story_variable_summary_260524.csv", replace
restore

*******************************************************
************ 2. Route A: ARS as main effect ***********
*******************************************************

estimates clear

* A1. Baseline ARS.
* Core coefficient: sim_mean. Economic meaning: a 0.01 increase in ARS changes RevPAR by exp(beta*0.01)-1.
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_sim_w199

* A2. Same ARS coefficient with 1/95 upper-tail winsorization.
reghdfe ln_RevPAR_clean_w195 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_sim_w195

* A3. Same ARS coefficient with 2.5/97.5 winsorization in the tighter focus sample.
reghdfe ln_RevPAR_clean_w025975 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w025975 if cs_sample_focus50 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_sim_w025

* A4. Within-hotel ARS version: tests whether months with higher within-hotel similarity have weaker revenue.
reghdfe ln_RevPAR_clean_w199 sim_mean_std_hotel ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_hotelstd

* A5. Scope-10 ARS robustness.
reghdfe ln_RevPAR_clean_w199 sim_mean_10 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_scope10

* A6. Scope-20 ARS robustness.
reghdfe ln_RevPAR_clean_w199 sim_mean_20 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_scope20

* A7. JSD-based ARS robustness.
reghdfe ln_RevPAR_clean_w199 ars_jsd_sim ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_jsd

* A8. COVID boundary condition. Core interaction: ARS slope during 2020-2022 versus other months.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.covid2020_2022 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_covid

esttab ta_sim_w199 ta_sim_w195 ta_sim_w025 ta_hotelstd ta_scope10 ta_scope20 ta_jsd ta_covid using "`table_dir'/story_table_a_ars_main_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("w199" "w195" "w025/975" "hotel std" "scope10" "scope20" "JSD" "COVID") nogap compress
esttab ta_sim_w199 ta_sim_w195 ta_sim_w025 ta_hotelstd ta_scope10 ta_scope20 ta_jsd ta_covid using "`csv_dir'/story_table_a_ars_main_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("w199" "w195" "w025/975" "hotel std" "scope10" "scope20" "JSD" "COVID") nogap

*******************************************************
************ 2.1 Route A: boundary conditions *********
*******************************************************

estimates clear

* A9. Rating uncertainty: if recent rating dispersion is high, ARS may matter differently.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.recent_sd_centered ln_recent_volumn recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_sd

* A10. Rating gap: ARS may be less useful when recent rating deviates from accumulated reputation.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.rating_recent_gap_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_ratinggap

* A11. Rating momentum: ARS may signal stability differently when recent ratings are moving.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.rating_momentum_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_ratingmom

* A12. Market pressure: competitor RevPAR captures local demand and competition.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_lag_avg_com_RevPAR_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_compete

* A13. Product-positioning gap: price gap captures relative market position.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.price_gap_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_pricegap

* A14. Product quality group: star_class is a factor. Missing star_class remains missing.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.star_class ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(star_class), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_star

* A15. Chain product type.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.chain ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(chain), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_chain

* A16. COVID boundary repeated in the moderator table for direct comparison.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.covid2020_2022 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_covid

esttab am_sd am_ratinggap am_ratingmom am_compete am_pricegap am_star am_chain am_covid using "`table_dir'/story_table_a_moderators_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("rating sd" "rating gap" "rating mom" "competition" "price gap" "star" "chain" "COVID") nogap compress
esttab am_sd am_ratinggap am_ratingmom am_compete am_pricegap am_star am_chain am_covid using "`csv_dir'/story_table_a_moderators_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("rating sd" "rating gap" "rating mom" "competition" "price gap" "star" "chain" "COVID") nogap

*******************************************************
************ 3. Route B: volume x ARS *****************
*******************************************************

estimates clear

* B1. Recent review flow. Core interaction: recent monthly volume x ARS.
* A doubling of recent volume is ln(2); ARS is interpreted in 0.01 raw-unit increments.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_recent

* B2. Recent review pressure above 10 reviews in the month.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_above10_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_recent10

* B3. Review growth from last month.
reghdfe ln_RevPAR_clean_w199 c.recent_growth_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_growth

* B4. Recent review flow relative to city-month competitors.
reghdfe ln_RevPAR_clean_w199 c.rel_ln_recent_volumn_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_relrecent

* B5. Accumulated review stock. Treat this as an alternative volume-stock measure rather than controlling for another volume stock.
reghdfe ln_RevPAR_clean_w199 c.ln_lag_volumn_acc_centered##c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum

* B6. Accumulated review stock with within-hotel ARS. This checks whether the volume story survives an alternative ARS measure.
reghdfe ln_RevPAR_clean_w199 c.ln_lag_volumn_acc_centered##c.sim_mean_std_hotel_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum_hstd

* B7. Accumulated review stock above log threshold 5.8.
reghdfe ln_RevPAR_clean_w199 c.lagvol_over58_centered##c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum58

* B8. Accumulated review stock above log threshold 5.8 with scope-10 ARS.
reghdfe ln_RevPAR_clean_w199 c.lagvol_over58_centered##c.sim_mean_10_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum58_s10

* B9. Accumulated review text stock. This captures solicitation/content intensity beyond count.
reghdfe ln_RevPAR_clean_w199 c.ln_words_acc_centered##c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_words

* B10. Text stock with within-hotel ARS.
reghdfe ln_RevPAR_clean_w199 c.ln_words_acc_centered##c.sim_mean_std_hotel_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_words_hstd

* B11. Nonlinear recent volume. Core terms are the linear and squared volume interactions with ARS.
reghdfe ln_RevPAR_clean_w199 ln_recent_volumn_centered ln_recent_volumn_sq_centered sim_mean_centered c.ln_recent_volumn_centered#c.sim_mean_centered c.ln_recent_volumn_sq_centered#c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_recent_sq

esttab tb_recent tb_recent10 tb_growth tb_relrecent tb_cum tb_cum_hstd tb_cum58 tb_cum58_s10 tb_words tb_words_hstd tb_recent_sq using "`table_dir'/story_table_b_volume_ars_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recent" "recent>10" "growth" "rel recent" "cumulative" "cum hstd" "cum>5.8" "cum>5.8 s10" "text volume" "text hstd" "recent sq") nogap compress
esttab tb_recent tb_recent10 tb_growth tb_relrecent tb_cum tb_cum_hstd tb_cum58 tb_cum58_s10 tb_words tb_words_hstd tb_recent_sq using "`csv_dir'/story_table_b_volume_ars_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recent" "recent>10" "growth" "rel recent" "cumulative" "cum hstd" "cum>5.8" "cum>5.8 s10" "text volume" "text hstd" "recent sq") nogap

*******************************************************
************ 4. Route C: reply -> revenue *************
*******************************************************

estimates clear

* C1. Any reply. Direct coefficient is the revenue gap between hotels with and without lagged reply activity at average ARS.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.lag_mr_any ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_any

* C2. Reply rate. A 0.10 increase is a 10 percentage-point higher lagged reply rate.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_rate_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_rate

* C3. Reply count.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_count_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_count

* C4. Total reply text length.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_lag_mr_words_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_words

* C5. Average reply length.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_lag_mr_avg_words_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_avgwords

* C6. Fast replies within seven days.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_quick7_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_quick

* C7. Invite wording as engagement/solicitation language.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_invite_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_invite

* C8. Service-recovery wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_recovery_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_recovery

* C9. Positive reply wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_positive_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_positive

esttab cr_any cr_rate cr_count cr_words cr_avgwords cr_quick cr_invite cr_recovery cr_positive using "`table_dir'/story_table_c_reply_revenue_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("any reply" "reply rate" "reply count" "words" "avg words" "quick7" "invite" "recovery" "positive") nogap compress
esttab cr_any cr_rate cr_count cr_words cr_avgwords cr_quick cr_invite cr_recovery cr_positive using "`csv_dir'/story_table_c_reply_revenue_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("any reply" "reply rate" "reply count" "words" "avg words" "quick7" "invite" "recovery" "positive") nogap

*******************************************************
************ 4.1 Route C: text interactions ***********
*******************************************************

estimates clear

* C10. Thanks wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_thanks_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_thanks

* C11. Apology wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_apology_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_apology

* C12. Contact wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_contact_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_contact

* C13. Personalization.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_personal_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_personal

* C14. Negative-problem wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_negtone_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_negtone

* C15. Template-like wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_template_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_template

* C16. Three-way test: volume x ARS x average reply length.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean_centered##c.ln_lag_mr_avg_words_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_avgw

* C17. Three-way test: volume x ARS x quick reply.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean_centered##c.lag_mr_quick7_share_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_quick

* C18. Three-way test: volume x ARS x positive reply wording.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean_centered##c.lag_mr_positive_share_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_pos

* C19. Three-way test: volume x ARS x recovery wording.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean_centered##c.lag_mr_recovery_share_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_rec

esttab tc_thanks tc_apology tc_contact tc_personal tc_negtone tc_template tc_triple_avgw tc_triple_quick tc_triple_pos tc_triple_rec using "`table_dir'/story_table_c_mr_text_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("thanks" "apology" "contact" "personal" "neg tone" "template" "triple avg words" "triple quick7" "triple positive" "triple recovery") nogap compress
esttab tc_thanks tc_apology tc_contact tc_personal tc_negtone tc_template tc_triple_avgw tc_triple_quick tc_triple_pos tc_triple_rec using "`csv_dir'/story_table_c_mr_text_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("thanks" "apology" "contact" "personal" "neg tone" "template" "triple avg words" "triple quick7" "triple positive" "triple recovery") nogap

*******************************************************
************ 5. Route C: mechanisms *******************
*******************************************************

estimates clear

* C20. Mechanism DV: next-month review volume. MR text is treated as observable engagement, not causal solicitation.
reghdfe ln_recent_volumn lag_mr_rate ln_lag_mr_words lag_mr_count lag_mr_quick7_share lag_mr_invite_share lag_mr_apology_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_volume

* C21. Mechanism DV: ARS. This asks whether reply engagement predicts later review similarity.
reghdfe sim_mean lag_mr_rate ln_lag_mr_words lag_mr_count lag_mr_quick7_share lag_mr_invite_share lag_mr_apology_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_ars

* C22. Mechanism DV: RevPAR with MR text variables entered directly.
reghdfe ln_RevPAR_clean_w199 lag_mr_rate ln_lag_mr_words lag_mr_count lag_mr_quick7_share lag_mr_invite_share lag_mr_apology_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share ln_recent_volumn sim_mean recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_revpar

esttab tm_volume tm_ars tm_revpar using "`table_dir'/story_table_c_mr_mechanisms_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("DV: volume" "DV: ARS" "DV: RevPAR") nogap compress
esttab tm_volume tm_ars tm_revpar using "`csv_dir'/story_table_c_mr_mechanisms_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("DV: volume" "DV: ARS" "DV: RevPAR") nogap

log close
