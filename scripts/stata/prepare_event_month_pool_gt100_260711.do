version 17.0
set more off
keep if cs_sample_focus100 == 1
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
capture drop ym
gen ym = monthly(year_month, "YM")
format ym %tm
capture drop ln_RevPAR_clean_w199 ln_RevPAR_clean_w595 ln_lag_RevPAR_clean_w199 ln_lag_RevPAR_clean_w595
* Use Stata's built-in percentile command so the replication does not depend
* on the user-installed winsor2 package.
foreach x in ln_RevPAR_clean ln_lag_RevPAR_clean {
    quietly _pctile `x' if !missing(`x'), p(1 99)
    local p1 = r(r1)
    local p99 = r(r2)
    gen double `x'_w199 = `x'
    replace `x'_w199 = min(max(`x', `p1'), `p99') if !missing(`x')
    quietly _pctile `x' if !missing(`x'), p(5 95)
    local p5 = r(r1)
    local p95 = r(r2)
    gen double `x'_w595 = `x'
    replace `x'_w595 = min(max(`x', `p5'), `p95') if !missing(`x')
}
capture drop zip_n_full_c city_n_full_c gap_zip_mean_full_c gap_city_mean_full_c price_gap_c
foreach x in zip_n_full city_n_full gap_zip_mean_full gap_city_mean_full price_gap {
    quietly summarize `x' if sample_final_reviews_gt100 == 1, meanonly
    gen double `x'_c = `x' - r(mean) if !missing(`x')
}
capture drop star_class_bucket3 high_star4 high_rank_status high_popularity hotel_evaluation_factor ln_lag_mr_words ln_lag_mr_avg_words
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
gen double ln_lag_mr_words = ln(lag_mr_text_words + 1)
gen double ln_lag_mr_avg_words = ln(lag_mr_avg_text_words + 1) if !missing(lag_mr_avg_text_words)
xtset hotel_id_num ym
