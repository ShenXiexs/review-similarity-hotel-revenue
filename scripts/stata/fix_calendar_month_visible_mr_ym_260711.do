version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
log using "`p'/stata-log/fix_calendar_month_visible_mr_ym_260711.log", text replace
use "`p'/outputs/core_simi_260501/data/calendar_month_pool_visible_mr_gt100_panel_260711.dta", clear
capture drop ym
gen ym = monthly(event_ym, "YM")
format ym %tm
save "`p'/outputs/core_simi_260501/data/calendar_month_pool_visible_mr_gt100_panel_260711.dta", replace
log close
