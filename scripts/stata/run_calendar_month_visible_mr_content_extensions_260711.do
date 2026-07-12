version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"

use "`p'/outputs/core_simi_260501/data/calendar_month_pool_visible_mr_gt100_panel_260711.dta", clear
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen ym = monthly(event_ym, "YM")
format ym %tm
xtset hotel_id_num ym

* Content-test family fixed before inspecting these extension results.
* All controls are measured before the outcome month; no current content
* variables are controls in primary specifications.
local X ln_pre_review_count ln_cumulative_reviews_start pre_mean_rating pre_mean_rating_missing pre_sd_rating pre_sd_rating_missing pre_ln_mean_text_chars pre_ln_mean_text_chars_missing pre_ars_pool_visible pre_ars_pool_visible_missing

* Grouped intensity: 0=no reply visible at month start; 1=1--3 replies;
* 2=4+ replies.  The 4+ threshold is the empirical upper quartile boundary.
capture drop mr_visible_intensity_group delta_ars_pool_visible L1_mr_visible_start_any L2_mr_visible_start_any
gen byte mr_visible_intensity_group = 0 if mr_visible_start_n == 0
replace mr_visible_intensity_group = 1 if inrange(mr_visible_start_n, 1, 3)
replace mr_visible_intensity_group = 2 if mr_visible_start_n >= 4
gen double delta_ars_pool_visible = ars_pool_visible - L.ars_pool_visible if !missing(ars_pool_visible, L.ars_pool_visible)
gen byte L1_mr_visible_start_any = L.mr_visible_start_any
gen byte L2_mr_visible_start_any = L2.mr_visible_start_any

log using "`p'/stata-log/run_calendar_month_visible_mr_content_extensions_260711.log", text replace
estimates clear

* Primary pooled 2-month content outcome, repeated here as the family anchor.
reghdfe ars_pool_visible mr_visible_start_any `X' if !missing(ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C1_pool2_any

* Broader pooled window: current plus both preceding calendar months.
reghdfe ars_pool_visible_3m mr_visible_start_any `X' if !missing(ars_pool_visible_3m), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C2_pool3_any

* New-review cohesion only: pooled similarity among current-month reviews.
reghdfe ars_within_current mr_visible_start_any `X' if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C3_within_any

* Change in two-month pooled homogeneity relative to its prior observed level.
reghdfe delta_ars_pool_visible mr_visible_start_any `X' if !missing(delta_ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C4_delta_any

* Grouped response dose rather than a functional-form interaction.
reghdfe ars_pool_visible ib0.mr_visible_intensity_group `X' if !missing(ars_pool_visible), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C5_pool2_groups
reghdfe ars_within_current ib0.mr_visible_intensity_group `X' if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C6_within_groups

* Distributed timing: contemporaneous month-start visibility plus the two
* preceding visible-response months.  This tests delayed rather than future use.
reghdfe ars_pool_visible mr_visible_start_any L1_mr_visible_start_any L2_mr_visible_start_any `X' if !missing(ars_pool_visible, L1_mr_visible_start_any, L2_mr_visible_start_any), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C7_pool2_lags
reghdfe ars_within_current mr_visible_start_any L1_mr_visible_start_any L2_mr_visible_start_any `X' if !missing(ars_within_current, L1_mr_visible_start_any, L2_mr_visible_start_any), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C8_within_lags

* Composition check: current review count can be a mechanism through which
* replies alter measured within-month cohesion, so this is secondary.
reghdfe ars_within_current mr_visible_start_any ln_review_count `X' if !missing(ars_within_current), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store C9_within_any_condcount

estimates table C1_pool2_any C2_pool3_any C3_within_any C4_delta_any C5_pool2_groups C6_within_groups C7_pool2_lags C8_within_lags C9_within_any_condcount, b(%9.6f) se(%9.6f) stats(N r2_a)
log close
