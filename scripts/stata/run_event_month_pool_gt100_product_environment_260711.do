version 17.0
clear all
set more off
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
log using "`p'/stata-log/run_event_month_pool_gt100_product_environment_260711.log", text replace
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
do "`p'/scripts/stata/prepare_event_month_pool_gt100_260711.do"
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
    gen double tp_price_mid = (hotel_price_low + hotel_price_high)/2 if !missing(hotel_price_low,hotel_price_high)
    gen double ln_tp_price_mid = ln(tp_price_mid) if tp_price_mid>0
    gen strL amen_lc = ustrlower(hotel_amenities)
    gen strL style_lc = ustrlower(hotel_style)
    gen double tp_amenity_count = strlen(hotel_amenities)-strlen(subinstr(hotel_amenities,",","",.))+1 if strtrim(hotel_amenities)!="" & !missing(hotel_amenities)
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
local C ev_ln_review_count ev_mean_rating ev_sd_rating ev_ln_mean_text_chars ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR lnRevenue_lag_month_w199
estimates clear
* V1-V3 vertical product systematics.
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.star_class_final_raw `C' if !missing(ars_pool_ev,star_class_final_raw), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V1_star
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.hotel_avg_rating `C' if !missing(ars_pool_ev,hotel_avg_rating), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V2_quality
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.hotel_rank_pct `C' if !missing(ars_pool_ev,hotel_rank_pct), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store V3_rank
* H1-H7 horizontal product systematics.
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.tp_amenity_count `C' if !missing(ars_pool_ev,tp_amenity_count), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store H1_amenity
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.amen_rec_index `C' if !missing(ars_pool_ev,amen_rec_index), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store H2_recreation
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.amen_serv_index `C' if !missing(ars_pool_ev,amen_serv_index), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store H3_service
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.amen_bus_index `C' if !missing(ars_pool_ev,amen_bus_index), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store H4_business
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.style_upscale `C' if !missing(ars_pool_ev,style_upscale), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store H5_upscale
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.style_luxury `C' if !missing(ars_pool_ev,style_luxury), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store H6_luxury
reghdfe lnRevenue_current_w199 c.ars_pool_ev##i.travelers_choice_flag `C' if !missing(ars_pool_ev,travelers_choice_flag), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store H7_choice
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.ln_tp_price_mid `C' if !missing(ars_pool_ev,ln_tp_price_mid), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store P1_price
* E1-E6 review-environment systematics.
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.recent_sd_10 `C' if !missing(ars_pool_ev,recent_sd_10), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E1_scope10sd
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.prevvis_recent_sd `C' if !missing(ars_pool_ev,prevvis_recent_sd), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E2_prevvis_sd
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.sent_avg_bing_10 `C' if !missing(ars_pool_ev,sent_avg_bing_10), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E3_scope10bing
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.sent_net_pos_bing_10 `C' if !missing(ars_pool_ev,sent_net_pos_bing_10), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E4_scope10net
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.prevvis_sent_avg_bing `C' if !missing(ars_pool_ev,prevvis_sent_avg_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E5_prevvisbing
reghdfe lnRevenue_current_w199 c.ars_pool_ev##c.prevvis_sent_net_pos_bing `C' if !missing(ars_pool_ev,prevvis_sent_net_pos_bing), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store E6_prevvisnet
estimates table V1_star V2_quality V3_rank H1_amenity H2_recreation H3_service H4_business H5_upscale H6_luxury H7_choice P1_price E1_scope10sd E2_prevvis_sd E3_scope10bing E4_scope10net E5_prevvisbing E6_prevvisnet, b(%9.4f) se stats(N r2_a)
log close
