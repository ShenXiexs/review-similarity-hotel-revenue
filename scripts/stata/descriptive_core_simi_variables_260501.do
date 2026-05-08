*******************************************************
* descriptive_core_simi_variables_260501.do
* Descriptive statistics and correlations for the
* variables used in run_core_simi_explicit_regressions_260501.do.
*******************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/core_simi_260501"
local data_main "`out_root'/data/core_simi_panel_260501.dta"
local summary_dir "`out_root'/summary"

cap mkdir "`summary_dir'"

use "`data_main'", clear
log using "`summary_dir'/descriptive_core_simi_variables_260501.log", text replace

*******************************************************
************ 1. Recreate generated variables ************
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

capture which winsor2
local has_winsor2 = cond(_rc == 0, 1, 0)

capture drop ln_RevPAR_clean_w
gen ln_RevPAR_clean_w = ln_RevPAR_clean
if `has_winsor2' {
    winsor2 ln_RevPAR_clean_w if cs_sample_focus100 == 1, cut(1 99) replace
}

capture drop ln_lag_RevPAR_clean_w
gen ln_lag_RevPAR_clean_w = ln_lag_RevPAR_clean
if `has_winsor2' {
    winsor2 ln_lag_RevPAR_clean_w if cs_sample_focus100 == 1, cut(1 99) replace
}

capture drop cs_covid2020 cs_covid2021 cs_covid2022
gen byte cs_covid2020 = (Year == 2020)
gen byte cs_covid2021 = (Year == 2021)
gen byte cs_covid2022 = (Year == 2022)

capture drop h2_med_rating5_ym h2_low_rating5_ym
bysort ym: egen h2_med_rating5_ym = median(rating_last_5)
gen h2_low_rating5_ym = .
replace h2_low_rating5_ym = 1 if cs_sample_focus100 == 1 & rating_last_5 < h2_med_rating5_ym
replace h2_low_rating5_ym = 0 if cs_sample_focus100 == 1 & rating_last_5 >= h2_med_rating5_ym

capture drop h2_med_lag_avg_rating_acc h2_low_lag_avg_rating_acc
bysort ym: egen h2_med_lag_avg_rating_acc = median(lag_avg_rating_acc)
gen h2_low_lag_avg_rating_acc = .
replace h2_low_lag_avg_rating_acc = 1 if cs_sample_focus100 == 1 & lag_avg_rating_acc <= h2_med_lag_avg_rating_acc
replace h2_low_lag_avg_rating_acc = 0 if cs_sample_focus100 == 1 & lag_avg_rating_acc > h2_med_lag_avg_rating_acc

capture drop h2_med_lag_avg_rating_month h2_low_lag_avg_rating_month
bysort ym: egen h2_med_lag_avg_rating_month = median(lag_avg_rating_month)
gen h2_low_lag_avg_rating_month = .
replace h2_low_lag_avg_rating_month = 1 if cs_sample_focus100 == 1 & lag_avg_rating_month <= h2_med_lag_avg_rating_month
replace h2_low_lag_avg_rating_month = 0 if cs_sample_focus100 == 1 & lag_avg_rating_month > h2_med_lag_avg_rating_month

capture drop h3_med_lag_recent_volumn h3_low_lag_recent_volumn
bysort CityID ym: egen h3_med_lag_recent_volumn = median(lag_recent_volumn)
gen h3_low_lag_recent_volumn = .
replace h3_low_lag_recent_volumn = 1 if cs_sample_focus100 == 1 & lag_recent_volumn < h3_med_lag_recent_volumn
replace h3_low_lag_recent_volumn = 0 if cs_sample_focus100 == 1 & lag_recent_volumn >= h3_med_lag_recent_volumn

capture drop h3_med_ln_lag_volumn_acc h3_low_ln_lag_volumn_acc
egen h3_med_ln_lag_volumn_acc = median(ln_lag_volumn_acc)
gen h3_low_ln_lag_volumn_acc = .
replace h3_low_ln_lag_volumn_acc = 1 if cs_sample_focus100 == 1 & ln_lag_volumn_acc < h3_med_ln_lag_volumn_acc
replace h3_low_ln_lag_volumn_acc = 0 if cs_sample_focus100 == 1 & ln_lag_volumn_acc >= h3_med_ln_lag_volumn_acc

capture drop h4_low_star35
gen h4_low_star35 = .
replace h4_low_star35 = 1 if cs_sample_focus100 == 1 & Year <= 2019 & star_class <= 3.5
replace h4_low_star35 = 0 if cs_sample_focus100 == 1 & Year <= 2019 & star_class > 3.5

capture drop h5_med_recent_sd h5_low_recent_sd
bysort CityID ym: egen h5_med_recent_sd = median(recent_sd)
gen h5_low_recent_sd = .
replace h5_low_recent_sd = 1 if cs_sample_focus100 == 1 & recent_sd < h5_med_recent_sd
replace h5_low_recent_sd = 0 if cs_sample_focus100 == 1 & recent_sd >= h5_med_recent_sd

capture drop covid2020 covid2020_2022 post2020 pre_covid zip_num
gen byte covid2020 = (Year == 2020)
gen byte covid2020_2022 = inrange(Year, 2020, 2022)
gen byte post2020 = (Year >= 2020)
gen byte pre_covid = (Year <= 2019)
egen zip_num = group(Zip)

capture drop h2_covid_med_zipym h2_covid_lowrep
bysort zip_num ym: egen h2_covid_med_zipym = median(lag_rating_last_5)
gen h2_covid_lowrep = .
replace h2_covid_lowrep = 1 if cs_sample_focus100 == 1 & lag_rating_last_5 < h2_covid_med_zipym
replace h2_covid_lowrep = 0 if cs_sample_focus100 == 1 & lag_rating_last_5 >= h2_covid_med_zipym

capture drop h3_covid_med_all h3_covid_lowpop
egen h3_covid_med_all = median(lag_recent_volumn)
gen h3_covid_lowpop = .
replace h3_covid_lowpop = 1 if cs_sample_focus100 == 1 & lag_recent_volumn < h3_covid_med_all
replace h3_covid_lowpop = 0 if cs_sample_focus100 == 1 & lag_recent_volumn >= h3_covid_med_all

capture drop h4_covid_lowstar3
gen h4_covid_lowstar3 = .
replace h4_covid_lowstar3 = 1 if cs_sample_focus100 == 1 & star_class <= 3
replace h4_covid_lowstar3 = 0 if cs_sample_focus100 == 1 & star_class > 3

capture drop h2_pre h2_shock h2_pandemic h3_pre h3_shock h3_pandemic h4_pre h4_shock h4_pandemic
gen h2_pre = h2_covid_lowrep if Year <= 2019
gen h2_shock = h2_covid_lowrep if Year == 2020
gen h2_pandemic = h2_covid_lowrep if inrange(Year, 2020, 2022)
gen h3_pre = h3_covid_lowpop if Year <= 2019
gen h3_shock = h3_covid_lowpop if Year == 2020
gen h3_pandemic = h3_covid_lowpop if inrange(Year, 2020, 2022)
gen h4_pre = h4_covid_lowstar3 if Year <= 2019
gen h4_shock = h4_covid_lowstar3 if Year == 2020
gen h4_pandemic = h4_covid_lowstar3 if inrange(Year, 2020, 2022)

*******************************************************
************ 2. Dataset volume audit ************
*******************************************************

di as text "===== Dataset volume ====="
describe
count
di as result "Total observations = " r(N)

egen tag_hotel = tag(hotel_id_num)
count if tag_hotel == 1
di as result "Unique hotels = " r(N)

egen tag_city = tag(CityID)
count if tag_city == 1
di as result "Unique cities = " r(N)

egen tag_zip = tag(zip_num)
count if tag_zip == 1
di as result "Unique ZIP groups = " r(N)

egen tag_ym = tag(ym)
count if tag_ym == 1
di as result "Unique months = " r(N)

tab Year if cs_sample_focus100 == 1
tab Mon if cs_sample_focus100 == 1

foreach s in cs_sample_full cs_sample_focus50 cs_sample_focus100 cs_sample_exclude2020 cs_sample_post2013 {
    count if `s' == 1
    di as result "`s' observations = " r(N)
    preserve
    keep if `s' == 1
    capture drop tag_hotel_sample
    egen tag_hotel_sample = tag(hotel_id_num)
    count if tag_hotel_sample == 1
    di as result "`s' hotels = " r(N)
    restore
}

*******************************************************
************ 3. Descriptive statistics CSV ************
*******************************************************

local desc_vars ln_RevPAR_clean ln_RevPAR_clean_w d_ln_RevPAR sim_mean ///
    ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_recent_volumn ///
    lag_avg_rating_acc lag_sd_acc lag_avg_rating_month lag_rating_last_5 ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean ln_lag_RevPAR_clean_w star_class ///
    h2_low_rating5_ym h2_low_lag_avg_rating_acc h2_low_lag_avg_rating_month ///
    h3_low_lag_recent_volumn h3_low_ln_lag_volumn_acc h4_low_star35 ///
    h5_low_recent_sd covid2020 covid2020_2022 post2020 pre_covid ///
    h2_covid_lowrep h3_covid_lowpop h4_covid_lowstar3

tempname post_desc
tempfile desc_dta
postfile `post_desc' str40 variable double N mean sd variance p25 median p75 min max missing using `desc_dta', replace

foreach v of local desc_vars {
    capture confirm numeric variable `v'
    if _rc == 0 {
        quietly count if cs_sample_focus100 == 1 & missing(`v')
        local missing = r(N)
        quietly summarize `v' if cs_sample_focus100 == 1, detail
        if r(N) > 0 {
            post `post_desc' ("`v'") (r(N)) (r(mean)) (r(sd)) (r(Var)) ///
                (r(p25)) (r(p50)) (r(p75)) (r(min)) (r(max)) (`missing')
        }
    }
}

postclose `post_desc'
preserve
use `desc_dta', clear
export delimited using "`summary_dir'/desc_stats_core_simi_260501.csv", replace
restore

*******************************************************
************ 4. Correlation matrix CSV ************
*******************************************************

local corr_vars ln_RevPAR_clean d_ln_RevPAR sim_mean ln_recent_volumn recent_sd ///
    rating_last_5 ln_lag_volumn_acc lag_recent_volumn lag_avg_rating_acc ///
    lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean star_class

pwcorr `corr_vars' if cs_sample_focus100 == 1, sig obs star(0.05)
correlate `corr_vars' if cs_sample_focus100 == 1
matrix C = r(C)

preserve
clear
svmat double C, names(col)
gen variable = ""
local i = 1
foreach v of local corr_vars {
    replace variable = "`v'" in `i'
    local i = `i' + 1
}
order variable
export delimited using "`summary_dir'/corr_core_simi_260501.csv", replace
restore

log close

*******************************************************
* End
*******************************************************
