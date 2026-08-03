************************************************************
* Table 10: revenue-based HHI market concentration.
*
* Construction:
*   HHI_mt = sum_j (hotel revenue_jmt / market revenue_mt)^2
* Markets are ZIP x month and City x month.
*
* Source coverage:
*   2011--2016: Texas hotel tax data with city and ZIP.
*   2017--2022: full hotel revenue panel; city is assigned from
*               the modal historical ZIP-to-city crosswalk.
*
* Final data action:
*   Adds hhi_rev_zip and hhi_rev_city directly to the existing
*   routeAB panel. No new permanent analysis dataset is created.
************************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close _all
mata: mata set matafavor speed

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_root "/Users/samxie/Research/ReviewSimi_Sales/Data"
local data_main "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local revenue_old "`data_root'/matched_new/tax2011_2016.csv"
local revenue_new "`data_root'/matched_new/HOT_Revenue_Com_Final.csv"
local revenue_map "`data_root'/month_revenue_20250304.csv"
local logfile "`project'/stata-log/run_table10_hhi_competition_260722.log"
local rtf "`project'/outputs/paper/rtf-0722/table10_hhi_competition_260722.rtf"

foreach f in "`data_main'" "`revenue_old'" "`revenue_new'" "`revenue_map'" {
    capture confirm file "`f'"
    if _rc exit 601
}
foreach cmd in reghdfe winsor2 esttab bdiff {
    capture which `cmd'
    if _rc exit 199
}

log using "`logfile'", text replace

tempfile zip_city_map city_id_map hotel_zip_map old_hotels new_hotels
tempfile hhi_zip hhi_city

************************************************************
* 1. Historical ZIP-to-city crosswalk and 2011--2016 hotels.
************************************************************
import delimited using "`revenue_old'", varnames(1) case(preserve) ///
    encoding("ISO-8859-1") stringcols(_all) colrange(1:12) clear

destring year month LocationZip, replace force
drop if !inrange(year, 2011, 2016) | !inrange(month, 1, 12)

gen int ym = ym(year, month)
format ym %tm
gen str5 market_zip = string(LocationZip, "%05.0f") if !missing(LocationZip)
gen str40 market_city = ustrupper(ustrtrim(LocationCity))
replace market_city = itrim(market_city)

preserve
    keep market_zip market_city
    drop if missing(market_zip) | missing(market_city)
    contract market_zip market_city
    gsort market_zip -_freq market_city
    by market_zip: keep if _n == 1
    isid market_zip
    keep market_zip market_city
    save `zip_city_map'
restore

replace TotalRoomReceipts = subinstr(TotalRoomReceipts, "$", "", .)
replace TotalRoomReceipts = subinstr(TotalRoomReceipts, ",", "", .)
destring TotalRoomReceipts, gen(room_revenue) force
drop if missing(market_zip) | missing(market_city) | missing(room_revenue)
drop if room_revenue < 0

egen long property_id = group(TaxpayerNumber LocationNumber LocationName LocationAddress market_zip)
collapse (max) room_revenue, by(property_id market_zip market_city ym)
save `old_hotels'

************************************************************
* 2. City-name to routeAB CityID crosswalk.
************************************************************
import delimited using "`revenue_map'", varnames(1) case(preserve) ///
    encoding("UTF-8") stringcols(_all) colrange(1:19) clear

gen str40 market_city = ustrupper(ustrtrim(CityName))
replace market_city = itrim(market_city)
gen str20 hhi_merge_cityid = strtrim(CityID)

preserve
    keep market_city hhi_merge_cityid
    drop if missing(market_city) | missing(hhi_merge_cityid)
    duplicates drop
    isid market_city
    save `city_id_map'
restore

* Recover ZIP for routeAB hotels whose panel ZIP is blank.
gen str20 hhi_merge_hotelid = strtrim(HotelID)
gen double zip_num = real(Zip)
gen str5 hhi_map_zip = string(zip_num, "%05.0f") if !missing(zip_num)
keep hhi_merge_hotelid hhi_map_zip
drop if missing(hhi_merge_hotelid) | missing(hhi_map_zip)
contract hhi_merge_hotelid hhi_map_zip
gsort hhi_merge_hotelid -_freq hhi_map_zip
by hhi_merge_hotelid: keep if _n == 1
isid hhi_merge_hotelid
keep hhi_merge_hotelid hhi_map_zip
save `hotel_zip_map'

************************************************************
* 3. Full 2017--2022 hotel revenue panel.
************************************************************
import delimited using "`revenue_new'", varnames(1) case(preserve) ///
    encoding("ISO-8859-1") stringcols(_all) colrange(1:8) clear

destring Year Mon Location_Zip, replace force
drop if !inrange(Year, 2017, 2022) | !inrange(Mon, 1, 12)
gen int ym = ym(Year, Mon)
format ym %tm
gen str5 market_zip = string(Location_Zip, "%05.0f") if !missing(Location_Zip)

replace Total_Room_Receipts = subinstr(Total_Room_Receipts, "$", "", .)
replace Total_Room_Receipts = subinstr(Total_Room_Receipts, ",", "", .)
destring Total_Room_Receipts, gen(room_revenue) force
drop if missing(market_zip) | missing(room_revenue)
drop if room_revenue < 0

merge m:1 market_zip using `zip_city_map', keep(master match) nogen
keep market_zip market_city ym room_revenue
save `new_hotels'

************************************************************
* 4. Revenue HHI for ZIP x month.
************************************************************
use `old_hotels', clear
keep market_zip ym room_revenue
append using `new_hotels', keep(market_zip ym room_revenue)

bysort market_zip ym: egen double market_revenue = total(room_revenue)
gen double revenue_share_sq = (room_revenue / market_revenue)^2 ///
    if market_revenue > 0 & !missing(room_revenue)
bysort market_zip ym: egen double hhi_rev_zip = total(revenue_share_sq)
replace hhi_rev_zip = . if market_revenue <= 0 | missing(market_revenue)
keep market_zip ym hhi_rev_zip
drop if missing(hhi_rev_zip)
duplicates drop
isid market_zip ym
assert inrange(hhi_rev_zip, 0, 1.0000001)
rename market_zip hhi_merge_zip
save `hhi_zip'

************************************************************
* 5. Revenue HHI for City x month.
************************************************************
use `old_hotels', clear
keep market_city ym room_revenue
append using `new_hotels', keep(market_city ym room_revenue)
drop if missing(market_city)

bysort market_city ym: egen double market_revenue = total(room_revenue)
gen double revenue_share_sq = (room_revenue / market_revenue)^2 ///
    if market_revenue > 0 & !missing(room_revenue)
bysort market_city ym: egen double hhi_rev_city = total(revenue_share_sq)
replace hhi_rev_city = . if market_revenue <= 0 | missing(market_revenue)
keep market_city ym hhi_rev_city
drop if missing(hhi_rev_city)
duplicates drop
isid market_city ym
assert inrange(hhi_rev_city, 0, 1.0000001)

merge m:1 market_city using `city_id_map', keep(match) nogen
keep hhi_merge_cityid ym hhi_rev_city
isid hhi_merge_cityid ym
save `hhi_city'

************************************************************
* 6. Join the two HHI fields into the existing routeAB panel.
************************************************************
use "`data_main'", clear
isid HotelID ym

capture drop hhi_rev_zip hhi_rev_city
capture drop _merge_hhi_zip _merge_hhi_city

capture confirm string variable Zip
if !_rc gen str5 hhi_merge_zip = string(real(Zip), "%05.0f") if !missing(Zip)
else gen str5 hhi_merge_zip = string(Zip, "%05.0f") if !missing(Zip)

capture confirm string variable HotelID
if !_rc gen str20 hhi_merge_hotelid = strtrim(HotelID)
else gen str20 hhi_merge_hotelid = string(HotelID, "%18.0g") if !missing(HotelID)
merge m:1 hhi_merge_hotelid using `hotel_zip_map', keep(master match) nogen
replace hhi_merge_zip = hhi_map_zip if missing(hhi_merge_zip) & !missing(hhi_map_zip)
drop hhi_merge_hotelid hhi_map_zip

capture confirm string variable CityID
if !_rc gen str20 hhi_merge_cityid = strtrim(CityID)
else gen str20 hhi_merge_cityid = string(CityID, "%18.0g") if !missing(CityID)

merge m:1 hhi_merge_zip ym using `hhi_zip', ///
    keep(master match) gen(_merge_hhi_zip)
merge m:1 hhi_merge_cityid ym using `hhi_city', ///
    keep(master match) gen(_merge_hhi_city)

count if _merge_hhi_zip == 3
local n_zip_match = r(N)
count if _merge_hhi_zip == 1
local n_zip_unmatch = r(N)
count if _merge_hhi_city == 3
local n_city_match = r(N)
count if _merge_hhi_city == 1
local n_city_unmatch = r(N)

assert inrange(hhi_rev_zip, 0, 1.0000001) if !missing(hhi_rev_zip)
assert inrange(hhi_rev_city, 0, 1.0000001) if !missing(hhi_rev_city)

label variable hhi_rev_zip "Revenue HHI: ZIP x month"
label variable hhi_rev_city "Revenue HHI: City x month"
notes hhi_rev_zip: Sum of squared hotel monthly-room-revenue shares in ZIP x month; full local hotel market.
notes hhi_rev_city: Sum of squared hotel monthly-room-revenue shares in City x month; full local hotel market.

drop hhi_merge_zip hhi_merge_cityid _merge_hhi_zip _merge_hhi_city
compress
sort hotel_id_num ym
save "`data_main'", replace

display as text "HHI merge coverage: ZIP matched = `n_zip_match'; ZIP unmatched = `n_zip_unmatch'"
display as text "HHI merge coverage: City matched = `n_city_match'; City unmatched = `n_city_unmatch'"

************************************************************
* 7. Table 10: low- versus high-HHI market-month cells.
* HHI is constant within its market x month cell. Therefore,
* medians are calculated across unique market-month cells, not
* within the same cell (which would mechanically leave one group empty).
************************************************************


capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
xtset hotel_id_num ym

capture drop hhi_base_cc hhi_zip_cell_cc hhi_city_cell_cc
capture drop hhi_zip_tag hhi_city_tag
capture drop het_med_hhi_zip het_med_hhi_city
capture drop het_high_hhi_zip het_high_hhi_city


capture confirm variable ln_RevPAR_clean_w199
if _rc winsor2 ln_RevPAR_clean, cuts(1 99) by(City ym) suffix(_w199)

capture confirm variable ln_lag_RevPAR_clean_w199
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 99) by(City ym) suffix(_w199)

capture confirm variable ln_RevPAR_clean_w195
if _rc winsor2 ln_RevPAR_clean, cuts(1 95) by(City ym) suffix(_w195)

capture confirm variable ln_lag_RevPAR_clean_w195
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 95) by(City ym) suffix(_w195)

capture confirm variable ln_RevPAR_clean_w595
if _rc winsor2 ln_RevPAR_clean, cuts(5 95) by(City ym) suffix(_w595)

capture confirm variable ln_lag_RevPAR_clean_w595
if _rc winsor2 ln_lag_RevPAR_clean, cuts(5 95) by(City ym) suffix(_w595)


egen byte hhi_base_missing = rowmiss(ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595)
gen byte hhi_base_cc = (cs_sample_focus100 == 1 & hhi_base_missing == 0)
drop hhi_base_missing

bysort Zip ym: egen byte hhi_zip_cell_cc = max(hhi_base_cc)
egen byte hhi_zip_tag = tag(Zip ym) if hhi_zip_cell_cc == 1 & !missing(hhi_rev_zip)
quietly summarize hhi_rev_zip if hhi_zip_tag == 1, detail
scalar het_med_hhi_zip = r(p50)

bysort CityID ym: egen byte hhi_city_cell_cc = max(hhi_base_cc)
egen byte hhi_city_tag = tag(CityID ym) if hhi_city_cell_cc == 1 & !missing(hhi_rev_city)
quietly summarize hhi_rev_city if hhi_city_tag == 1, detail
scalar het_med_hhi_city = r(p50)

gen byte het_high_hhi_zip = .
replace het_high_hhi_zip = 0 if hhi_base_cc & hhi_rev_zip < scalar(het_med_hhi_zip)
replace het_high_hhi_zip = 1 if hhi_base_cc & hhi_rev_zip >= scalar(het_med_hhi_zip) & !missing(hhi_rev_zip)

gen byte het_high_hhi_city = .
replace het_high_hhi_city = 0 if hhi_base_cc & hhi_rev_city < scalar(het_med_hhi_city)
replace het_high_hhi_city = 1 if hhi_base_cc & hhi_rev_city >= scalar(het_med_hhi_city) & !missing(hhi_rev_city)

label define hhi_lowhigh 0 "Low HHI (high competition)" 1 "High HHI (low competition)", replace
label values het_high_hhi_zip hhi_lowhigh
label values het_high_hhi_city hhi_lowhigh

label variable sim_mean "ARS"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable lag_avg_rating_month "Rating month, t-1"
label variable rating_last_5 "Rating last 5, t"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating, t-1"
label variable lag_sd_acc "Accumulated rating SD, t-1"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"
label variable ln_lag_RevPAR_clean_w595 "ln(RevPAR), t-1"

estimates clear

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 hhi_rev_zip ///
    if het_high_hhi_zip == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_zip_low

reghdfe ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199 hhi_rev_zip ///
    if het_high_hhi_zip == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_zip_high

bdiff, group(het_high_hhi_zip) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(100) seed(260722) first

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_hhi_city == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_city_low

reghdfe ln_RevPAR_clean sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ///
    if het_high_hhi_city == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_city_high

bdiff, group(het_high_hhi_city) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_lag_RevPAR_clean_w595 hhi_rev_city, ///
        absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(100) seed(260722) first

esttab t10_zip_low t10_zip_high t10_city_low t10_city_high using "`rtf'", replace rtf ///
    order(sim_mean recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("ZIP: Low HHI" "ZIP: High HHI" "City: Low HHI" "City: High HHI") ///
    title("Table 10. Revenue-based market concentration (HHI)") ///
    addnotes("Standard errors are clustered at the hotel level." ///
        "HHI is the sum of squared hotel monthly-room-revenue shares in each market-month." ///
        "Higher HHI indicates greater concentration and weaker competition.") ///
    label nogap compress

log close
