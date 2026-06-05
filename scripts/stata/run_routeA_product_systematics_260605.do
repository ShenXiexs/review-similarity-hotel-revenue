*******************************************************
* run_routeA_product_systematics_260605.do
* Route A extension: ARS as the main effect, with hotel
* product boundaries grouped into vertical quality,
* horizontal differentiation, and price/scale.
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
local csv_dir "`out_root'/csv"
local log_dir "`out_root'/logs"
local run_id "260605"

local data_main "`data_dir'/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local profile_csv "`project'/full-data/hotel_profile_TP.csv"

cap mkdir "`table_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`log_dir'"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'."
    exit 601
}

capture confirm file "`profile_csv'"
if _rc {
    di as error "Cannot find `profile_csv'."
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

*******************************************************
************ 1. load data and merge profile ************
*******************************************************

use "`data_main'", clear
log using "`log_dir'/run_routeA_product_systematics_`run_id'.log", text replace

di as text "Data source: `data_main'"
di as text "Profile source: `profile_csv'"

tempfile hotel_profile
preserve
    import delimited using "`profile_csv'", varnames(1) clear bindquote(loose) maxquotedrows(unlimited) encoding("UTF-8")
    keep hotel_id_ta hotel_class hotel_price_low hotel_price_high hotel_room review_count ///
        hotel_avg_rating hotel_location_rating hotel_rooms_rating hotel_value_rating ///
        hotel_cleanliness_rating hotel_service_rating hotel_sleep_quality_rating ///
        hotel_rank hotel_amenities hotel_style travelers_choice

    rename hotel_id_ta HotelID
    capture confirm string variable HotelID
    if _rc {
        tostring HotelID, replace format(%18.0f)
    }
    replace HotelID = strtrim(HotelID)
    duplicates drop HotelID, force

    foreach v of varlist hotel_class hotel_price_low hotel_price_high hotel_room review_count ///
        hotel_avg_rating hotel_location_rating hotel_rooms_rating hotel_value_rating ///
        hotel_cleanliness_rating hotel_service_rating hotel_sleep_quality_rating {
        capture destring `v', replace ignore(",") force
    }

    rename hotel_class hotel_class_profile_raw
    gen double tp_price_mid = (hotel_price_low + hotel_price_high) / 2 if !missing(hotel_price_low, hotel_price_high)
    gen double ln_tp_price_mid = ln(tp_price_mid) if tp_price_mid > 0
    gen double ln_tp_room = ln(hotel_room + 1) if !missing(hotel_room)
    gen double ln_tp_review_count = ln(review_count + 1) if !missing(review_count)

    egen double tp_quality_index = rowmean(hotel_avg_rating hotel_location_rating hotel_rooms_rating hotel_value_rating hotel_cleanliness_rating hotel_service_rating hotel_sleep_quality_rating)
    egen double tp_service_quality = rowmean(hotel_cleanliness_rating hotel_service_rating hotel_rooms_rating)

    gen str244 hotel_rank_short = substr(hotel_rank, 1, 244)
    replace hotel_rank_short = subinstr(hotel_rank_short, ",", "", .)
    gen double tp_rank_num = .
    gen double tp_rank_total = .
    replace tp_rank_num = real(regexs(1)) if regexm(hotel_rank_short, "#([0-9]+) of ([0-9]+)")
    replace tp_rank_total = real(regexs(2)) if regexm(hotel_rank_short, "#([0-9]+) of ([0-9]+)")
    gen double tp_rank_pct = tp_rank_num / tp_rank_total if tp_rank_num > 0 & tp_rank_total > 0

    gen strL hotel_amenities_lc = ustrlower(hotel_amenities)
    gen strL hotel_style_lc = ustrlower(hotel_style)
    gen double tp_amenity_count = 0 if !missing(hotel_amenities)
    replace tp_amenity_count = strlen(hotel_amenities) - strlen(subinstr(hotel_amenities, ",", "", .)) + 1 if !missing(hotel_amenities) & strtrim(hotel_amenities) != ""

    gen byte amenity_pool = regexm(hotel_amenities_lc, "pool") if !missing(hotel_amenities_lc)
    gen byte amenity_breakfast = regexm(hotel_amenities_lc, "breakfast") if !missing(hotel_amenities_lc)
    gen byte amenity_fitness = regexm(hotel_amenities_lc, "fitness|gym|workout") if !missing(hotel_amenities_lc)
    gen byte amenity_business = regexm(hotel_amenities_lc, "business center|business") if !missing(hotel_amenities_lc)
    gen byte amenity_meeting = regexm(hotel_amenities_lc, "meeting") if !missing(hotel_amenities_lc)
    gen byte amenity_spa = regexm(hotel_amenities_lc, "spa|hot tub|jacuzzi|sauna") if !missing(hotel_amenities_lc)
    gen byte amenity_golf = regexm(hotel_amenities_lc, "golf") if !missing(hotel_amenities_lc)
    gen byte amenity_parking = regexm(hotel_amenities_lc, "parking|park") if !missing(hotel_amenities_lc)
    gen byte amenity_wifi = regexm(hotel_amenities_lc, "wifi|wi-fi|internet") if !missing(hotel_amenities_lc)
    gen byte amenity_laundry = regexm(hotel_amenities_lc, "laundry|dry cleaning") if !missing(hotel_amenities_lc)
    gen byte amenity_frontdesk = regexm(hotel_amenities_lc, "24-hour|front desk|concierge") if !missing(hotel_amenities_lc)
    gen byte amenity_conference = regexm(hotel_amenities_lc, "conference|banquet") if !missing(hotel_amenities_lc)
    gen byte amenity_workspace = regexm(hotel_amenities_lc, "workspace|desk|work area") if !missing(hotel_amenities_lc)

    gen byte style_business = regexm(hotel_style_lc, "business") if !missing(hotel_style_lc)
    gen byte style_family = regexm(hotel_style_lc, "family") if !missing(hotel_style_lc)
    gen byte style_budget = regexm(hotel_style_lc, "budget|value") if !missing(hotel_style_lc)
    gen byte style_luxury = regexm(hotel_style_lc, "luxury|romantic|boutique") if !missing(hotel_style_lc)
    gen byte style_modern = regexm(hotel_style_lc, "modern|trendy") if !missing(hotel_style_lc)

    foreach v of varlist amenity_pool amenity_breakfast amenity_fitness amenity_business amenity_meeting amenity_spa amenity_golf amenity_parking amenity_wifi amenity_laundry amenity_frontdesk amenity_conference amenity_workspace style_business style_family style_budget style_luxury style_modern {
        replace `v' = 0 if missing(`v')
    }

    gen double amen_rec_index = amenity_pool + amenity_fitness + amenity_spa + amenity_golf
    gen double amen_serv_index = amenity_breakfast + amenity_parking + amenity_wifi + amenity_laundry + amenity_frontdesk
    gen double amen_bus_index = amenity_business + amenity_meeting + amenity_conference + amenity_workspace
    gen byte style_business_family = (style_business == 1 | style_family == 1)
    gen byte style_budget_value = style_budget
    gen byte style_upscale = (style_luxury == 1 | style_modern == 1)

    gen strL travelers_choice_text = ustrlower(travelers_choice)
    gen byte travelers_choice_flag = regexm(travelers_choice_text, "travelers' choice|best of the best") if !missing(travelers_choice_text)
    replace travelers_choice_flag = 0 if missing(travelers_choice_flag)

    keep HotelID hotel_class_profile_raw ln_tp_price_mid ln_tp_room ln_tp_review_count ///
        tp_quality_index tp_service_quality tp_rank_pct tp_amenity_count amen_rec_index ///
        amen_serv_index amen_bus_index style_business_family style_budget_value ///
        style_upscale travelers_choice_flag
    save `hotel_profile', replace
restore

merge m:1 HotelID using `hotel_profile', keep(master match) nogen

capture confirm variable star_class_raw
if _rc {
    gen double star_class_raw = .
    capture confirm numeric variable star_class
    if !_rc replace star_class_raw = star_class
}
capture drop star_class_final_raw
gen double star_class_final_raw = star_class_raw
replace star_class_final_raw = hotel_class_profile_raw if missing(star_class_final_raw) & !missing(hotel_class_profile_raw)

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
xtset hotel_id_num ym
sort hotel_id_num ym

capture drop ln_RevPAR_clean_w199 ln_lag_RevPAR_clean_w199
gen double ln_RevPAR_clean_w199 = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w199 = ln_lag_RevPAR_clean
quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local y_p1 = r(r1)
local y_p99 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local ly_p1 = r(r1)
local ly_p99 = r(r2)
replace ln_RevPAR_clean_w199 = `y_p1' if ln_RevPAR_clean_w199 < `y_p1' & !missing(ln_RevPAR_clean_w199)
replace ln_RevPAR_clean_w199 = `y_p99' if ln_RevPAR_clean_w199 > `y_p99' & !missing(ln_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p1' if ln_lag_RevPAR_clean_w199 < `ly_p1' & !missing(ln_lag_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p99' if ln_lag_RevPAR_clean_w199 > `ly_p99' & !missing(ln_lag_RevPAR_clean_w199)

capture drop sim_mean_c starf_c tpqual_c tpserv_c tprank_c tpamen_c amenrec_c amensrv_c amenbus_c tpprice_c tproom_c tprev_c
quietly summarize sim_mean if cs_sample_focus100 == 1 & !missing(sim_mean)
gen double sim_mean_c = sim_mean - r(mean) if !missing(sim_mean)
quietly summarize star_class_final_raw if cs_sample_focus100 == 1 & !missing(star_class_final_raw)
gen double starf_c = star_class_final_raw - r(mean) if !missing(star_class_final_raw)
quietly summarize tp_quality_index if cs_sample_focus100 == 1 & !missing(tp_quality_index)
gen double tpqual_c = tp_quality_index - r(mean) if !missing(tp_quality_index)
quietly summarize tp_service_quality if cs_sample_focus100 == 1 & !missing(tp_service_quality)
gen double tpserv_c = tp_service_quality - r(mean) if !missing(tp_service_quality)
quietly summarize tp_rank_pct if cs_sample_focus100 == 1 & !missing(tp_rank_pct)
gen double tprank_c = tp_rank_pct - r(mean) if !missing(tp_rank_pct)
quietly summarize tp_amenity_count if cs_sample_focus100 == 1 & !missing(tp_amenity_count)
gen double tpamen_c = tp_amenity_count - r(mean) if !missing(tp_amenity_count)
quietly summarize amen_rec_index if cs_sample_focus100 == 1 & !missing(amen_rec_index)
gen double amenrec_c = amen_rec_index - r(mean) if !missing(amen_rec_index)
quietly summarize amen_serv_index if cs_sample_focus100 == 1 & !missing(amen_serv_index)
gen double amensrv_c = amen_serv_index - r(mean) if !missing(amen_serv_index)
quietly summarize amen_bus_index if cs_sample_focus100 == 1 & !missing(amen_bus_index)
gen double amenbus_c = amen_bus_index - r(mean) if !missing(amen_bus_index)
quietly summarize ln_tp_price_mid if cs_sample_focus100 == 1 & !missing(ln_tp_price_mid)
gen double tpprice_c = ln_tp_price_mid - r(mean) if !missing(ln_tp_price_mid)
quietly summarize ln_tp_room if cs_sample_focus100 == 1 & !missing(ln_tp_room)
gen double tproom_c = ln_tp_room - r(mean) if !missing(ln_tp_room)
quietly summarize ln_tp_review_count if cs_sample_focus100 == 1 & !missing(ln_tp_review_count)
gen double tprev_c = ln_tp_review_count - r(mean) if !missing(ln_tp_review_count)

*******************************************************
************ 2. vertical quality boundaries ************
*******************************************************

estimates clear

* V1. Filled star-class boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.starf_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(star_class_final_raw), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_star

* V2. Profile quality index boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.tpqual_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(tp_quality_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_quality

* V3. Profile service-quality boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.tpserv_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(tp_service_quality), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_service

* V4. Profile rank boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.tprank_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(tp_rank_pct), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_rank

esttab pv_star pv_quality pv_service pv_rank using "`table_dir'/routeA_product_vertical_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("star" "quality" "service" "rank") nogap compress
esttab pv_star pv_quality pv_service pv_rank using "`csv_dir'/routeA_product_vertical_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("star" "quality" "service" "rank") nogap

*******************************************************
************ 3. horizontal differentiation *************
*******************************************************

estimates clear

* H1. Amenity breadth boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.tpamen_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(tp_amenity_count), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_amenity

* H2. Recreation-style boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.amenrec_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(amen_rec_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_recreation

* H3. Service-amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.amensrv_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(amen_serv_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_serviceamen

* H4. Business-amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.amenbus_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(amen_bus_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_businessamen

* H5. Upscale-style boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.style_upscale ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(style_upscale), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_upscale

* H6. Travelers' Choice boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##i.travelers_choice_flag ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(travelers_choice_flag), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_choice

esttab ph_amenity ph_recreation ph_serviceamen ph_businessamen ph_upscale ph_choice using "`table_dir'/routeA_product_horizontal_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("amenity count" "recreation" "service amen" "business amen" "upscale" "choice") nogap compress
esttab ph_amenity ph_recreation ph_serviceamen ph_businessamen ph_upscale ph_choice using "`csv_dir'/routeA_product_horizontal_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("amenity count" "recreation" "service amen" "business amen" "upscale" "choice") nogap

*******************************************************
************ 4. price and scale boundaries *************
*******************************************************

estimates clear

* P1. Price boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.tpprice_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(ln_tp_price_mid), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ps_price

* P2. Room-count scale boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.tproom_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(ln_tp_room), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ps_room

* P3. Profile review-stock scale boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_c##c.tprev_c ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(ln_tp_review_count), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ps_reviews

esttab ps_price ps_room ps_reviews using "`table_dir'/routeA_product_pricescale_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("price" "rooms" "profile reviews") nogap compress
esttab ps_price ps_room ps_reviews using "`csv_dir'/routeA_product_pricescale_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("price" "rooms" "profile reviews") nogap

log close
