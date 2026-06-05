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
local log_dir "`out_root'/stata-log"
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
        style_luxury style_upscale travelers_choice_flag
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

keep if cs_sample_focus100 == 1

capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)


winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199_cym) by(City ym)
winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595_cym) by(City ym)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199_cym) by(City ym)
winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595_cym) by(City ym)
*******************************************************
************ 2. vertical quality boundaries ************
*******************************************************

estimates clear

* V1. Filled star-class boundary using the raw filled star value. (上一个do已经做完了
reghdfe ln_RevPAR_clean c.sim_mean##c.star_class_final_raw ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & !missing(star_class_final_raw), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_star

* V2. Profile quality index boundary using the raw profile quality index.
tab tp_quality_index
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.hotel_avg_rating ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(tp_quality_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_quality

* V2.a-b
capture drop med_tp_quality_index high_quality_index
bysort Zip ym: egen med_tp_quality_index = median(tp_quality_index)
generate high_quality_index = 1 if cs_sample_focus100 == 1 & tp_quality_index >=  med_tp_quality_index
replace high_quality_index = 0 if cs_sample_focus100 == 1 & tp_quality_index <  med_tp_quality_index

* V2a-V2b. Grouped quality-index regressions.
* Split hotels into below-median and above-median profile-quality groups within each Zip-month cell.
reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_quality_index == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_quality_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_quality_index == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_quality_high


* V3. Profile rank boundary using the raw rank percentile.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.tp_rank_pct ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(tp_rank_pct), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_rank

capture drop med_tp_rank_pct high_tp_rank_pct
bysort Zip ym: egen med_tp_rank_pct = median(tp_rank_pct)
generate high_tp_rank_pct = 0 if cs_sample_focus100 == 1 & tp_rank_pct >  med_tp_rank_pct
replace high_tp_rank_pct = 1 if cs_sample_focus100 == 1 & tp_rank_pct <  med_tp_rank_pct

* V3a-V3b. Grouped rank-position regressions.
* Split hotels into lower-status and higher-status rank groups within each Zip-month cell.
reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_tp_rank_pct == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_rank_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_tp_rank_pct == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store pv_rank_high

esttab pv_star pv_quality pv_rank using "`table_dir'/routeA_product_vertical_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("star" "quality" "rank") nogap compress
esttab pv_star pv_quality pv_rank using "`csv_dir'/routeA_product_vertical_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("star" "quality" "rank") nogap

esttab pv_quality_low pv_quality_high pv_rank_low pv_rank_high using "`table_dir'/routeA_product_vertical_grouped_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("quality low" "quality high" "rank low" "rank high") nogap compress
esttab pv_quality_low pv_quality_high pv_rank_low pv_rank_high using "`csv_dir'/routeA_product_vertical_grouped_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("quality low" "quality high" "rank low" "rank high") nogap

*******************************************************
************ 3. horizontal differentiation *************
*******************************************************

estimates clear

* H1. Amenity breadth boundary using the raw amenity-count measure.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.tp_amenity_count ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(tp_amenity_count), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_amenity

* H1a-H1b. Grouped amenity-count regressions.
* Split hotels into below-median and above-median amenity-breadth groups within each Zip-month cell.
capture drop med_tp_amenity_count high_tp_amenity_count
bysort Zip ym: egen med_tp_amenity_count = median(tp_amenity_count)
generate high_tp_amenity_count = 1 if cs_sample_focus100 == 1 & tp_amenity_count >med_tp_amenity_count
replace high_tp_amenity_count = 0 if cs_sample_focus100 == 1 & tp_amenity_count < med_tp_amenity_count


reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595  ///
    if cs_sample_focus100 == 1 & high_tp_amenity_count == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_amenity_low

reghdfe ln_RevPAR_clean_w595  sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_tp_amenity_count == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_amenity_high

* H2. Recreation-style boundary using the raw recreation-amenity index.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.amen_rec_index ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(amen_rec_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_recreation

* H2a-H2b. Grouped recreation-amenity regressions.
* Split hotels into below-median and above-median recreation-amenity groups within each Zip-month cell.
capture drop med_amen_rec_index high_amen_rec_index
bysort Zip ym: egen med_amen_rec_index = median(amen_rec_index)
generate high_amen_rec_index = 1 if cs_sample_focus100 == 1 & amen_rec_index > med_amen_rec_index
replace high_amen_rec_index = 0 if cs_sample_focus100 == 1 & amen_rec_index < med_amen_rec_index

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_amen_rec_index == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_recreation_low

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & high_amen_rec_index == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_recreation_high

* H3. Service-amenity boundary using the raw service-amenity index.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.amen_serv_index ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(amen_serv_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_serviceamen

* H3a-H3b. Grouped service-amenity regressions.
* Split hotels into below-median and above-median service-amenity groups within each Zip-month cell.
capture drop med_amen_serv_index high_amen_serv_index
bysort Zip ym: egen med_amen_serv_index = median(amen_serv_index)
generate high_amen_serv_index = 1 if cs_sample_focus100 == 1 & amen_serv_index >= med_amen_serv_index
replace high_amen_serv_index = 0 if cs_sample_focus100 == 1 & amen_serv_index < med_amen_serv_index

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & high_amen_serv_index == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_serviceamen_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & high_amen_serv_index == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_serviceamen_high

* H4. Business-amenity boundary using the raw business-amenity index.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.amen_bus_index ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & !missing(amen_bus_index), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_businessamen

* H4a-H4b. Grouped business-amenity regressions.
* Split hotels into below-median and above-median business-amenity groups within each Zip-month cell.
capture drop med_amen_bus_index high_amen_bus_index
bysort Zip ym: egen med_amen_bus_index = median(amen_bus_index)
generate high_amen_bus_index = 1 if cs_sample_focus100 == 1 & amen_bus_index >= med_amen_bus_index
replace high_amen_bus_index = 0 if cs_sample_focus100 == 1 & amen_bus_index < med_amen_bus_index

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_amen_bus_index == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_businessamen_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_amen_bus_index == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_businessamen_high

* H5. Upscale-style boundary.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.style_upscale ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(style_upscale), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_upscale

* H5a-H5b. Grouped upscale-style regressions.
* Estimate the ARS slope separately for non-upscale and upscale-style hotels.
reghdfe ln_RevPAR_clean_w595_cym sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & style_upscale == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_upscale_low

reghdfe ln_RevPAR_clean_w595_cym sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & style_upscale == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_upscale_high

* H6. Luxury-style boundary.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.style_luxury ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(style_luxury), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_luxury

* H6a-H6b. Grouped luxury-style regressions.
* Estimate the ARS slope separately for non-luxury-style and luxury-style hotels.
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & style_luxury == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_luxury_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & style_luxury == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_luxury_high

* H7. Travelers' Choice boundary.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##i.travelers_choice_flag ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(travelers_choice_flag), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_choice

* H7a-H7b. Grouped Travelers' Choice regressions.
* Estimate the ARS slope separately for non-Travelers'-Choice and Travelers'-Choice hotels.
reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & travelers_choice_flag == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_choice_low

reghdfe ln_RevPAR_clean sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if cs_sample_focus100 == 1 & travelers_choice_flag == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ph_choice_high

esttab ph_amenity ph_recreation ph_serviceamen ph_businessamen ph_upscale ph_luxury ph_choice using "`table_dir'/routeA_product_horizontal_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("amenity count" "recreation" "service amen" "business amen" "upscale" "luxury" "choice") nogap compress
esttab ph_amenity ph_recreation ph_serviceamen ph_businessamen ph_upscale ph_luxury ph_choice using "`csv_dir'/routeA_product_horizontal_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("amenity count" "recreation" "service amen" "business amen" "upscale" "luxury" "choice") nogap

esttab ph_amenity_low ph_amenity_high ph_recreation_low ph_recreation_high ph_serviceamen_low ph_serviceamen_high ph_businessamen_low ph_businessamen_high ph_upscale_low ph_upscale_high ph_luxury_low ph_luxury_high ph_choice_low ph_choice_high using "`table_dir'/routeA_product_horizontal_grouped_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("amenity low" "amenity high" "recreation low" "recreation high" "service low" "service high" "business low" "business high" "upscale 0" "upscale 1" "luxury 0" "luxury 1" "choice 0" "choice 1") nogap compress
esttab ph_amenity_low ph_amenity_high ph_recreation_low ph_recreation_high ph_serviceamen_low ph_serviceamen_high ph_businessamen_low ph_businessamen_high ph_upscale_low ph_upscale_high ph_luxury_low ph_luxury_high ph_choice_low ph_choice_high using "`csv_dir'/routeA_product_horizontal_grouped_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("amenity low" "amenity high" "recreation low" "recreation high" "service low" "service high" "business low" "business high" "upscale 0" "upscale 1" "luxury 0" "luxury 1" "choice 0" "choice 1") nogap

*******************************************************
************ 4. price and scale boundaries *************
*******************************************************

estimates clear

* P1. Price boundary using the raw profile price midpoint.
reghdfe ln_RevPAR_clean_w595 c.sim_mean##c.ln_tp_price_mid ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595 ///
    if cs_sample_focus100 == 1 & !missing(ln_tp_price_mid), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ps_price

* P1a-P1b. Grouped price-level regressions.
* Split hotels into below-median and above-median profile-price groups within each Zip-month cell.
capture drop med_ln_tp_price_mid high_ln_tp_price_mid
bysort Zip ym: egen med_ln_tp_price_mid = median(ln_tp_price_mid)
generate high_ln_tp_price_mid = 1 if cs_sample_focus100 == 1 & ln_tp_price_mid > med_ln_tp_price_mid
replace high_ln_tp_price_mid = 0 if cs_sample_focus100 == 1 & ln_tp_price_mid < med_ln_tp_price_mid

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_ln_tp_price_mid == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ps_price_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
     ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if cs_sample_focus100 == 1 & high_ln_tp_price_mid == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ps_price_high


esttab ps_price ps_room ps_reviews using "`table_dir'/routeA_product_pricescale_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("price" "rooms" "profile reviews") nogap compress
esttab ps_price ps_room ps_reviews using "`csv_dir'/routeA_product_pricescale_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("price" "rooms" "profile reviews") nogap

esttab ps_price_low ps_price_high ps_room_low ps_room_high ps_reviews_low ps_reviews_high using "`table_dir'/routeA_product_pricescale_grouped_`run_id'.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("price low" "price high" "rooms low" "rooms high" "reviews low" "reviews high") nogap compress
esttab ps_price_low ps_price_high ps_room_low ps_room_high ps_reviews_low ps_reviews_high using "`csv_dir'/routeA_product_pricescale_grouped_`run_id'.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("price low" "price high" "rooms low" "rooms high" "reviews low" "reviews high") nogap

log close
