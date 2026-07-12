version 17.0
clear all
set more off
local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
do "`project'/scripts/stata/run_event_month_pool_gt100_market_organization_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_product_environment_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_engagement_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_learning_mr_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_grouped_slopes_260711.do"
