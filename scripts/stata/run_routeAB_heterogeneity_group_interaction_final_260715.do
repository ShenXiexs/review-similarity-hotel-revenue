************************************************************
* Route A/B heterogeneity: interaction, high group, low group,
* and bdiff group-difference test for every moderator.
* Final deliverables only: one DTA and one RTF.
************************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close _all
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_main "`project'/outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local profile_csv "`project'/full-data/hotel_profile_TP.csv"
local data_final "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local rtf_final "`project'/outputs/paper/routeAB_heterogeneity_group_interaction_final_260715.rtf"

foreach f in "`data_main'" "`profile_csv'" {
    capture confirm file "`f'"
    if _rc exit 601
}
foreach cmd in reghdfe winsor2 esttab bdiff {
    capture which `cmd'
    if _rc exit 199
}

************************************************************
* 1. Load the Route-A/Route-B panel and the raw profile fields.
************************************************************

tempfile hotel_profile
preserve
    import delimited using "`profile_csv'", varnames(1) ///
        bindquote(loose) maxquotedrows(unlimited) encoding("UTF-8") clear
    keep hotel_id_ta hotel_amenities hotel_style travelers_choice
    rename hotel_id_ta HotelID
    capture confirm string variable HotelID
    if _rc tostring HotelID, replace format(%18.0f)
    replace HotelID = strtrim(HotelID)
    duplicates drop HotelID, force
    save `hotel_profile', replace
restore

use "`data_main'", clear
keep if cs_sample_focus100 == 1
merge m:1 HotelID using `hotel_profile', keep(master match) nogen

capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
sort hotel_id_num ym

winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)

egen byte het_missing = rowmiss(ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199)
gen byte het_base_cc = (het_missing == 0)
label variable het_base_cc "Common complete-case sample"

label variable sim_mean "ARS"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable recent_rating_10 "Recent rating"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating"
label variable lag_sd_acc "Accumulated rating SD"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"
label variable ln_lag_RevPAR_clean_w199 "ln(RevPAR), lagged"
label define het_lowhigh 0 "Low" 1 "High", replace

estimates clear

************************************************************
* 2. Accumulated rating: construct group, interaction, high,
*    low, then bdiff.
************************************************************

bysort ym: egen double het_med_acc_rating = median(lag_avg_rating_acc) if het_base_cc
gen byte het_high_acc_rating = (lag_avg_rating_acc >= het_med_acc_rating) if het_base_cc
label values het_high_acc_rating het_lowhigh
label variable het_high_acc_rating "High accumulated rating"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_high_acc_rating ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_high_acc_rating#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_acc_rating

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_acc_rating == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_acc_rating_high

reghdfe ln_RevPAR_clean_w595 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_acc_rating == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_acc_rating_low

quietly bdiff, group(het_high_acc_rating) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260715) nodots first
local p_acc_rating = r(p)
estimates restore grp_acc_rating_high
estadd scalar Fisher_p = `p_acc_rating'
estimates drop grp_acc_rating_high
estimates store grp_acc_rating_high

************************************************************
* 3. Accumulated volume: construct group, interaction, high,
*    low, then bdiff.
************************************************************

bysort ym: egen double het_med_acc_volume = median(ln_lag_volumn_acc) if het_base_cc
gen byte het_high_acc_volume = (ln_lag_volumn_acc >= het_med_acc_volume) if het_base_cc
label values het_high_acc_volume het_lowhigh
label variable het_high_acc_volume "High accumulated volume"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_high_acc_volume ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_high_acc_volume#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_acc_volume

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_acc_volume == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_acc_volume_high

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_acc_volume == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_acc_volume_low

quietly bdiff, group(het_high_acc_volume) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260716) nodots first
local p_acc_volume = r(p)
estimates restore grp_acc_volume_high
estadd scalar Fisher_p = `p_acc_volume'
estimates drop grp_acc_volume_high
estimates store grp_acc_volume_high

************************************************************
* 4. Accumulated rating SD: construct group, interaction,
*    high, low, then bdiff.
************************************************************

bysort ym: egen double het_med_acc_sd = median(lag_sd_acc) if het_base_cc
gen byte het_high_acc_sd = (lag_sd_acc >= het_med_acc_sd) if het_base_cc
label values het_high_acc_sd het_lowhigh
label variable het_high_acc_sd "High accumulated rating SD"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_high_acc_sd ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_high_acc_sd#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_acc_sd

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_acc_sd == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_acc_sd_high

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_acc_sd == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_acc_sd_low

quietly bdiff, group(het_high_acc_sd) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260717) nodots first
local p_acc_sd = r(p)
estimates restore grp_acc_sd_high
estadd scalar Fisher_p = `p_acc_sd'
estimates drop grp_acc_sd_high
estimates store grp_acc_sd_high

************************************************************
* 5. Amenity breadth: construct static profile measure/group,
*    interaction, high, low, then bdiff.
************************************************************

gen strL het_amenities_text = ustrlower(hotel_amenities)
gen double het_amenity_count = .
replace het_amenity_count = 0 ///
    if inlist(strtrim(het_amenities_text), "b'[]'", "[]", "none", "b'none'")
replace het_amenity_count = ///
    strlen(hotel_amenities) - strlen(subinstr(hotel_amenities, ",", "", .)) + 1 ///
    if !missing(hotel_amenities) & strtrim(hotel_amenities) != "" ///
    & missing(het_amenity_count)
bysort hotel_id_num: egen byte het_hotel_cc = max(het_base_cc)
egen byte het_hotel_tag = tag(hotel_id_num)
quietly summarize het_amenity_count ///
    if het_hotel_tag == 1 & het_hotel_cc == 1 & !missing(het_amenity_count), detail
local amenity_median = r(p50)
gen byte het_high_amenity = (het_amenity_count >= `amenity_median') ///
    if !missing(het_amenity_count) & het_hotel_cc == 1
label values het_high_amenity het_lowhigh
label variable het_amenity_count "Amenity breadth"
label variable het_high_amenity "High amenity breadth"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_high_amenity ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & !missing(het_high_amenity), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_high_amenity#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_amenity

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_amenity == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_amenity_high

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_amenity == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_amenity_low

quietly bdiff, group(het_high_amenity) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260718) nodots first
local p_amenity = r(p)
estimates restore grp_amenity_high
estadd scalar Fisher_p = `p_amenity'
estimates drop grp_amenity_high
estimates store grp_amenity_high

************************************************************
* 6. Differentiation-oriented style: construct profile group,
*    interaction, high, low, then bdiff.
************************************************************

gen strL het_style_text = ustrlower(hotel_style)
gen byte het_style_upscale = regexm(het_style_text, ///
    "luxury|romantic|boutique|modern|trendy") if !missing(het_style_text)
replace het_style_upscale = 0 if missing(het_style_upscale)
label define het_style_lbl 0 "Other style" 1 "Differentiation-oriented style", replace
label values het_style_upscale het_style_lbl
label variable het_style_upscale "Differentiation-oriented style"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_style_upscale ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_style_upscale#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_style

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_style_upscale == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_style_high

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_style_upscale == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_style_low

quietly bdiff, group(het_style_upscale) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260719) nodots first
local p_style = r(p)
estimates restore grp_style_high
estadd scalar Fisher_p = `p_style'
estimates drop grp_style_high
estimates store grp_style_high

************************************************************
* 7. Travelers' Choice: construct badge group, interaction,
*    high, low, then bdiff.
************************************************************

gen strL het_badge_text = ustrlower(travelers_choice)
gen byte het_travelers_choice = regexm(het_badge_text, ///
    "travelers' choice|best of the best") if !missing(het_badge_text)
replace het_travelers_choice = 0 if missing(het_travelers_choice)
label define het_badge_lbl 0 "No Travelers' Choice" 1 "Travelers' Choice", replace
label values het_travelers_choice het_badge_lbl
label variable het_travelers_choice "Travelers' Choice badge"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_travelers_choice ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_travelers_choice#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_badge

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_travelers_choice == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_badge_high

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_travelers_choice == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_badge_low

quietly bdiff, group(het_travelers_choice) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260720) nodots first
local p_badge = r(p)
estimates restore grp_badge_high
estadd scalar Fisher_p = `p_badge'
estimates drop grp_badge_high
estimates store grp_badge_high

************************************************************
* 8. Same-ZIP market thickness: construct group, interaction,
*    high, low, then bdiff.
************************************************************

bysort ym: egen double het_med_market_thickness = median(zip_n_full) ///
    if het_base_cc & !missing(zip_n_full)
gen byte het_high_market_thickness = (zip_n_full > het_med_market_thickness) ///
    if het_base_cc & !missing(zip_n_full)
label values het_high_market_thickness het_lowhigh
label variable het_high_market_thickness "High same-ZIP market thickness"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_high_market_thickness ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & !missing(het_high_market_thickness), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_high_market_thickness#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_market_thickness

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_market_thickness == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_market_thickness_high

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_market_thickness == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_market_thickness_low

quietly bdiff, group(het_high_market_thickness) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260721) nodots first
local p_market_thickness = r(p)
estimates restore grp_market_thickness_high
estadd scalar Fisher_p = `p_market_thickness'
estimates drop grp_market_thickness_high
estimates store grp_market_thickness_high

************************************************************
* 9. Same-ZIP competitor RevPAR: construct group, interaction,
*    high, low, then bdiff.
************************************************************

bysort ym: egen double het_med_local_pressure = ///
    median(ln_comp_zip_mean_excl_full) ///
    if het_base_cc & !missing(ln_comp_zip_mean_excl_full)
gen byte het_high_local_pressure = ///
    (ln_comp_zip_mean_excl_full >= het_med_local_pressure) ///
    if het_base_cc & !missing(ln_comp_zip_mean_excl_full)
label values het_high_local_pressure het_lowhigh
label variable het_high_local_pressure "High same-ZIP competitor RevPAR"

reghdfe ln_RevPAR_clean_w199 c.sim_mean##i.het_high_local_pressure ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & !missing(het_high_local_pressure), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
test 1.het_high_local_pressure#c.sim_mean
estadd scalar Interaction_p = r(p)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store int_local_pressure

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_local_pressure == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_local_pressure_high

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
    lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 ///
    if het_base_cc == 1 & het_high_local_pressure == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store grp_local_pressure_low

quietly bdiff, group(het_high_local_pressure) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean recent_sd_10 ///
        ln_recent_volumn_10 recent_rating_10 ln_lag_volumn_acc ///
        lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        ln_lag_RevPAR_clean_w199, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(500) seed(260722) nodots first
local p_local_pressure = r(p)
estimates restore grp_local_pressure_high
estadd scalar Fisher_p = `p_local_pressure'
estimates drop grp_local_pressure_high
estimates store grp_local_pressure_high

************************************************************
* 10. Save final analysis DTA and write the six RTF panels.
************************************************************

compress
save "`data_final'", replace

esttab int_acc_rating int_acc_volume int_acc_sd using "`rtf_final'", replace rtf ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(HotelFE TimeFE N r2_a Interaction_p, ///
        labels("Hotel fixed effects" "Time fixed effects" "Observations" "Adjusted R-squared" "Interaction p-value") ///
        fmt(%18s %18s %12.0fc %9.3f %9.3f)) ///
    mtitles("Accumulated rating" "Accumulated volume" "Accumulated SD") ///
    label nogap compress title("Panel A1. Review-history: high/low interaction regressions")

esttab grp_acc_rating_high grp_acc_rating_low grp_acc_volume_high grp_acc_volume_low ///
    grp_acc_sd_high grp_acc_sd_low using "`rtf_final'", append rtf ///
    order(sim_mean recent_sd_10 ln_recent_volumn_10 recent_rating_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(HotelFE TimeFE N r2_a Fisher_p, ///
        labels("Hotel fixed effects" "Time fixed effects" "Observations" "Adjusted R-squared" "bdiff Fisher p-value") ///
        fmt(%18s %18s %12.0fc %9.3f %9.3f)) ///
    mtitles("Rating high" "Rating low" "Volume high" "Volume low" "SD high" "SD low") ///
    label nogap compress title("Panel A2. Review-history: grouped regressions and bdiff")

esttab int_amenity int_style int_badge using "`rtf_final'", append rtf ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(HotelFE TimeFE N r2_a Interaction_p, ///
        labels("Hotel fixed effects" "Time fixed effects" "Observations" "Adjusted R-squared" "Interaction p-value") ///
        fmt(%18s %18s %12.0fc %9.3f %9.3f)) ///
    mtitles("Amenity breadth" "Differentiation-oriented style" "Travelers' Choice") ///
    label nogap compress title("Panel B1. Hotel profile: high/low interaction regressions")

esttab grp_amenity_high grp_amenity_low grp_style_high grp_style_low ///
    grp_badge_high grp_badge_low using "`rtf_final'", append rtf ///
    order(sim_mean recent_sd_10 ln_recent_volumn_10 recent_rating_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(HotelFE TimeFE N r2_a Fisher_p, ///
        labels("Hotel fixed effects" "Time fixed effects" "Observations" "Adjusted R-squared" "bdiff Fisher p-value") ///
        fmt(%18s %18s %12.0fc %9.3f %9.3f)) ///
    mtitles("Amenities high" "Amenities low" "Style high" "Style low" "Badge" "No badge") ///
    label nogap compress title("Panel B2. Hotel profile: grouped regressions and bdiff")

esttab int_market_thickness int_local_pressure using "`rtf_final'", append rtf ///
    cells(b(star fmt(3)) se(par fmt(3))) star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(HotelFE TimeFE N r2_a Interaction_p, ///
        labels("Hotel fixed effects" "Time fixed effects" "Observations" "Adjusted R-squared" "Interaction p-value") ///
        fmt(%18s %18s %12.0fc %9.3f %9.3f)) ///
    mtitles("Same-ZIP hotel count" "Same-ZIP competitor RevPAR") ///
    label nogap compress title("Panel C1. Market: high/low interaction regressions")

esttab grp_market_thickness_high grp_market_thickness_low ///
    grp_local_pressure_high grp_local_pressure_low using "`rtf_final'", append rtf ///
    order(sim_mean recent_sd_10 ln_recent_volumn_10 recent_rating_10 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(HotelFE TimeFE N r2_a Fisher_p, ///
        labels("Hotel fixed effects" "Time fixed effects" "Observations" "Adjusted R-squared" "bdiff Fisher p-value") ///
        fmt(%18s %18s %12.0fc %9.3f %9.3f)) ///
    mtitles("Thick ZIP market" "Thin ZIP market" "High competitor RevPAR" "Low competitor RevPAR") ///
    label nogap compress title("Panel C2. Market: grouped regressions and bdiff")

display as result "Final DTA: `data_final'"
display as result "Final RTF: `rtf_final'"
