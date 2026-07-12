version 17.0
set more off
keep if sample_final_reviews_gt100 == 1
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen ym = monthly(event_ym, "YM")
format ym %tm
capture drop lnRevenue_current_w199 lnRevenue_current_w595 lnRevenue_lag_month_w199 lnRevenue_lag_month_w595
winsor2 lnRevenue_current, cuts(1 99) suffix(_w199)
winsor2 lnRevenue_current, cuts(5 95) suffix(_w595)
winsor2 lnRevenue_lag_month, cuts(1 99) suffix(_w199)
winsor2 lnRevenue_lag_month, cuts(5 95) suffix(_w595)
capture drop zip_n_full_c city_n_full_c gap_zip_mean_full_c gap_city_mean_full_c price_gap_c
foreach x in zip_n_full city_n_full gap_zip_mean_full gap_city_mean_full price_gap {
    quietly summarize `x' if sample_final_reviews_gt100 == 1, meanonly
    gen double `x'_c = `x' - r(mean) if !missing(`x')
}
capture drop star_class_bucket3 high_star4 high_rank_status high_popularity hotel_evaluation_factor ln_pmr_words ln_pmr_avg_words
gen byte star_class_bucket3 = 1 if star_class_final < 3 & !missing(star_class_final)
replace star_class_bucket3 = 2 if star_class_final >= 3 & star_class_final < 4
replace star_class_bucket3 = 3 if star_class_final >= 4 & !missing(star_class_final)
gen byte high_star4 = star_class_final >= 4 if !missing(star_class_final)
quietly summarize hotel_rank_pct if sample_final_reviews_gt100 == 1 & !missing(hotel_rank_pct), detail
gen byte high_rank_status = hotel_rank_pct <= r(p50) if !missing(hotel_rank_pct)
quietly bysort Zip ym: egen double pool_pop_median = median(ln_lag_volumn_acc)
gen byte high_popularity = ln_lag_volumn_acc > pool_pop_median if !missing(ln_lag_volumn_acc, pool_pop_median)
drop pool_pop_median
capture confirm string variable hotel_evaluation_raw
if !_rc encode hotel_evaluation_raw, gen(hotel_evaluation_factor)
else gen long hotel_evaluation_factor = hotel_evaluation_raw
gen double ln_pmr_words = ln(pmr_activity_words + 1)
gen double ln_pmr_avg_words = ln(pmr_activity_avg_words + 1) if !missing(pmr_activity_avg_words)
xtset hotel_id_num ym
