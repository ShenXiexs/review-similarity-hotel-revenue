*******************************************************
* Compatibility entry point for separate Route B learning and MR modules.
*******************************************************
version 17.0
clear all
set more off
local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
do "`project'/scripts/stata/run_event_month_pool_gt100_learning_effect_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_mr_targeting_260711.do"
