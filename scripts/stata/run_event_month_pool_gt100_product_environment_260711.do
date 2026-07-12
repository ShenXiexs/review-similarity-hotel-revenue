*******************************************************
* Compatibility entry point.  The standalone files preserve the Route A
* product-systematics and review-environment modules separately.
*******************************************************
version 17.0
clear all
set more off
local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
do "`project'/scripts/stata/run_event_month_pool_gt100_product_systematics_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_review_environment_260711.do"
