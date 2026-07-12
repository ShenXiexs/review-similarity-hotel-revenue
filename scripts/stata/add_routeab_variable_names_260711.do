version 17.0
clear all
set more off
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
capture drop sim_mean ln_RevPAR_clean ln_lag_RevPAR_clean cs_sample_focus100
gen double sim_mean = ars_pool_ev
gen double ln_RevPAR_clean = lnRevenue_current
gen double ln_lag_RevPAR_clean = lnRevenue_lag_month
gen byte cs_sample_focus100 = 1
save "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", replace
