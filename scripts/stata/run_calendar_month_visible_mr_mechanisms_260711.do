************************************************************
* Compatibility entry point.
* The complete strict month-start visible-reply mechanism analysis now lives
* in run_event_month_pool_gt100_reply_mechanisms_260711.do.  Running either
* file produces the same single log and does not invoke the legacy event-month
* lag_mr_* specifications.
************************************************************
version 17.0
clear all
set more off
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
do "`p'/scripts/stata/run_event_month_pool_gt100_reply_mechanisms_260711.do"
