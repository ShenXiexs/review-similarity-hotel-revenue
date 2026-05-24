*******************************************************
* run_core_simi_dual_route_mr_screen_260524.do
* Clean screening regressions for:
* A) ARS main effect and moderators
* B) Review volume main effect with ARS moderation
* C) Management response extension
*******************************************************

version 17.0
clear all
set more off
set linesize 255
mata: mata set matafavor speed
capture log close

*******************************************************
************ 0. paths and required packages ************
*******************************************************

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/core_simi_260501"
local data_dir "`out_root'/data"
local table_dir "`out_root'/tables_explicit"
local log_dir "`out_root'/logs"
local run_id "260524"

local data_core "`data_dir'/core_simi_panel_260501.dta"
local data_mr "`data_dir'/core_simi_panel_260501_with_mr_260524.dta"

cap mkdir "`table_dir'"
cap mkdir "`log_dir'"

capture confirm file "`data_mr'"
if !_rc {
    local data_main "`data_mr'"
    local has_mr 1
}
else {
    local data_main "`data_core'"
    local has_mr 0
}

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'."
    exit 601
}

capture which reghdfe
if _rc {
    di as error "reghdfe not found. Install it first: ssc install reghdfe, replace"
    exit 199
}

capture which esttab
if _rc {
    di as error "esttab not found. Install it first: ssc install estout, replace"
    exit 199
}

use "`data_main'", clear
log using "`log_dir'/run_core_simi_dual_route_mr_screen_260524.log", text replace

di as text "Data source: `data_main'"
di as text "Management response variables available: `has_mr'"

*******************************************************
************ 1. panel setup and generated variables ****
*******************************************************

capture drop hotel_id_num
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

capture confirm variable Year
if _rc {
    gen Year = year(dofm(ym))
}

capture confirm variable Mon
if _rc {
    gen Mon = month(dofm(ym))
}

xtset hotel_id_num ym
sort hotel_id_num ym

keep if cs_sample_focus100 == 1

capture drop covid2020 covid2020_2022 post2020 pre_covid
gen byte covid2020 = (Year == 2020)
gen byte covid2020_2022 = inrange(Year, 2020, 2022)
gen byte post2020 = (Year >= 2020)
gen byte pre_covid = (Year <= 2019)

capture drop ln_RevPAR_clean_w ln_lag_RevPAR_clean_w
gen double ln_RevPAR_clean_w = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w = ln_lag_RevPAR_clean

capture which winsor2
if !_rc {
    winsor2 ln_RevPAR_clean_w, cut(1 99) replace
    winsor2 ln_lag_RevPAR_clean_w, cut(1 99) replace
}
else {
    di as text "winsor2 not found; applying manual 1/99 winsorization fallback."
    foreach v in ln_RevPAR_clean_w ln_lag_RevPAR_clean_w {
        quietly summarize `v', detail
        local p1 = r(p1)
        local p99 = r(p99)
        replace `v' = `p1' if `v' < `p1' & !missing(`v')
        replace `v' = `p99' if `v' > `p99' & !missing(`v')
    }
}

capture drop mean_ln_recent_volumn_cym mean_ln_lag_volumn_acc_cym rel_ln_recent_volumn rel_ln_lag_volumn_acc
bysort CityID ym: egen mean_ln_recent_volumn_cym = mean(ln_recent_volumn)
bysort CityID ym: egen mean_ln_lag_volumn_acc_cym = mean(ln_lag_volumn_acc)
gen double rel_ln_recent_volumn = ln_recent_volumn - mean_ln_recent_volumn_cym
gen double rel_ln_lag_volumn_acc = ln_lag_volumn_acc - mean_ln_lag_volumn_acc_cym

if `has_mr' == 1 {
    foreach v in lag_mr_any lag_mr_count lag_mr_rate lag_mr_text_chars lag_mr_text_words lag_mr_avg_text_chars lag_mr_avg_text_words {
        capture confirm variable `v'
        if !_rc {
            replace `v' = 0 if missing(`v')
        }
    }
}

foreach v in sim_mean ln_recent_volumn ln_lag_volumn_acc rel_ln_recent_volumn rel_ln_lag_volumn_acc ln_lag_avg_com_RevPAR price_gap zip_n_sample star_class lag_mr_rate lag_mr_text_words lag_mr_avg_text_words {
    capture confirm variable `v'
    if !_rc {
        quietly summarize `v' if !missing(`v')
        capture drop z_`v'
        if r(N) > 1 & r(sd) > 0 {
            gen double z_`v' = (`v' - r(mean)) / r(sd) if !missing(`v')
        }
        else {
            gen double z_`v' = .
        }
    }
}

capture drop z_ln_recent_volumn_sq z_ln_lag_volumn_acc_sq
capture confirm variable z_ln_recent_volumn
if !_rc gen double z_ln_recent_volumn_sq = z_ln_recent_volumn^2
capture confirm variable z_ln_lag_volumn_acc
if !_rc gen double z_ln_lag_volumn_acc_sq = z_ln_lag_volumn_acc^2

*******************************************************
************ 2. explicit control sets ******************
*******************************************************

local controls_a ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w
local controls_b_recent recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w
local controls_b_cum ln_recent_volumn recent_sd rating_last_5 lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w

*******************************************************
************ 3. Route A: ARS main effect ***************
*******************************************************

estimates clear

reghdfe ln_RevPAR_clean_w sim_mean `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store a_base

reghdfe ln_RevPAR_clean_w c.z_sim_mean##i.covid2020 `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store a_covid2020

reghdfe ln_RevPAR_clean_w c.z_sim_mean##i.covid2020_2022 `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store a_covid2022

esttab a_base a_covid2020 a_covid2022 using "`table_dir'/dual_route_a_baseline_260524.rtf", replace ///
    order(sim_mean z_sim_mean 1.covid2020#c.z_sim_mean 1.covid2020_2022#c.z_sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("A baseline" "A x 2020" "A x 2020-2022") ///
    nogap compress

*******************************************************
************ 4. Route A: market/product moderators *****
*******************************************************

estimates clear

reghdfe ln_RevPAR_clean_w c.z_sim_mean##c.z_ln_lag_avg_com_RevPAR `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store a_mkt_comp

reghdfe ln_RevPAR_clean_w c.z_sim_mean##c.z_price_gap `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store a_mkt_gap

reghdfe ln_RevPAR_clean_w c.z_sim_mean##c.z_zip_n_sample `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store a_mkt_density

reghdfe ln_RevPAR_clean_w c.z_sim_mean##c.z_star_class `controls_a' if !missing(star_class), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store a_product_star

capture confirm variable chain
if !_rc {
    reghdfe ln_RevPAR_clean_w c.z_sim_mean##i.chain `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store a_product_chain

    esttab a_mkt_comp a_mkt_gap a_mkt_density a_product_star a_product_chain using "`table_dir'/dual_route_a_moderators_260524.rtf", replace ///
        order(z_sim_mean c.z_sim_mean#c.z_ln_lag_avg_com_RevPAR c.z_sim_mean#c.z_price_gap c.z_sim_mean#c.z_zip_n_sample c.z_sim_mean#c.z_star_class 1.chain#c.z_sim_mean ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w) ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("Comp RevPAR" "Price gap" "ZIP density" "Star" "Chain") ///
        nogap compress
}
else {
    esttab a_mkt_comp a_mkt_gap a_mkt_density a_product_star using "`table_dir'/dual_route_a_moderators_260524.rtf", replace ///
        order(z_sim_mean c.z_sim_mean#c.z_ln_lag_avg_com_RevPAR c.z_sim_mean#c.z_price_gap c.z_sim_mean#c.z_zip_n_sample c.z_sim_mean#c.z_star_class ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w) ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("Comp RevPAR" "Price gap" "ZIP density" "Star") ///
        nogap compress
}

*******************************************************
************ 5. Route B: volume x ARS ******************
*******************************************************

estimates clear

reghdfe ln_RevPAR_clean_w c.z_ln_recent_volumn##c.z_sim_mean `controls_b_recent', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store b_recent

reghdfe ln_RevPAR_clean_w c.z_ln_lag_volumn_acc##c.z_sim_mean `controls_b_cum', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store b_cum

reghdfe ln_RevPAR_clean_w c.z_ln_recent_volumn##c.z_sim_mean c.z_ln_recent_volumn_sq##c.z_sim_mean `controls_b_recent', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store b_recent_sq

reghdfe ln_RevPAR_clean_w c.z_ln_lag_volumn_acc##c.z_sim_mean c.z_ln_lag_volumn_acc_sq##c.z_sim_mean `controls_b_cum', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store b_cum_sq

reghdfe ln_RevPAR_clean_w c.z_rel_ln_recent_volumn##c.z_sim_mean `controls_b_recent', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store b_recent_rel

reghdfe ln_RevPAR_clean_w c.z_rel_ln_lag_volumn_acc##c.z_sim_mean `controls_b_cum', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store b_cum_rel

esttab b_recent b_cum b_recent_sq b_cum_sq b_recent_rel b_cum_rel using "`table_dir'/dual_route_b_volume_ars_260524.rtf", replace ///
    order(z_ln_recent_volumn z_ln_lag_volumn_acc z_rel_ln_recent_volumn z_rel_ln_lag_volumn_acc z_sim_mean c.z_ln_recent_volumn#c.z_sim_mean c.z_ln_lag_volumn_acc#c.z_sim_mean c.z_ln_recent_volumn_sq#c.z_sim_mean c.z_ln_lag_volumn_acc_sq#c.z_sim_mean c.z_rel_ln_recent_volumn#c.z_sim_mean c.z_rel_ln_lag_volumn_acc#c.z_sim_mean recent_sd rating_last_5 ln_lag_volumn_acc ln_recent_volumn lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    mtitles("Recent" "Cumulative" "Recent sq" "Cumulative sq" "Rel recent" "Rel cumulative") ///
    nogap compress

*******************************************************
************ 6. Route C: management response ***********
*******************************************************

if `has_mr' == 1 {
    estimates clear

    reghdfe ln_RevPAR_clean_w c.z_sim_mean##i.lag_mr_any `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store c_ars_any

    reghdfe ln_RevPAR_clean_w c.z_sim_mean##c.z_lag_mr_rate `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store c_ars_rate

    reghdfe ln_RevPAR_clean_w c.z_ln_recent_volumn##c.z_sim_mean lag_mr_any z_lag_mr_rate z_lag_mr_text_words `controls_b_recent', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store c_b_recent_ctrl

    reghdfe ln_RevPAR_clean_w c.z_ln_lag_volumn_acc##c.z_sim_mean lag_mr_any z_lag_mr_rate z_lag_mr_text_words `controls_b_cum', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store c_b_cum_ctrl

    esttab c_ars_any c_ars_rate c_b_recent_ctrl c_b_cum_ctrl using "`table_dir'/dual_route_c_management_response_260524.rtf", replace ///
        order(z_sim_mean 1.lag_mr_any#c.z_sim_mean c.z_sim_mean#c.z_lag_mr_rate z_ln_recent_volumn z_ln_lag_volumn_acc c.z_ln_recent_volumn#c.z_sim_mean c.z_ln_lag_volumn_acc#c.z_sim_mean lag_mr_any z_lag_mr_rate z_lag_mr_text_words ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w) ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("ARS x MR any" "ARS x MR rate" "Recent vol + MR" "Cumulative vol + MR") ///
        nogap compress

    estimates clear

    reghdfe ln_recent_volumn lag_mr_any z_lag_mr_rate z_lag_mr_text_words recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store c_mech_volume

    reghdfe sim_mean lag_mr_any z_lag_mr_rate z_lag_mr_text_words ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store c_mech_ars

    reghdfe ln_RevPAR_clean_w lag_mr_any z_lag_mr_rate z_lag_mr_text_words `controls_a', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    est store c_mech_revpar

    esttab c_mech_volume c_mech_ars c_mech_revpar using "`table_dir'/dual_route_c_response_mechanisms_260524.rtf", replace ///
        order(lag_mr_any z_lag_mr_rate z_lag_mr_text_words ln_recent_volumn sim_mean recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w) ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("DV: Review volume" "DV: ARS" "DV: RevPAR") ///
        nogap compress
}
else {
    di as text "Skipping Route C. Run scripts/r/build_management_response_panel_260524.R first to create `data_mr'."
}

log close
