************************************************************
* Tables 5--8 for reviewsimi-revenue-0722v1.docx
* No data construction: reads two prepared analysis panels only.
* Table 5 excludes the separately maintained Sys-GMM specification.
************************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close _all

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_main "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local data_scope "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_scope_ars_35_50_260715.dta"
local logfile "`project'/stata-log/run_tables5_8_new_controls_260722.log"

capture confirm file "`data_main'"
if _rc exit 601
capture confirm file "`data_scope'"
if _rc exit 601
capture which reghdfe
if _rc exit 199
capture which esttab
if _rc exit 199

log using "`logfile'", text replace

************************************************************
* Tables 5--7: final Route A/B prepared panel.
************************************************************
use "`data_main'", clear
keep if cs_sample_focus100 == 1
capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
capture confirm variable ym
if _rc gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym

************************************************************
* Table 5. FE and OLS; Sys-GMM deliberately excluded.
************************************************************
reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t5_fe

reg ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    vce(cluster hotel_id_num)
estimates store t5_ols

esttab t5_fe t5_ols, ///
    order(sim_mean recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("FE" "OLS") label nogap compress

************************************************************
* Table 6. COVID-19 models.
************************************************************
capture drop covid2020 covid2020_2022
gen byte covid2020 = Year == 2020 if !missing(Year)
gen byte covid2020_2022 = inrange(Year, 2020, 2022) if !missing(Year)

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if covid2020_2022 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_pre2020

reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_2020

reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020_2022 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_pandemic

reghdfe d_ln_RevPAR c.sim_mean##i.covid2020_2022 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_growth

esttab t6_pre2020 t6_2020 t6_pandemic t6_growth, ///
    order(sim_mean 1.covid2020#c.sim_mean 1.covid2020_2022#c.sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("Before 2020" "2020 shock" "2020--2022 shock" "2020--2022 growth") label nogap compress

************************************************************
* Table 7. Alternative ARS measures.
************************************************************
reghdfe ln_RevPAR_clean lag_sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t7_lag

reghdfe ln_RevPAR_clean ars_roll_10 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t7_roll

reghdfe ln_RevPAR_clean ars_jsd_sim ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t7_jsd

esttab t7_lag t7_roll t7_jsd, ///
    order(lag_sim_mean ars_roll_10 ars_jsd_sim recent_sd_10 ln_recent_volumn_10 ///
    lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("ARS lag" "ARS roll" "ARS JSD") label nogap compress

************************************************************
* Table 8. 5--50-review ARS windows.  Only the ARS window changes;
* all new-control variables remain the scope-10 baseline variables.
************************************************************
use "`data_scope'", clear
keep if cs_sample_focus100 == 1
capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
capture confirm variable ym
if _rc gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym

reghdfe ln_RevPAR_clean sim_mean_5 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope5

reghdfe ln_RevPAR_clean sim_mean_10 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope10

reghdfe ln_RevPAR_clean sim_mean_15 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope15

reghdfe ln_RevPAR_clean sim_mean_20 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope20

reghdfe ln_RevPAR_clean sim_mean_30 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope30

reghdfe ln_RevPAR_clean sim_mean_35 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope35

reghdfe ln_RevPAR_clean sim_mean_40 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope40

reghdfe ln_RevPAR_clean sim_mean_45 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope45

reghdfe ln_RevPAR_clean sim_mean_50 ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_scope50

esttab t8_scope5 t8_scope10 t8_scope15 t8_scope20 t8_scope30 ///
    t8_scope35 t8_scope40 t8_scope45 t8_scope50, ///
    order(sim_mean_5 sim_mean_10 sim_mean_15 sim_mean_20 sim_mean_30 ///
    sim_mean_35 sim_mean_40 sim_mean_45 sim_mean_50 recent_sd_10 ///
    ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("5" "10" "15" "20" "30" "35" "40" "45" "50") label nogap compress

log close
