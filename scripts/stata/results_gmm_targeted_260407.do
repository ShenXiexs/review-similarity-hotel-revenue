*******************************************************
* results_gmm_targeted_260407.do
* Purpose:
*   1) rerun a few top-ranked GMM candidates on the adopted 260407 sample
*   2) preserve raw output for paper writing while broad scans keep running
*******************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local output_root "`project'/outputs"
local data_dir "`output_root'/data"
local log_dir "`output_root'/logs"
cap mkdir "`output_root'"
cap mkdir "`data_dir'"
cap mkdir "`log_dir'"
local data_main "`data_dir'/valid_match_review_acc_260407_main.dta"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find valid_match_review_acc_260407_main.dta. Run scripts/r/Review_Simi_260325.Rmd first."
    exit 601
}

use "`data_main'", clear

capture confirm numeric variable HotelID
if _rc {
    encode HotelID, gen(hotel_id_num)
}
else {
    gen long hotel_id_num = HotelID
}

capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm

capture drop covid_2020 covid_2021 covid_2022 post2020 post2021 sim_post2020 sim_post2021
gen byte covid_2020 = (Year == 2020)
gen byte covid_2021 = (Year == 2021)
gen byte covid_2022 = (Year == 2022)
gen byte post2020 = (Year >= 2020)
gen byte post2021 = (Year >= 2021)
gen double sim_post2020 = sim_mean_std_hotel * post2020
gen double sim_post2021 = sim_mean_std_hotel * post2021

log using "`log_dir'/results_gmm_targeted_260407.log", text replace

di as text "============================================================"
di as text "1) PRE2019 TARGETED SAME-SAMPLE GMM"
di as text "============================================================"

preserve
keep if main_sample_keep == 1 & Year <= 2019
xtset hotel_id_num ym

xtabond2 ln_RevPAR_clean L.ln_RevPAR_clean L2.ln_RevPAR_clean ///
    sim_mean_std_hotel ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness i.Year, ///
    gmm(L.ln_RevPAR_clean L2.ln_RevPAR_clean, laglimits(5 8) collapse) ///
    gmm(sim_mean_std_hotel, laglimits(6 7) collapse) ///
    iv(ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc ///
       lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness i.Year) ///
    twostep robust small orthogonal

xtabond2 ln_RevPAR_clean L.ln_RevPAR_clean L2.ln_RevPAR_clean ///
    sim_mean_std_hotel ///
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR i.Year, ///
    gmm(L.ln_RevPAR_clean L2.ln_RevPAR_clean, laglimits(5 8) collapse) ///
    gmm(sim_mean_std_hotel, laglimits(6 7) collapse) ///
    iv(ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc ln_avg_com_RevPAR i.Year) ///
    twostep robust small orthogonal
restore

di as text "============================================================"
di as text "2) FULL-YEAR TARGETED SAME-SAMPLE GMM"
di as text "============================================================"

preserve
keep if main_sample_keep == 1
xtset hotel_id_num ym

xtabond2 ln_RevPAR_clean L.ln_RevPAR_clean L2.ln_RevPAR_clean ///
    sim_mean_std_hotel ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness ///
    covid_2020 covid_2021 covid_2022 i.Mon, ///
    gmm(L.ln_RevPAR_clean L2.ln_RevPAR_clean, laglimits(7 10) collapse) ///
    gmm(sim_mean_std_hotel, laglimits(6 7) collapse) ///
    iv(ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc ///
       lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness ///
       covid_2020 covid_2021 covid_2022 i.Mon) ///
    twostep robust small orthogonal

xtabond2 ln_RevPAR_clean L.ln_RevPAR_clean L2.ln_RevPAR_clean ///
    sim_mean_std_hotel sim_post2020 ///
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc ///
    lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness ///
    covid_2020 covid_2021 covid_2022 i.Mon, ///
    gmm(L.ln_RevPAR_clean L2.ln_RevPAR_clean, laglimits(7 10) collapse) ///
    gmm(sim_mean_std_hotel sim_post2020, laglimits(6 7) collapse) ///
    iv(ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc ///
       lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness ///
       covid_2020 covid_2021 covid_2022 i.Mon) ///
    twostep robust small orthogonal
restore

log close
