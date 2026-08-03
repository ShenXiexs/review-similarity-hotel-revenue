*******************************************************
* Event-month ARS full replication, 260710.
* Writes a text log only: no CSV, XLSX, or RTF artifacts.
* The foreach expansion is a prespecified cross/pool measurement
* replication, not a model-search or candidate-model loop.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_ars_mr_panel_260710.dta", clear
log using "`p'/stata-log/run_event_month_full_replication_260710.log", text replace
capture which reghdfe
if _rc exit 199
keep if cs_sample_focus100 == 1
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
gen ym = monthly(event_ym, "YM")
format ym %tm
xtset hotel_id_num ym

* Idempotent event-month winsors; raw variables remain unchanged.
capture drop lnRevenue_current_w199 lnRevenue_current_w595 lnRevenue_lag_month_w199 lnRevenue_lag_month_w595 lnRevenue_next_calendar_w199 lnRevenue_next_calendar_w595
foreach x in lnRevenue_current lnRevenue_lag_month lnRevenue_next_calendar {
    quietly _pctile `x' if !missing(`x'), p(1 99)
    gen double `x'_w199 = min(max(`x', r(r1)), r(r2)) if !missing(`x')
    quietly _pctile `x' if !missing(`x'), p(5 95)
    gen double `x'_w595 = min(max(`x', r(r1)), r(r2)) if !missing(`x')
}
capture drop zip_n_full_c city_n_full_c gap_zip_mean_full_c gap_city_mean_full_c price_gap_c high_star4 high_rank_status high_popularity hotel_evaluation_factor ln_pmr_words ln_pmr_avg_words
foreach x in zip_n_full city_n_full gap_zip_mean_full gap_city_mean_full price_gap {
    quietly summarize `x' if !missing(`x'), meanonly
    gen double `x'_c = `x' - r(mean) if !missing(`x')
}
gen byte high_star4 = star_class_final >= 4 if !missing(star_class_final)
quietly summarize hotel_rank_pct if !missing(hotel_rank_pct), detail
gen byte high_rank_status = hotel_rank_pct <= r(p50) if !missing(hotel_rank_pct)
bysort Zip ym: egen double _popmed = median(ln_lag_volumn_acc)
gen byte high_popularity = ln_lag_volumn_acc > _popmed if !missing(ln_lag_volumn_acc, _popmed)
drop _popmed
capture confirm string variable hotel_evaluation_raw
if !_rc encode hotel_evaluation_raw, gen(hotel_evaluation_factor)
else gen long hotel_evaluation_factor = hotel_evaluation_raw
gen double ln_pmr_words = ln(pmr_activity_words + 1)
gen double ln_pmr_avg_words = ln(pmr_activity_avg_words + 1) if !missing(pmr_activity_avg_words)

* Product-systematic measures are deterministically rebuilt from the profile source.
tempfile profile
preserve
    import delimited using "`p'/full-data/hotel_profile_TP.csv", varnames(1) clear bindquote(loose) maxquotedrows(unlimited) encoding("UTF-8")
    keep hotel_id_ta hotel_price_low hotel_price_high hotel_amenities hotel_style travelers_choice
    rename hotel_id_ta HotelID
    capture confirm string variable HotelID
    if _rc tostring HotelID, replace format(%18.0f)
    replace HotelID = strtrim(HotelID)
    duplicates drop HotelID, force
    destring hotel_price_low hotel_price_high, replace ignore(",") force
    gen double tp_price_mid = (hotel_price_low + hotel_price_high) / 2 if !missing(hotel_price_low, hotel_price_high)
    gen double ln_tp_price_mid = ln(tp_price_mid) if tp_price_mid > 0
    gen strL amen_lc = ustrlower(hotel_amenities)
    gen strL style_lc = ustrlower(hotel_style)
    gen double tp_amenity_count = strlen(hotel_amenities)-strlen(subinstr(hotel_amenities, ",", "", .))+1 if strtrim(hotel_amenities)!="" & !missing(hotel_amenities)
    replace tp_amenity_count = 0 if missing(tp_amenity_count) & !missing(hotel_amenities)
    gen byte amen_rec_index = regexm(amen_lc,"pool") + regexm(amen_lc,"fitness|gym|workout") + regexm(amen_lc,"spa|hot tub|jacuzzi|sauna") + regexm(amen_lc,"golf") if !missing(amen_lc)
    gen byte amen_serv_index = regexm(amen_lc,"breakfast") + regexm(amen_lc,"parking|park") + regexm(amen_lc,"wifi|wi-fi|internet") + regexm(amen_lc,"laundry|dry cleaning") + regexm(amen_lc,"24-hour|front desk|concierge") if !missing(amen_lc)
    gen byte amen_bus_index = regexm(amen_lc,"business center|business") + regexm(amen_lc,"meeting") + regexm(amen_lc,"conference|banquet") + regexm(amen_lc,"workspace|desk|work area") if !missing(amen_lc)
    gen byte style_upscale = regexm(style_lc,"luxury|romantic|boutique|modern|trendy") if !missing(style_lc)
    gen byte travelers_choice_flag = regexm(ustrlower(travelers_choice),"travelers' choice|best of the best") if !missing(travelers_choice)
    foreach x in amen_rec_index amen_serv_index amen_bus_index style_upscale travelers_choice_flag {
        replace `x' = 0 if missing(`x')
    }
    keep HotelID ln_tp_price_mid tp_amenity_count amen_rec_index amen_serv_index amen_bus_index style_upscale travelers_choice_flag
    save `profile', replace
restore
merge m:1 HotelID using `profile', keep(master match) nogen

* All formal specifications below have hotel and event-calendar-month FE, hotel clustering, current event controls, and prior accumulated controls.
* M0.1--M9: market boundaries.
foreach a in ars_cross_ev ars_pool_ev {
    reghdfe lnRevenue_current_w199 `a' ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store M01_`a'
    foreach m in c.ln_avg_com_RevPAR i.high_comp_zip_focus100 i.high_comp_city_focus100 c.zip_n_full_c c.city_n_full_c c.ln_comp_zip_mean_excl_full c.ln_comp_city_mean_excl_full c.gap_zip_mean_full_c c.gap_city_mean_full_c c.price_gap_c {
        reghdfe lnRevenue_current_w199 c.`a'##`m' ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    }
    * M1--M13: organization boundaries.
    foreach m in i.chain i.independent i.chain_small i.chain3_small i.star_class_final i.high_star4 c.lag_avg_rating_acc i.high_quality_ym i.high_quality_cityym i.high_quality_zipym i.high_rank_status i.hotel_evaluation_factor c.ln_lag_volumn_acc {
        reghdfe lnRevenue_current_w199 c.`a'##`m' ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    }
    * V1--V3, H1--H7, P1: product systematics.
    foreach m in c.star_class_final_raw c.hotel_avg_rating c.hotel_rank_pct c.tp_amenity_count c.amen_rec_index c.amen_serv_index c.amen_bus_index i.style_upscale i.style_luxury i.travelers_choice_flag c.ln_tp_price_mid {
        reghdfe lnRevenue_current_w199 c.`a'##`m' ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    }
    * E1--E6: event-aligned current and previous-event review environment.
    foreach m in c.recent_sd_10 c.prevvis_recent_sd c.sent_avg_bing_10 c.sent_net_pos_bing_10 c.prevvis_sent_avg_bing c.prevvis_sent_net_pos_bing {
        reghdfe lnRevenue_current_w199 c.`a'##`m' ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    }
    * G1--G16: prior-event management-response engagement style.
    foreach m in i.pmr_any c.pmr_cohort_rate7 c.pmr_activity_n c.ln_pmr_words c.ln_pmr_avg_words c.pmr_activity_avg_days c.pmr_cohort_rate30 c.pmr_text_thanks_zf c.pmr_text_apology_zf c.pmr_text_invite_zf c.pmr_text_recovery_zf c.pmr_text_positive_zf c.pmr_text_problem_zf c.pmr_text_personalization_zf c.pmr_text_manager_zf c.pmr_text_template_zf {
        reghdfe lnRevenue_current_w199 c.`a'##`m' pmr_any ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    }
    * L1--L2: corrected next-event learning levels, not mechanically coupled deltas.
    reghdfe next_event_`a' `a' ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if !missing(next_event_`a',`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    reghdfe next_event_mean_text_chars `a' ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if !missing(next_event_mean_text_chars,`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    * T1--T6: complaint / service / room / cleanliness / value / low-rating response targeting.
    foreach m in c.pmr_target_complaint_zf c.pmr_target_service_zf c.pmr_target_room_zf c.pmr_target_cleanliness_zf c.pmr_target_value_zf c.pmr_target_low_zf {
        reghdfe lnRevenue_current_w199 c.`a'##`m' pmr_any pmr_activity_n pmr_cohort_rate7 ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars sent_avg_bing sent_pos_share_bing sent_neg_share_bing ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199 if !missing(`a'), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    }
}
estimates table M01_ars_cross_ev M01_ars_pool_ev, b(%9.4f) se stats(N r2_a)
log close
