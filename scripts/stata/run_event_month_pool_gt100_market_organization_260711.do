*******************************************************
* Compatibility entry point.  Use the two standalone Route A files below
* when individual market or organization results are required.
*******************************************************
version 17.0
clear all
set more off
local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
do "`project'/scripts/stata/run_event_month_pool_gt100_market_boundaries_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_organization_boundaries_260711.do"
