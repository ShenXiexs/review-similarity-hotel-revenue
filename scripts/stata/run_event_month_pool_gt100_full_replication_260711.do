version 17.0
clear all
set more off
local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
do "`project'/scripts/stata/run_event_month_pool_gt100_market_boundaries_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_organization_boundaries_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_product_systematics_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_review_environment_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_engagement_style_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_learning_effect_260711.do"
do "`project'/scripts/stata/run_event_month_pool_gt100_mr_targeting_260711.do"
