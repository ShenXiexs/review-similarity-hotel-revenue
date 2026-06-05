*******************************************************
* run_core_simi_story_exploration_260524.do
* ARS, review volume, and management-response story tests.
*
* Style follows run_core_simi_explicit_regressions_260501.do:
* - No regression wrapper program.
* - No candidate-model loop.
* - Every reported model writes the DV, focal variables,
*   controls, FE, and clustering explicitly.
* - Interactions use raw/log variables. Centered variables are
*   used only to make lower-order coefficients interpretable at
*   the sample mean; they are not standardized.
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
local run_id "260524"

local data_main "`data_dir'/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local profile_csv "`project'/full-data/hotel_profile_TP.csv"

cap mkdir "`table_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`log_dir'"

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find `data_main'. Run scripts/r/build_review_sentiment_panel_260526.R first."
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
************ 1. load data and prepare variables ********
*******************************************************

use "`data_main'", clear
log using "`log_dir'/run_core_simi_story_exploration_260524.log", text replace

di as text "Data source: `data_main'"
di as text "Hotel profile source: `profile_csv'"

*******************************************************
************ 1.0 Hotel Profile merge ******************
*******************************************************

* TripAdvisor hotel profile adds product characteristics.
* It is merged in memory only; the source panel .dta is not overwritten.
tempfile hotel_profile
preserve
    import delimited using "`profile_csv'", varnames(1) clear bindquote(strict) encoding("UTF-8")
    local profile_raw_n = _N

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

    duplicates tag HotelID, gen(profile_dup)
    quietly count if profile_dup > 0
    local profile_dup_n = r(N)
    if `profile_dup_n' > 0 {
        duplicates drop HotelID, force
    }
    drop profile_dup

    foreach v of varlist hotel_class hotel_price_low hotel_price_high hotel_room review_count ///
        hotel_avg_rating hotel_location_rating hotel_rooms_rating hotel_value_rating ///
        hotel_cleanliness_rating hotel_service_rating hotel_sleep_quality_rating {
        capture destring `v', replace ignore(",") force
    }

    rename hotel_class hotel_class_profile_raw

    capture drop tp_price_mid ln_tp_price_mid ln_tp_room ln_tp_review_count
    gen double tp_price_mid = (hotel_price_low + hotel_price_high) / 2 if !missing(hotel_price_low, hotel_price_high)
    gen double ln_tp_price_mid = ln(tp_price_mid) if tp_price_mid > 0
    gen double ln_tp_room = ln(hotel_room + 1) if !missing(hotel_room)
    gen double ln_tp_review_count = ln(review_count + 1) if !missing(review_count)

    capture drop tp_quality_index tp_service_quality
    egen double tp_quality_index = rowmean(hotel_avg_rating hotel_location_rating hotel_rooms_rating hotel_value_rating hotel_cleanliness_rating hotel_service_rating hotel_sleep_quality_rating)
    egen double tp_service_quality = rowmean(hotel_cleanliness_rating hotel_service_rating hotel_rooms_rating)

    capture drop tp_rank_num tp_rank_total tp_rank_pct
    gen str244 hotel_rank_short = substr(hotel_rank, 1, 244)
    replace hotel_rank_short = subinstr(hotel_rank_short, ",", "", .)
    gen double tp_rank_num = .
    gen double tp_rank_total = .
    replace tp_rank_num = real(regexs(1)) if regexm(hotel_rank_short, "#([0-9]+) of ([0-9]+)")
    replace tp_rank_total = real(regexs(2)) if regexm(hotel_rank_short, "#([0-9]+) of ([0-9]+)")
    gen double tp_rank_pct = tp_rank_num / tp_rank_total if tp_rank_num > 0 & tp_rank_total > 0

    capture drop hotel_amenities_lc hotel_style_lc tp_amenity_count
    gen strL hotel_amenities_lc = ustrlower(hotel_amenities)
    gen strL hotel_style_lc = ustrlower(hotel_style)
    gen double tp_amenity_count = 0 if !missing(hotel_amenities)
    replace tp_amenity_count = strlen(hotel_amenities) - strlen(subinstr(hotel_amenities, ",", "", .)) + 1 if !missing(hotel_amenities) & strtrim(hotel_amenities) != ""

    capture drop amenity_pool amenity_breakfast amenity_fitness amenity_pet amenity_business amenity_meeting
    gen byte amenity_pool = regexm(hotel_amenities_lc, "pool") if !missing(hotel_amenities_lc)
    gen byte amenity_breakfast = regexm(hotel_amenities_lc, "breakfast") if !missing(hotel_amenities_lc)
    gen byte amenity_fitness = regexm(hotel_amenities_lc, "fitness|gym|workout") if !missing(hotel_amenities_lc)
    gen byte amenity_pet = regexm(hotel_amenities_lc, "pet") if !missing(hotel_amenities_lc)
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

    capture drop style_business style_family style_budget style_luxury style_modern
    gen byte style_business = regexm(hotel_style_lc, "business") if !missing(hotel_style_lc)
    gen byte style_family = regexm(hotel_style_lc, "family") if !missing(hotel_style_lc)
    gen byte style_budget = regexm(hotel_style_lc, "budget|value") if !missing(hotel_style_lc)
    gen byte style_luxury = regexm(hotel_style_lc, "luxury|romantic|boutique") if !missing(hotel_style_lc)
    gen byte style_modern = regexm(hotel_style_lc, "modern|trendy") if !missing(hotel_style_lc)

    foreach v of varlist amenity_pool amenity_breakfast amenity_fitness amenity_pet amenity_business amenity_meeting ///
        amenity_spa amenity_golf amenity_parking amenity_wifi amenity_laundry amenity_frontdesk amenity_conference amenity_workspace ///
        style_business style_family style_budget style_luxury style_modern {
        replace `v' = 0 if missing(`v')
    }

    capture drop amen_rec_index amen_serv_index amen_bus_index style_business_family style_budget_value style_upscale
    gen double amen_rec_index = amenity_pool + amenity_fitness + amenity_spa + amenity_golf
    gen double amen_serv_index = amenity_breakfast + amenity_parking + amenity_wifi + amenity_laundry + amenity_frontdesk
    gen double amen_bus_index = amenity_business + amenity_meeting + amenity_conference + amenity_workspace
    gen byte style_business_family = (style_business == 1 | style_family == 1)
    gen byte style_budget_value = style_budget
    gen byte style_upscale = (style_luxury == 1 | style_modern == 1)

    capture drop travelers_choice_text travelers_choice_flag travelers_choice_best_flag
    gen strL travelers_choice_text = ustrlower(travelers_choice)
    gen byte travelers_choice_flag = regexm(travelers_choice_text, "travelers' choice|best of the best") if !missing(travelers_choice_text)
    replace travelers_choice_flag = 0 if missing(travelers_choice_flag)
    gen byte travelers_choice_best_flag = regexm(travelers_choice_text, "best of the best") if !missing(travelers_choice_text)
    replace travelers_choice_best_flag = 0 if missing(travelers_choice_best_flag)
    quietly count if travelers_choice_flag == 1
    local profile_choice_hotels = r(N)
    quietly count if travelers_choice_best_flag == 1
    local profile_choice_best_hotels = r(N)

    keep HotelID hotel_class_profile_raw hotel_price_low hotel_price_high tp_price_mid ln_tp_price_mid ///
        hotel_room ln_tp_room review_count ln_tp_review_count hotel_avg_rating hotel_location_rating ///
        hotel_rooms_rating hotel_value_rating hotel_cleanliness_rating hotel_service_rating ///
        hotel_sleep_quality_rating tp_quality_index tp_service_quality tp_rank_num tp_rank_total ///
        tp_rank_pct tp_amenity_count amenity_pool amenity_breakfast amenity_fitness amenity_pet ///
        amenity_business amenity_meeting style_business style_family style_budget style_luxury ///
        style_modern amen_rec_index amen_serv_index amen_bus_index ///
        style_business_family style_budget_value style_upscale travelers_choice_flag travelers_choice_best_flag

    save `hotel_profile', replace
restore

quietly count
local panel_raw_n = r(N)
preserve
    keep HotelID
    duplicates drop
    local panel_hotel_n = _N
restore

merge m:1 HotelID using `hotel_profile', keep(master match) gen(profile_merge)
quietly count if profile_merge == 3
local profile_match_rows = r(N)
capture drop __profile_first_hotel
bysort HotelID: gen byte __profile_first_hotel = (_n == 1)
quietly count if __profile_first_hotel == 1 & profile_merge == 3
local profile_match_hotels = r(N)
drop __profile_first_hotel

capture confirm variable star_class_raw
if _rc {
    gen double star_class_raw = .
    capture confirm numeric variable star_class
    if !_rc {
        replace star_class_raw = star_class
    }
}

quietly count if missing(star_class_raw)
local star_missing_before = r(N)
quietly count if missing(star_class_raw) & !missing(hotel_class_profile_raw)
local star_fillable = r(N)

capture drop star_class_final_raw star_class_final
gen double star_class_final_raw = star_class_raw
replace star_class_final_raw = hotel_class_profile_raw if missing(star_class_final_raw) & !missing(hotel_class_profile_raw)
egen star_class_final = group(star_class_final_raw), label
replace star_class_final = . if missing(star_class_final_raw)
label variable star_class_final_raw "Original panel star class filled by TA profile hotel_class"
label variable star_class_final "Star class factor filled by TA profile"

quietly count if missing(star_class_final_raw)
local star_missing_after = r(N)

di as text "Hotel profile audit:"
di as text "  profile rows imported: `profile_raw_n'"
di as text "  duplicate profile HotelID rows before dropping: `profile_dup_n'"
di as text "  panel rows matched to profile: `profile_match_rows' / `panel_raw_n'"
di as text "  panel hotels matched to profile: `profile_match_hotels' / `panel_hotel_n'"
di as text "  original star_class_raw missing rows: `star_missing_before'"
di as text "  star_class rows fillable from profile: `star_fillable'"
di as text "  final star_class_final_raw missing rows: `star_missing_after'"
di as text "  profile Travelers' Choice hotels: `profile_choice_hotels'"
di as text "  profile Best-of-the-Best hotels: `profile_choice_best_hotels'"

quietly count if travelers_choice_flag == 1 & cs_sample_focus100 == 1
local panel_choice_focus_rows = r(N)
capture drop __tmp_choice_hotel
bysort HotelID: gen byte __tmp_choice_hotel = (_n == 1)
quietly count if travelers_choice_flag == 1 & cs_sample_focus100 == 1 & __tmp_choice_hotel == 1
local panel_choice_focus_hotels = r(N)
drop __tmp_choice_hotel

preserve
    clear
    set obs 1
    gen long profile_rows = `profile_raw_n'
    gen long profile_duplicate_id_rows = `profile_dup_n'
    gen long panel_rows = `panel_raw_n'
    gen long panel_rows_matched = `profile_match_rows'
    gen long panel_hotels = `panel_hotel_n'
    gen long panel_hotels_matched = `profile_match_hotels'
    gen long star_missing_before = `star_missing_before'
    gen long star_fillable_from_profile = `star_fillable'
    gen long star_missing_after = `star_missing_after'
    gen long profile_travelers_choice_hotels = `profile_choice_hotels'
    gen long profile_best_of_best_hotels = `profile_choice_best_hotels'
    gen long focus100_travelers_choice_rows = `panel_choice_focus_rows'
    gen long focus100_travelers_choice_hotels = `panel_choice_focus_hotels'
    gen double row_match_rate = panel_rows_matched / panel_rows
    gen double hotel_match_rate = panel_hotels_matched / panel_hotels
    export delimited using "`csv_dir'/story_profile_merge_audit_260524.csv", replace
restore

drop profile_merge

* Create numeric hotel id for FE, panel setting, and clustering.
capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc {
    encode HotelID, gen(hotel_id_num)
}
else {
    gen long hotel_id_num = HotelID
}

* Create monthly time variable.
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

capture drop covid2020 covid2020_2022 post2020 pre_covid
gen byte covid2020 = (Year == 2020)
gen byte covid2020_2022 = inrange(Year, 2020, 2022)
gen byte post2020 = (Year >= 2020)
gen byte pre_covid = (Year <= 2019)

*******************************************************
************ 1.1 winsorized revenue outcomes **********
*******************************************************

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

capture drop ln_RevPAR_clean_w195 ln_lag_RevPAR_clean_w195
gen double ln_RevPAR_clean_w195 = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w195 = ln_lag_RevPAR_clean

quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 95)
local y_p1 = r(r1)
local y_p95 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 95)
local ly_p1 = r(r1)
local ly_p95 = r(r2)

replace ln_RevPAR_clean_w195 = `y_p1' if ln_RevPAR_clean_w195 < `y_p1' & !missing(ln_RevPAR_clean_w195)
replace ln_RevPAR_clean_w195 = `y_p95' if ln_RevPAR_clean_w195 > `y_p95' & !missing(ln_RevPAR_clean_w195)
replace ln_lag_RevPAR_clean_w195 = `ly_p1' if ln_lag_RevPAR_clean_w195 < `ly_p1' & !missing(ln_lag_RevPAR_clean_w195)
replace ln_lag_RevPAR_clean_w195 = `ly_p95' if ln_lag_RevPAR_clean_w195 > `ly_p95' & !missing(ln_lag_RevPAR_clean_w195)

capture drop ln_RevPAR_clean_w025975 ln_lag_RevPAR_clean_w025975
gen double ln_RevPAR_clean_w025975 = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_w025975 = ln_lag_RevPAR_clean

quietly _pctile ln_RevPAR_clean if cs_sample_focus50 == 1, p(2.5 97.5)
local y_p025 = r(r1)
local y_p975 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus50 == 1, p(2.5 97.5)
local ly_p025 = r(r1)
local ly_p975 = r(r2)

replace ln_RevPAR_clean_w025975 = `y_p025' if ln_RevPAR_clean_w025975 < `y_p025' & !missing(ln_RevPAR_clean_w025975)
replace ln_RevPAR_clean_w025975 = `y_p975' if ln_RevPAR_clean_w025975 > `y_p975' & !missing(ln_RevPAR_clean_w025975)
replace ln_lag_RevPAR_clean_w025975 = `ly_p025' if ln_lag_RevPAR_clean_w025975 < `ly_p025' & !missing(ln_lag_RevPAR_clean_w025975)
replace ln_lag_RevPAR_clean_w025975 = `ly_p975' if ln_lag_RevPAR_clean_w025975 > `ly_p975' & !missing(ln_lag_RevPAR_clean_w025975)

*******************************************************
************ 1.2 story variables and centering ********
*******************************************************

* Market-relative review flow: hotel review flow minus city-month average.
capture drop mean_recent_cym mean_lagvol_cym rel_ln_recent_volumn rel_ln_lag_volumn_acc
bysort CityID ym: egen mean_recent_cym = mean(ln_recent_volumn)
bysort CityID ym: egen mean_lagvol_cym = mean(ln_lag_volumn_acc)
gen double rel_ln_recent_volumn = ln_recent_volumn - mean_recent_cym
gen double rel_ln_lag_volumn_acc = ln_lag_volumn_acc - mean_lagvol_cym

* Volume nonlinearity: extra recent reviews above 10 and accumulated volume above log threshold 5.8.
capture drop recent_above10 ln_recent_above10 recent_growth lagvol_over58 low_lagvol_58 high_lagvol_58 ln_recent_volumn_sq
gen double recent_above10 = max(recent_volumn - 10, 0) if !missing(recent_volumn)
gen double ln_recent_above10 = ln(recent_above10 + 1)
gen double recent_growth = ln((recent_volumn + 1) / (lag_recent_volumn + 1)) if !missing(recent_volumn, lag_recent_volumn)
gen double lagvol_over58 = max(ln_lag_volumn_acc - 5.8, 0) if !missing(ln_lag_volumn_acc)
gen byte low_lagvol_58 = (ln_lag_volumn_acc < 5.8) if !missing(ln_lag_volumn_acc)
gen byte high_lagvol_58 = (ln_lag_volumn_acc >= 5.8) if !missing(ln_lag_volumn_acc)
gen double ln_recent_volumn_sq = ln_recent_volumn^2 if !missing(ln_recent_volumn)

* Missing management-response values are zero because no lagged response activity is observed.
foreach v of varlist lag_mr_any lag_mr_count lag_mr_rate lag_mr_text_chars lag_mr_text_words lag_mr_avg_resp_days lag_mr_med_resp_days lag_mr_quick7_share lag_mr_quick30_share lag_mr_thanks_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_contact_share lag_mr_personal_share lag_mr_positive_share lag_mr_negtone_share lag_mr_template_share lag_mr_mgr_share lag_mr_neg_review_share lag_mr_neg_response_rate lag_mr_avg_text_chars lag_mr_avg_text_words {
    replace `v' = 0 if missing(`v')
}

capture drop ln_lag_mr_words ln_lag_mr_avg_words ln_lag_mr_chars
gen double ln_lag_mr_words = ln(lag_mr_text_words + 1)
gen double ln_lag_mr_avg_words = ln(lag_mr_avg_text_words + 1)
gen double ln_lag_mr_chars = ln(lag_mr_text_chars + 1)

* Short aliases keep Stata variable names valid after adding the _centered suffix.
capture drop sent_syuzhet100 sent_bing100 sent_afinn100 sent_nrc100 lag_sent_afinn100
capture confirm variable sent_avg_per100w_syuzhet
if !_rc {
    gen double sent_syuzhet100 = sent_avg_per100w_syuzhet
}
capture confirm variable sent_avg_per100w_bing
if !_rc {
    gen double sent_bing100 = sent_avg_per100w_bing
}
capture confirm variable sent_avg_per100w_afinn
if !_rc {
    gen double sent_afinn100 = sent_avg_per100w_afinn
}
capture confirm variable sent_avg_per100w_nrc
if !_rc {
    gen double sent_nrc100 = sent_avg_per100w_nrc
}
capture confirm variable lag_sent_avg_per100w_afinn
if !_rc {
    gen double lag_sent_afinn100 = lag_sent_avg_per100w_afinn
}

* Centering keeps the original unit but makes main effects interpretable at the sample mean.
foreach v of varlist sim_mean sim_mean_10 sim_mean_20 sim_mean_std_hotel ars_jsd_sim recent_sd rating_recent_gap rating_momentum ln_lag_avg_com_RevPAR price_gap ln_recent_volumn ln_recent_above10 recent_growth rel_ln_recent_volumn ln_lag_volumn_acc lagvol_over58 ln_words_acc ln_recent_volumn_sq ln_lag_mr_words ln_lag_mr_avg_words ln_lag_mr_chars lag_mr_rate lag_mr_count lag_mr_quick7_share lag_mr_apology_share lag_mr_invite_share lag_mr_recovery_share lag_mr_contact_share lag_mr_personal_share lag_mr_positive_share lag_mr_negtone_share lag_mr_template_share lag_mr_thanks_share lag_mr_mgr_share hotel_class_profile_raw star_class_final_raw ln_tp_price_mid ln_tp_room ln_tp_review_count tp_quality_index tp_service_quality tp_rank_pct tp_amenity_count amen_rec_index amen_serv_index amen_bus_index sent_avg_syuzhet sent_avg_bing sent_avg_afinn sent_avg_nrc sent_med_syuzhet sent_med_bing sent_med_afinn sent_med_nrc sent_syuzhet100 sent_bing100 sent_afinn100 sent_nrc100 sent_sd_syuzhet sent_sd_bing sent_sd_afinn sent_sd_nrc sent_neg_share_bing sent_neg_share_afinn sent_pos_share_bing sent_pos_share_afinn sent_net_pos_bing sent_net_pos_afinn lag_sent_avg_syuzhet lag_sent_avg_bing lag_sent_avg_afinn lag_sent_avg_nrc lag_sent_net_pos_bing lag_sent_neg_share_bing lag_sent_afinn100 lag_mr_rep_count lag_mr_rep_low_share lag_mr_rep_neg_share {
    capture drop `v'_centered
    quietly summarize `v' if cs_sample_focus100 == 1 & !missing(`v')
    gen double `v'_centered = `v' - r(mean) if !missing(`v')
}

* Store raw-scale distribution facts used later to translate coefficients into economic effects.
tempname sumhandle
tempfile sumdata
postfile `sumhandle' str40 variable double mean sd p25 p75 using `sumdata', replace
foreach v of varlist sim_mean sim_mean_10 sim_mean_20 sim_mean_std_hotel ars_jsd_sim ln_recent_volumn ln_lag_volumn_acc ln_words_acc lagvol_over58 lag_mr_rate lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_invite_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share hotel_class_profile_raw star_class_final_raw ln_tp_price_mid ln_tp_room ln_tp_review_count tp_quality_index tp_service_quality tp_rank_pct tp_amenity_count amen_rec_index amen_serv_index amen_bus_index sent_avg_syuzhet sent_avg_bing sent_avg_afinn sent_avg_nrc sent_med_bing sent_afinn100 sent_net_pos_bing sent_sd_syuzhet sent_sd_bing sent_sd_afinn sent_sd_nrc sent_neg_share_bing sent_neg_share_afinn lag_mr_rep_neg_share lag_mr_rep_low_share {
    quietly summarize `v' if cs_sample_focus100 == 1, detail
    post `sumhandle' ("`v'") (r(mean)) (r(sd)) (r(p25)) (r(p75))
}
postclose `sumhandle'
preserve
use `sumdata', clear
export delimited using "`csv_dir'/story_variable_summary_260524.csv", replace
restore

*******************************************************
************ 2. Route A: ARS as main effect ***********
*******************************************************

estimates clear

* A1. Baseline ARS.
* Core coefficient: sim_mean. Economic meaning: a 0.01 increase in ARS changes RevPAR by exp(beta*0.01)-1.
reghdfe ln_RevPAR_clean_w199 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_sim_w199

* A2. Same ARS coefficient with 1/95 upper-tail winsorization.
reghdfe ln_RevPAR_clean_w195 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_sim_w195

* A3. Same ARS coefficient with 2.5/97.5 winsorization in the tighter focus sample.
reghdfe ln_RevPAR_clean_w025975 sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w025975 if cs_sample_focus50 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_sim_w025

* A4. Within-hotel ARS version: tests whether months with higher within-hotel similarity have weaker revenue.
reghdfe ln_RevPAR_clean_w199 sim_mean_std_hotel ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_hotelstd

* A5. Scope-10 ARS robustness.
reghdfe ln_RevPAR_clean_w199 sim_mean_10 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_scope10

* A6. Scope-20 ARS robustness.
reghdfe ln_RevPAR_clean_w199 sim_mean_20 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_scope20

* A7. JSD-based ARS robustness.
reghdfe ln_RevPAR_clean_w199 ars_jsd_sim ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_jsd

* A8. COVID boundary condition. Core interaction: ARS slope during 2020-2022 versus other months.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.covid2020_2022 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ta_covid

esttab ta_sim_w199 ta_sim_w195 ta_sim_w025 ta_hotelstd ta_scope10 ta_scope20 ta_jsd ta_covid using "`table_dir'/story_table_a_ars_main_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("w199" "w195" "w025/975" "hotel std" "scope10" "scope20" "JSD" "COVID") nogap compress
esttab ta_sim_w199 ta_sim_w195 ta_sim_w025 ta_hotelstd ta_scope10 ta_scope20 ta_jsd ta_covid using "`csv_dir'/story_table_a_ars_main_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("w199" "w195" "w025/975" "hotel std" "scope10" "scope20" "JSD" "COVID") nogap

*******************************************************
************ 2.1 Route A: boundary conditions *********
*******************************************************

estimates clear

* A9. Rating uncertainty: if recent rating dispersion is high, ARS may matter differently.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.recent_sd_centered ln_recent_volumn recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_sd

* A10. Rating gap: ARS may be less useful when recent rating deviates from accumulated reputation.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.rating_recent_gap_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_ratinggap

* A11. Rating momentum: ARS may signal stability differently when recent ratings are moving.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.rating_momentum_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_ratingmom

* A12. Market pressure: competitor RevPAR captures local demand and competition.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_lag_avg_com_RevPAR_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_compete

* A13. Product-positioning gap: price gap captures relative market position.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.price_gap_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_pricegap

* A14. Product quality group: star_class_final is filled from TripAdvisor profile when the panel star is missing.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.star_class_final ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(star_class_final), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_star

* A15. Chain product type.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.chain ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(chain), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_chain

* A16. COVID boundary repeated in the moderator table for direct comparison.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.covid2020_2022 ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store am_covid

esttab am_sd am_ratinggap am_ratingmom am_compete am_pricegap am_star am_chain am_covid using "`table_dir'/story_table_a_moderators_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("rating sd" "rating gap" "rating mom" "competition" "price gap" "star" "chain" "COVID") nogap compress
esttab am_sd am_ratinggap am_ratingmom am_compete am_pricegap am_star am_chain am_covid using "`csv_dir'/story_table_a_moderators_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("rating sd" "rating gap" "rating mom" "competition" "price gap" "star" "chain" "COVID") nogap

*******************************************************
************ 2.2 Route A: profile product features ****
*******************************************************

estimates clear

* A17. Filled star class factor. Product main effects are absorbed by hotel FE; interactions test ARS heterogeneity.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.star_class_final ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(star_class_final), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_star_final

* A18. Raw TripAdvisor hotel class. A one-unit change is roughly one star.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.hotel_class_profile_raw_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(hotel_class_profile_raw), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_hotelclass

* A19. Overall profile quality index: average TripAdvisor total and sub-rating scores.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.tp_quality_index_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(tp_quality_index), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_quality

* A20. Service-quality index: cleanliness, service, and room ratings.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.tp_service_quality_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(tp_service_quality), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_service

* A21. Price positioning. Product main effect is absorbed; the interaction asks whether ARS matters differently for higher-price hotels.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_tp_price_mid_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(ln_tp_price_mid), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_price

* A22. Hotel scale: number of rooms.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_tp_room_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(ln_tp_room), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_room

* A23. TripAdvisor rank percentile within destination/type list. Lower values mean better profile rank.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.tp_rank_pct_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(tp_rank_pct), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_rank

* A24. Amenity breadth from profile amenities text.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.tp_amenity_count_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(tp_amenity_count), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_amenity

* A25. Travelers' Choice badge. Missing badge field is coded as no badge in the profile.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.travelers_choice_flag ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(travelers_choice_flag), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ap_choice

esttab ap_star_final ap_hotelclass ap_quality ap_service ap_price ap_room ap_rank ap_amenity ap_choice using "`table_dir'/story_table_a_profile_product_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("star final" "TA class" "quality" "service" "price" "rooms" "rank pct" "amenities" "choice") nogap compress
esttab ap_star_final ap_hotelclass ap_quality ap_service ap_price ap_room ap_rank ap_amenity ap_choice using "`csv_dir'/story_table_a_profile_product_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("star final" "TA class" "quality" "service" "price" "rooms" "rank pct" "amenities" "choice") nogap

*******************************************************
************ 2.3 Route A: profile composite flags *****
*******************************************************

estimates clear

* A26. Recreation amenities combine pool, fitness, spa/hot tub/sauna, and golf.
* Product main effects are absorbed by hotel FE; the interaction asks whether ARS has a different revenue slope for recreation-heavy hotels.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.amen_rec_index_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amen_rec_index), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ac_recreation

* A27. Service amenities combine breakfast, parking, wifi, laundry, and front-desk/concierge signals.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.amen_serv_index_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amen_serv_index), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ac_serviceamen

* A28. Business amenities combine business center, meeting, conference, and workspace signals.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.amen_bus_index_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amen_bus_index), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ac_businessamen

* A29. Business/family positioning from profile style tags.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.style_business_family ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_business_family), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ac_businessfamily

* A30. Budget/value positioning from profile style tags.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.style_budget_value ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_budget_value), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ac_budgetvalue

* A31. Upscale positioning combines luxury, boutique, romantic, modern, and trendy style tags.
reghdfe ln_RevPAR_clean_w195 c.sim_mean_centered##i.style_upscale ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_upscale), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ac_upscale

* A32. Travelers' Choice badge. This is now parsed from the original string field instead of destringing it.
reghdfe ln_RevPAR_clean c.sim_mean_centered##i.travelers_choice_flag ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(travelers_choice_flag), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ac_choice

esttab ac_recreation ac_serviceamen ac_businessamen ac_businessfamily ac_budgetvalue ac_upscale ac_choice using "`table_dir'/story_table_a_profile_composite_260526.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recreation" "service" "business amenity" "business/family" "budget/value" "upscale" "choice") nogap compress
esttab ac_recreation ac_serviceamen ac_businessamen ac_businessfamily ac_budgetvalue ac_upscale ac_choice using "`csv_dir'/story_table_a_profile_composite_260526.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recreation" "service" "business amenity" "business/family" "budget/value" "upscale" "choice") nogap

*******************************************************
************ 2.3A Route A: single profile flags *******
*******************************************************

estimates clear

* A26. Pool amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.amenity_pool ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amenity_pool), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_pool

* A27. Breakfast amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.amenity_breakfast ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amenity_breakfast), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_breakfast

* A28. Fitness amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.amenity_fitness ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amenity_fitness), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_fitness

* A29. Pet-friendly amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.amenity_pet ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amenity_pet), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_pet

* A30. Business-center amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.amenity_business ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amenity_business), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_business

* A31. Meeting-room amenity boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.amenity_meeting ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(amenity_meeting), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_meeting

* A32. Business-style profile boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.style_business ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_business), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_style_business

* A33. Family-style profile boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.style_family ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_family), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_style_family

* A34. Budget-style profile boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.style_budget ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_budget), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_style_budget

* A35. Luxury/romantic/boutique-style profile boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.style_luxury ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_luxury), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_style_luxury

* A36. Modern/trendy-style profile boundary.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.style_modern ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & !missing(style_modern), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store af_style_modern

esttab af_pool af_breakfast af_fitness af_pet af_business af_meeting af_style_business af_style_family af_style_budget af_style_luxury af_style_modern using "`table_dir'/story_table_a_profile_flags_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("pool" "breakfast" "fitness" "pet" "business amenity" "meeting" "business style" "family style" "budget style" "luxury style" "modern style") nogap compress
esttab af_pool af_breakfast af_fitness af_pet af_business af_meeting af_style_business af_style_family af_style_budget af_style_luxury af_style_modern using "`csv_dir'/story_table_a_profile_flags_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("pool" "breakfast" "fitness" "pet" "business amenity" "meeting" "business style" "family style" "budget style" "luxury style" "modern style") nogap

*******************************************************
************ 2.4 Route D: review sentiment x ARS ******
*******************************************************

estimates clear

* D1. DV: ARS. Syuzhet package default lexicon average sentiment from the same review text used to construct ARS.
reghdfe sim_mean sent_avg_syuzhet_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_ars_syuzhet

* D2. DV: ARS. Bing lexicon average sentiment.
reghdfe sim_mean sent_avg_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_ars_bing

* D3. DV: ARS. AFINN lexicon average sentiment.
reghdfe sim_mean sent_avg_afinn_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_ars_afinn

* D4. DV: ARS. NRC lexicon average sentiment.
reghdfe sim_mean sent_avg_nrc_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_ars_nrc

* D5. Revenue boundary: ARS x Syuzhet sentiment. Core interaction tests whether ARS is more/less harmful when review tone is more positive.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.sent_avg_syuzhet_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_rev_syuzhet

* D6. Revenue boundary: ARS x Bing sentiment.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.sent_avg_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_rev_bing

* D7. Revenue boundary: ARS x AFINN sentiment.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.sent_avg_afinn_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_rev_afinn

* D8. Revenue boundary: ARS x NRC sentiment.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.sent_avg_nrc_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_rev_nrc

* D9. Revenue boundary: ARS x negative-review tone share under Bing.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.sent_neg_share_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_rev_negbing

* D10. Revenue boundary: ARS x lagged Syuzhet sentiment. This is less mechanical than same-month sentiment because it uses prior review tone.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_sent_avg_syuzhet_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store ds_rev_lagsyuzhet

esttab ds_ars_syuzhet ds_ars_bing ds_ars_afinn ds_ars_nrc ds_rev_syuzhet ds_rev_bing ds_rev_afinn ds_rev_nrc ds_rev_negbing ds_rev_lagsyuzhet using "`table_dir'/story_table_d_review_sentiment_260526.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("ARS syuzhet" "ARS bing" "ARS afinn" "ARS nrc" "Rev syuzhet" "Rev bing" "Rev afinn" "Rev nrc" "Rev neg bing" "Rev lag syuzhet") nogap compress
esttab ds_ars_syuzhet ds_ars_bing ds_ars_afinn ds_ars_nrc ds_rev_syuzhet ds_rev_bing ds_rev_afinn ds_rev_nrc ds_rev_negbing ds_rev_lagsyuzhet using "`csv_dir'/story_table_d_review_sentiment_260526.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("ARS syuzhet" "ARS bing" "ARS afinn" "ARS nrc" "Rev syuzhet" "Rev bing" "Rev afinn" "Rev nrc" "Rev neg bing" "Rev lag syuzhet") nogap

*******************************************************
************ 2.5 Route D: refined sentiment ***********
*******************************************************

estimates clear

* D11. Mechanism: net positive share from Bing lexicon -> ARS.
* A 0.10 increase means 10 percentage points more positive than negative review share.
reghdfe sim_mean sent_net_pos_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_ars_netbing

* D12. Mechanism: negative-review share -> ARS.
reghdfe sim_mean sent_neg_share_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_ars_negbing

* D13. Mechanism: AFINN score normalized by review words -> ARS.
reghdfe sim_mean sent_afinn100_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_ars_afinn100

* D14. Revenue direct effect: current-month net positive sentiment.
reghdfe ln_RevPAR_clean_w199 sent_net_pos_bing_centered sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_rev_netbing

* D15. Revenue moderation: ARS x net positive sentiment.
reghdfe ln_RevPAR_clean c.sim_mean_centered##c.sent_net_pos_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_rev_netbing_int

* D16. Revenue moderation: ARS x negative sentiment share.
reghdfe ln_RevPAR_clean c.sim_mean_centered##c.sent_neg_share_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_rev_negbing_int

* D17. Revenue moderation: ARS x normalized AFINN sentiment.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.sent_afinn100_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_rev_afinn100_int

* D18. Revenue moderation: high sentiment month relative to low sentiment month.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.high_sent_bing ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1 & sent_any_text == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_rev_high_int

* D19. Revenue moderation: prior-month net positive sentiment.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_sent_net_pos_bing_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store dr_rev_lagnet_int

esttab dr_ars_netbing dr_ars_negbing dr_ars_afinn100 dr_rev_netbing dr_rev_netbing_int dr_rev_negbing_int dr_rev_afinn100_int dr_rev_high_int dr_rev_lagnet_int using "`table_dir'/story_table_d_review_sentiment_refined_260526.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("ARS net bing" "ARS neg bing" "ARS afinn/100w" "Rev net bing" "Rev net x ARS" "Rev neg x ARS" "Rev afinn/100w x ARS" "Rev high x ARS" "Rev lag net x ARS") nogap compress
esttab dr_ars_netbing dr_ars_negbing dr_ars_afinn100 dr_rev_netbing dr_rev_netbing_int dr_rev_negbing_int dr_rev_afinn100_int dr_rev_high_int dr_rev_lagnet_int using "`csv_dir'/story_table_d_review_sentiment_refined_260526.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("ARS net bing" "ARS neg bing" "ARS afinn/100w" "Rev net bing" "Rev net x ARS" "Rev neg x ARS" "Rev afinn/100w x ARS" "Rev high x ARS" "Rev lag net x ARS") nogap

*******************************************************
************ 3. Route B: volume x ARS *****************
*******************************************************

estimates clear

* B1. Recent review flow. Core interaction: recent monthly volume x ARS.
* A doubling of recent volume is ln(2); ARS is interpreted in 0.01 raw-unit increments.
reghdfe ln_RevPAR_clean c.ln_recent_volumn_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_recent

* B2. Recent review pressure above 10 reviews in the month.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_above10_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_recent10

* B3. Review growth from last month.
reghdfe ln_RevPAR_clean_w195 c.recent_growth_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_growth

* B4. Recent review flow relative to city-month competitors.
reghdfe ln_RevPAR_clean_w199 c.rel_ln_recent_volumn_centered##c.sim_mean_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_relrecent

* B5. Accumulated review stock. Treat this as an alternative volume-stock measure rather than controlling for another volume stock.
reghdfe ln_RevPAR_clean_w199 c.ln_lag_volumn_acc##c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum

* B6. Accumulated review stock with within-hotel ARS. This checks whether the volume story survives an alternative ARS measure.
reghdfe ln_RevPAR_clean_w199 c.ln_lag_volumn_acc_centered##c.sim_mean_std_hotel_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum_hstd

* B7. Accumulated review stock above log threshold 5.8.
reghdfe ln_RevPAR_clean_w199 c.lagvol_over58_centered##c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum58

* B8. Accumulated review stock above log threshold 5.8 with scope-10 ARS.
reghdfe ln_RevPAR_clean_w199 c.lagvol_over58_centered##c.sim_mean_10_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_cum58_s10

* B9. Accumulated review text stock. This captures solicitation/content intensity beyond count.
reghdfe ln_RevPAR_clean_w199 c.ln_words_acc_centered##c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_words

* B10. Text stock with within-hotel ARS.
reghdfe ln_RevPAR_clean_w199 c.ln_words_acc_centered##c.sim_mean_std_hotel_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_words_hstd

* B11. Nonlinear recent volume. Core terms are the linear and squared volume interactions with ARS.
reghdfe ln_RevPAR_clean_w199 ln_recent_volumn_centered ln_recent_volumn_sq_centered sim_mean_centered c.ln_recent_volumn_centered#c.sim_mean_centered c.ln_recent_volumn_sq_centered#c.sim_mean_centered recent_sd recent_rating lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tb_recent_sq

esttab tb_recent tb_recent10 tb_growth tb_relrecent tb_cum tb_cum_hstd tb_cum58 tb_cum58_s10 tb_words tb_words_hstd tb_recent_sq using "`table_dir'/story_table_b_volume_ars_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recent" "recent>10" "growth" "rel recent" "cumulative" "cum hstd" "cum>5.8" "cum>5.8 s10" "text volume" "text hstd" "recent sq") nogap compress
esttab tb_recent tb_recent10 tb_growth tb_relrecent tb_cum tb_cum_hstd tb_cum58 tb_cum58_s10 tb_words tb_words_hstd tb_recent_sq using "`csv_dir'/story_table_b_volume_ars_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("recent" "recent>10" "growth" "rel recent" "cumulative" "cum hstd" "cum>5.8" "cum>5.8 s10" "text volume" "text hstd" "recent sq") nogap

*******************************************************
************ 4. Route C: reply -> revenue *************
*******************************************************

estimates clear

* C1. Any reply. Direct coefficient is the revenue gap between hotels with and without lagged reply activity at average ARS.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##i.lag_mr_any ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_any

* C2. Reply rate. A 0.10 increase is a 10 percentage-point higher lagged reply rate.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_rate_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_rate

* C3. Reply count.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_count_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_count

* C4. Total reply text length.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_lag_mr_words_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_words

* C5. Average reply length.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.ln_lag_mr_avg_words_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_avgwords

* C6. Fast replies within seven days.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_quick7_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_quick

* C7. Invite wording as engagement/solicitation language.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_invite_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_invite

* C8. Service-recovery wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_recovery_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_recovery

* C9. Positive reply wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_positive_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store cr_positive

esttab cr_any cr_rate cr_count cr_words cr_avgwords cr_quick cr_invite cr_recovery cr_positive using "`table_dir'/story_table_c_reply_revenue_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("any reply" "reply rate" "reply count" "words" "avg words" "quick7" "invite" "recovery" "positive") nogap compress
esttab cr_any cr_rate cr_count cr_words cr_avgwords cr_quick cr_invite cr_recovery cr_positive using "`csv_dir'/story_table_c_reply_revenue_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("any reply" "reply rate" "reply count" "words" "avg words" "quick7" "invite" "recovery" "positive") nogap

*******************************************************
************ 4.1 Route C: text interactions ***********
*******************************************************

estimates clear

* C10. Thanks wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_thanks_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_thanks

* C11. Apology wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_apology_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_apology

* C12. Contact wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_contact_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_contact

* C13. Personalization.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_personal_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_personal

* C14. Negative-problem wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean##c.lag_mr_negtone_share recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_negtone

* C15. Template-like wording.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_template_share_centered recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_template

* C16. Three-way test: volume x ARS x average reply length.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean##c.ln_lag_mr_avg_words_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_avgw

* C17. Three-way test: volume x ARS x quick reply.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean_centered##c.lag_mr_quick7_share_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_quick

* C18. Three-way test: volume x ARS x positive reply wording.
reghdfe ln_RevPAR_clean_w199 c.ln_recent_volumn_centered##c.sim_mean_centered##c.lag_mr_positive_share_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_pos

* C19. Three-way test: volume x ARS x recovery wording.
reghdfe ln_RevPAR_clean c.ln_recent_volumn_centered##c.sim_mean_centered##c.lag_mr_recovery_share_centered recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tc_triple_rec

esttab tc_thanks tc_apology tc_contact tc_personal tc_negtone tc_template tc_triple_avgw tc_triple_quick tc_triple_pos tc_triple_rec using "`table_dir'/story_table_c_mr_text_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("thanks" "apology" "contact" "personal" "neg tone" "template" "triple avg words" "triple quick7" "triple positive" "triple recovery") nogap compress
esttab tc_thanks tc_apology tc_contact tc_personal tc_negtone tc_template tc_triple_avgw tc_triple_quick tc_triple_pos tc_triple_rec using "`csv_dir'/story_table_c_mr_text_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("thanks" "apology" "contact" "personal" "neg tone" "template" "triple avg words" "triple quick7" "triple positive" "triple recovery") nogap

*******************************************************
************ 4.2 Route C: replied reviews *************
*******************************************************

estimates clear

* C20. Targeted response object: share of replied reviews with negative Bing sentiment.
* This captures what type of reviews management engaged with, not only what management wrote.
reghdfe ln_RevPAR_clean_w199 lag_mr_rep_neg_share sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store c2_neg_direct

* C21. Targeted response object: share of replied reviews with rating <= 2.
reghdfe ln_RevPAR_clean_w199 lag_mr_rep_low_share sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store c2_low_direct

* C22. Revenue moderation: ARS x replied negative-sentiment share.
reghdfe ln_RevPAR_clean_w199 c.sim_mean_centered##c.lag_mr_rep_neg_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store c2_neg_ars

* C23. Revenue moderation: ARS x replied low-rating share.
reghdfe ln_RevPAR_clean c.sim_mean_centered##c.lag_mr_rep_low_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store c2_low_ars

* C24. Three-way test: reply count x ARS x share of replied reviews that are negative.
reghdfe ln_RevPAR_clean_w195 c.lag_mr_count_centered##c.sim_mean_centered##c.lag_mr_rep_neg_share_centered ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w195 lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store c2_triple_neg

* C25. Mechanism DV: later review volume.
reghdfe ln_recent_volumn lag_mr_rep_neg_share lag_mr_rep_low_share lag_mr_rep_service_share lag_mr_rep_room_share lag_mr_count recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store c2_mech_volume

* C26. Mechanism DV: later ARS.
reghdfe sim_mean lag_mr_rep_neg_share lag_mr_rep_low_share lag_mr_rep_service_share lag_mr_rep_room_share lag_mr_count ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store c2_mech_ars

esttab c2_neg_direct c2_low_direct c2_neg_ars c2_low_ars c2_triple_neg c2_mech_volume c2_mech_ars using "`table_dir'/story_table_c2_replied_review_260526.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("Rev neg replied" "Rev low replied" "Rev neg x ARS" "Rev low x ARS" "Rev triple neg" "DV volume" "DV ARS") nogap compress
esttab c2_neg_direct c2_low_direct c2_neg_ars c2_low_ars c2_triple_neg c2_mech_volume c2_mech_ars using "`csv_dir'/story_table_c2_replied_review_260526.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("Rev neg replied" "Rev low replied" "Rev neg x ARS" "Rev low x ARS" "Rev triple neg" "DV volume" "DV ARS") nogap

*******************************************************
************ 5. Route C: mechanisms *******************
*******************************************************

estimates clear

* C20. Mechanism DV: next-month review volume. MR text is treated as observable engagement, not causal solicitation.
reghdfe ln_recent_volumn lag_mr_rate ln_lag_mr_words lag_mr_count lag_mr_quick7_share lag_mr_invite_share lag_mr_apology_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_volume

* C21. Mechanism DV: ARS. This asks whether reply engagement predicts later review similarity.
reghdfe sim_mean lag_mr_rate ln_lag_mr_words lag_mr_count lag_mr_quick7_share lag_mr_invite_share lag_mr_apology_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share recent_sd recent_rating ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_ars

* C22. Mechanism DV: RevPAR with MR text variables entered directly.
reghdfe ln_RevPAR_clean_w199 lag_mr_rate ln_lag_mr_words lag_mr_count lag_mr_quick7_share lag_mr_invite_share lag_mr_apology_share lag_mr_recovery_share lag_mr_positive_share lag_mr_template_share ln_recent_volumn sim_mean recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
est store tm_revpar

esttab tm_volume tm_ars tm_revpar using "`table_dir'/story_table_c_mr_mechanisms_260524.rtf", replace star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("DV: volume" "DV: ARS" "DV: RevPAR") nogap compress
esttab tm_volume tm_ars tm_revpar using "`csv_dir'/story_table_c_mr_mechanisms_260524.csv", replace csv star(* 0.10 ** 0.05 *** 0.01 **** 0.001) cells(b(star fmt(4)) se(par fmt(4))) stats(N r2_a, labels("Observations" "Adjusted R-squared")) mtitles("DV: volume" "DV: ARS" "DV: RevPAR") nogap

log close
