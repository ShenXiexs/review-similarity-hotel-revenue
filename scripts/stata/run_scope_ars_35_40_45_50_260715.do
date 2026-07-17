* run_scope_ars_35_40_45_50_260715.do
* Additional review-scope robustness: current month plus N prior reviews.

version 17.0
clear all
set more off
set linesize 255
capture log close _all

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_scope_ars_35_50_260715.dta"
* Corrected specification: match the recent-rating control to the review
* window in each column, rather than using one 10-review measure throughout.
* Keep the original RTF as an archive.
local rtf "`project'/outputs/paper/rtf/reviewsimi_scope_35_40_45_50_recent_rating10_260717.rtf"

use "`data'", clear
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
keep if cs_sample_focus100 == 1
label variable ln_lag_volumn_acc "Review volume i,t-1"
label variable lag_avg_rating_acc "Rating acc. i,t-1"
label variable lag_sd_acc "Rating SD acc. i,t-1"
label variable ln_avg_com_RevPAR "Competitor RevPAR i,t"
label variable ln_lag_RevPAR_clean "RevPAR i,t-1"

foreach s in 35 40 45 50 {
    label variable sim_mean_`s' "ARS i,t (`s'-review window)"
    label variable ln_recent_volumn_`s' "Recent volume i,t (`s'-review window)"
    label variable recent_sd_`s' "Recent SD i,t (`s'-review window)"
    label variable recent_rating_`s' "Recent rating i,t-1 (`s'-review window)"
    reghdfe ln_RevPAR_clean sim_mean_`s' ln_recent_volumn_`s' recent_sd_`s' ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc recent_rating_`s' ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store scope`s'
}

esttab scope35 scope40 scope45 scope50 using "`rtf'", replace rtf ///
    order(sim_mean_35 sim_mean_40 sim_mean_45 sim_mean_50 ///
        ln_recent_volumn_35 ln_recent_volumn_40 ln_recent_volumn_45 ln_recent_volumn_50 ///
        recent_sd_35 recent_sd_40 recent_sd_45 recent_sd_50 ///
        recent_rating_35 recent_rating_40 recent_rating_45 recent_rating_50 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("35" "40" "45" "50") ///
    label nogap compress ///
    title("Additional review scopes; current month plus prior 35/40/45/50 reviews")

display as result "Completed: `rtf'"
