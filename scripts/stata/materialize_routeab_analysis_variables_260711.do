version 17.0
clear all
set more off
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
save "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", replace
