************************************************************
* Re-run of the regression results reported in
* outputs/paper/reviewsimi-revenue-0521.docx
*
* Historical source:
*   run_core_simi_explicit_regressions_260501.do
*   Git commit 26fa252eb337c9a3da9cbac89d7124fb9f9adea9
*
* Change requested on 2026-07-15:
*   rating_last_5 is removed from every regression RHS.
*   It is retained only to reconstruct the original Table 6/7
*   rating-last-five subgroup; it is not a control variable.
*
* Correction requested on 2026-07-17:
*   Replace lag_avg_rating_month with the matching recent-rating measure.
*   Table 10 matches recent_rating_5/10/15/20/30 to its review scope;
*   all other tables retain recent_rating_10, their 10-review base measure.
*   The enriched panel is used because the original core panel does not
*   contain the recent-rating variables.
*
* Persistent outputs:
*   1) this do-file
*   2) one final RTF only
* No log, CSV, XLSX, TXT, or DTA is generated.
************************************************************

version 17.0
clear all
set more off
set linesize 255
capture log close _all
mata: mata set matafavor speed

local project  "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data_dir "`project'/outputs/core_simi_260501/data"
local data_main "`data_dir'/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local data_alt  "`data_dir'/core_simi_panel_260501_with_altars.dta"
local data_scope "`data_dir'/core_simi_panel_260501_with_scope_ars.dta"
local data_chain "`data_dir'/core_simi_panel_260501_with_mr_text_sentiment_260526.dta"
local rtf "`project'/outputs/paper/rtf/reviewsimi_revenue_0521_rerun_recent_rating10_260717.rtf"

foreach f in "`data_main'" "`data_alt'" "`data_scope'" "`data_chain'" {
    capture confirm file `f'
    if _rc {
        display as error "Required data file not found: `f'"
        exit 601
    }
}

foreach cmd in reghdfe esttab estpost winsor2 bdiff {
    capture which `cmd'
    if _rc {
        display as error "Required command not installed: `cmd'"
        exit 199
    }
}

* Original paper used 500 permutation draws for the reported
* between-group Fisher/empirical p-values. An optional first do-file
* argument can lower this only for a quick syntax test, for example:
* do rerun_reviewsimi_revenue_0521_no_ratinglast5_260715.do 2
args bdiff_reps
if "`bdiff_reps'" == "" local bdiff_reps 500
local seed 202505

local controls "ln_recent_volumn recent_sd recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean"
local controls_wlag "ln_recent_volumn recent_sd recent_rating_10 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ln_lag_RevPAR_clean_w"

************************************************************
* 1. Main panel and historically used winsorized outcomes
************************************************************

use "`data_main'", clear

capture drop hotel_id_num
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID

capture drop ym
gen int ym = monthly(year_month, "YM")
format ym %tm
sort hotel_id_num ym
isid hotel_id_num ym
xtset hotel_id_num ym

keep if cs_sample_focus100 == 1

* Table 9 uses the alternative-ARS panel, which does not retain
* recent_rating_10.  Save an exact HotelID x month lookup from the enriched
* core panel and merge it later; the two panels have complete key overlap.
tempfile recent_rating10_lookup
preserve
    keep HotelID year_month recent_rating_10
    isid HotelID year_month
    save `recent_rating10_lookup', replace
restore

capture drop ln_RevPAR_clean_w ln_lag_RevPAR_clean_w
gen double ln_RevPAR_clean_w = ln_RevPAR_clean
winsor2 ln_RevPAR_clean_w if cs_sample_focus50 == 1, cut(2.5 97.5) replace
gen double ln_lag_RevPAR_clean_w = ln_lag_RevPAR_clean
winsor2 ln_lag_RevPAR_clean_w if cs_sample_focus50 == 1, cut(2.5 97.5) replace

capture drop ln_RevPAR_clean_w199 ln_lag_RevPAR_clean_w199
gen double ln_RevPAR_clean_w199 = ln_RevPAR_clean
winsor2 ln_RevPAR_clean_w199, cut(1 99) replace
gen double ln_lag_RevPAR_clean_w199 = ln_lag_RevPAR_clean
winsor2 ln_lag_RevPAR_clean_w199, cut(1 99) replace

label variable ln_RevPAR_clean "ln(RevPAR)"
label variable sim_mean "ARS i,t"
label variable ln_recent_volumn "Recent volume i,t"
label variable recent_volumn "Recent volume"
label variable recent_sd "Recent SD i,t"
label variable recent_rating_10 "Recent rating i,t-1 (10-review window)"
label variable ln_lag_volumn_acc "Review volume i,t-1"
label variable lag_volumn_acc "Review volume, t-1"
label variable lag_recent_volumn "Recent volume, t-1"
label variable lag_avg_rating_acc "Rating acc. i,t-1"
label variable lag_sd_acc "Rating SD acc. i,t-1"
label variable ln_avg_com_RevPAR "Competitor RevPAR i,t"
label variable ln_lag_RevPAR_clean "RevPAR i,t-1"
label variable star_class "Star class"

************************************************************
* Table 3. Descriptive statistics
* rating_last_5 and lag_rating_last_5 are intentionally absent.
************************************************************

local descvars ln_RevPAR_clean sim_mean ln_recent_volumn recent_volumn recent_sd ///
    ln_lag_volumn_acc lag_volumn_acc lag_recent_volumn lag_avg_rating_acc ///
    lag_sd_acc recent_rating_10 ln_avg_com_RevPAR ///
    ln_lag_RevPAR_clean star_class

estpost summarize `descvars', detail
esttab using "`rtf'", replace rtf ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(3)) p50(fmt(3)) max(fmt(3))") ///
    label noobs nonumber nomtitle ///
    title("Table 3. Descriptive statistics; rating_last_5 removed")

************************************************************
* Table 4. Correlation matrix
************************************************************

estpost correlate `descvars', matrix
esttab using "`rtf'", append rtf ///
    cells("b(fmt(3))") unstack not noobs compress label nonumber nostar ///
    title("Table 4. Correlation matrix; rating_last_5 removed")

************************************************************
* Table 5. FE and OLS re-run
* The document's old Sys-GMM column contained no valid result.
* The corrected Route-A Sys-GMM is estimated in a separate do-file.
************************************************************

estimates clear
reghdfe ln_RevPAR_clean sim_mean `controls', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estadd local HotelFE "YES"
estadd local TimeFE "YES"
estimates store t5_fe

reg ln_RevPAR_clean sim_mean `controls', vce(cluster hotel_id_num)
estadd local HotelFE "NO"
estadd local TimeFE "NO"
estimates store t5_ols

esttab t5_fe t5_ols using "`rtf'", append rtf ///
    order(sim_mean `controls') ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(HotelFE TimeFE N r2_a, ///
        labels("Hotel fixed effects" "Time fixed effects" "Observations" "Adjusted R-squared") ///
        fmt(%9s %9s %12.0fc %9.3f)) ///
    mtitles("FE" "OLS") label nogap compress ///
    title("Table 5. FE and OLS; rating_last_5 removed")

************************************************************
* 2. Moderator definitions used in Tables 6, 6-2, and 7
************************************************************

capture drop h2_med_rating5_ym h2_low_rating5_ym
bysort CityID ym: egen double h2_med_rating5_ym = median(rating_last_5)
gen byte h2_low_rating5_ym = .
replace h2_low_rating5_ym = 1 if rating_last_5 <= h2_med_rating5_ym
replace h2_low_rating5_ym = 0 if rating_last_5 > h2_med_rating5_ym
label variable h2_low_rating5_ym "Low rating-last-five group"

capture drop h3_med_lag_recent_volumn h3_low_lag_recent_volumn
bysort ym: egen double h3_med_lag_recent_volumn = median(lag_recent_volumn)
gen byte h3_low_lag_recent_volumn = .
replace h3_low_lag_recent_volumn = 1 if lag_recent_volumn < h3_med_lag_recent_volumn
replace h3_low_lag_recent_volumn = 0 if lag_recent_volumn >= h3_med_lag_recent_volumn
label variable h3_low_lag_recent_volumn "Low recent-volume group"

capture drop h4_low_star4
gen byte h4_low_star4 = .
replace h4_low_star4 = 1 if star_class <= 4
replace h4_low_star4 = 0 if star_class > 4
label variable h4_low_star4 "Hotel at or below four stars"

capture drop h2_med_lag_avg_rating_acc h2_low_lag_avg_rating_acc
bysort City ym: egen double h2_med_lag_avg_rating_acc = median(lag_avg_rating_acc)
gen byte h2_low_lag_avg_rating_acc = .
replace h2_low_lag_avg_rating_acc = 1 if lag_avg_rating_acc <= h2_med_lag_avg_rating_acc
replace h2_low_lag_avg_rating_acc = 0 if lag_avg_rating_acc > h2_med_lag_avg_rating_acc
label variable h2_low_lag_avg_rating_acc "Low accumulated-rating group"

capture drop h3_med_ln_lag_volumn_acc h3_low_ln_lag_volumn_acc
bysort ym: egen double h3_med_ln_lag_volumn_acc = median(ln_lag_volumn_acc)
gen byte h3_low_ln_lag_volumn_acc = .
replace h3_low_ln_lag_volumn_acc = 1 if ln_lag_volumn_acc < h3_med_ln_lag_volumn_acc
replace h3_low_ln_lag_volumn_acc = 0 if ln_lag_volumn_acc >= h3_med_ln_lag_volumn_acc
label variable h3_low_ln_lag_volumn_acc "Low accumulated-volume group"

capture drop h5_med_lag_sd_acc h5_low_lag_sd_acc
bysort ym: egen double h5_med_lag_sd_acc = median(lag_sd_acc)
gen byte h5_low_lag_sd_acc = .
replace h5_low_lag_sd_acc = 1 if lag_sd_acc <= h5_med_lag_sd_acc
replace h5_low_lag_sd_acc = 0 if lag_sd_acc > h5_med_lag_sd_acc
label variable h5_low_lag_sd_acc "Low accumulated-SD group"

************************************************************
* Table 6. Rating-last-five, recent-volume, and star groups
* rating_last_5 is only the first split variable, never an RHS control.
************************************************************

reghdfe ln_RevPAR_clean sim_mean `controls' if h2_low_rating5_ym == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_rating_low
reghdfe ln_RevPAR_clean sim_mean `controls' if h2_low_rating5_ym == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_rating_high
quietly bdiff, group(h2_low_rating5_ym) ///
    model(reghdfe ln_RevPAR_clean sim_mean `controls', absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(`bdiff_reps') seed(`seed') nodots first
local p_rating = r(p)
estimates restore t6_rating_high
estadd scalar Fisher_p = `p_rating'
estimates drop t6_rating_high
estimates store t6_rating_high

reghdfe ln_RevPAR_clean_w sim_mean `controls' if h3_low_lag_recent_volumn == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_volume_low
reghdfe ln_RevPAR_clean_w sim_mean `controls' if h3_low_lag_recent_volumn == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_volume_high
quietly bdiff, group(h3_low_lag_recent_volumn) ///
    model(reghdfe ln_RevPAR_clean_w sim_mean `controls', absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(`bdiff_reps') seed(`seed') nodots first
local p_volume = r(p)
estimates restore t6_volume_high
estadd scalar Fisher_p = `p_volume'
estimates drop t6_volume_high
estimates store t6_volume_high

reghdfe ln_RevPAR_clean_w sim_mean `controls' if h4_low_star4 == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_star_low
reghdfe ln_RevPAR_clean_w sim_mean `controls' if h4_low_star4 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t6_star_high
quietly bdiff, group(h4_low_star4) ///
    model(reghdfe ln_RevPAR_clean_w sim_mean `controls', absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(`bdiff_reps') seed(`seed') nodots first
local p_star = r(p)
estimates restore t6_star_high
estadd scalar Fisher_p = `p_star'
estimates drop t6_star_high
estimates store t6_star_high

esttab t6_rating_low t6_rating_high t6_volume_low t6_volume_high t6_star_low t6_star_high ///
    using "`rtf'", append rtf order(sim_mean `controls') ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a Fisher_p, labels("Observations" "Adjusted R-squared" "Fisher p-value") ///
        fmt(%12.0fc %9.3f %9.3f)) ///
    mtitles("Rating low" "Rating high" "Recent volume low" "Recent volume high" "<=4 stars" ">4 stars") ///
    label nogap compress ///
    title("Table 6. Grouped moderating effects; rating_last_5 removed from RHS")

************************************************************
* Table 6-2. Accumulated rating, volume, SD, and chain groups
************************************************************

reghdfe ln_RevPAR_clean_w199 sim_mean `controls_wlag' if h2_low_lag_avg_rating_acc == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_ra_low
reghdfe ln_RevPAR_clean_w199 sim_mean `controls_wlag' if h2_low_lag_avg_rating_acc == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_ra_high
quietly bdiff, group(h2_low_lag_avg_rating_acc) ///
    model(reghdfe ln_RevPAR_clean_w199 sim_mean `controls_wlag', absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(`bdiff_reps') seed(`seed') nodots first
local p_ra = r(p)
estimates restore t62_ra_high
estadd scalar Fisher_p = `p_ra'
estimates drop t62_ra_high
estimates store t62_ra_high

reghdfe ln_RevPAR_clean_w sim_mean `controls' if h3_low_ln_lag_volumn_acc == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_va_low
reghdfe ln_RevPAR_clean_w sim_mean `controls' if h3_low_ln_lag_volumn_acc == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_va_high
quietly bdiff, group(h3_low_ln_lag_volumn_acc) ///
    model(reghdfe ln_RevPAR_clean_w sim_mean `controls', absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(`bdiff_reps') seed(`seed') nodots first
local p_va = r(p)
estimates restore t62_va_high
estadd scalar Fisher_p = `p_va'
estimates drop t62_va_high
estimates store t62_va_high

reghdfe ln_RevPAR_clean_w sim_mean `controls_wlag' if h5_low_lag_sd_acc == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_sd_low
reghdfe ln_RevPAR_clean_w sim_mean `controls_wlag' if h5_low_lag_sd_acc == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_sd_high
quietly bdiff, group(h5_low_lag_sd_acc) ///
    model(reghdfe ln_RevPAR_clean_w sim_mean `controls_wlag', absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(`bdiff_reps') seed(`seed') nodots first
local p_sd = r(p)
estimates restore t62_sd_high
estadd scalar Fisher_p = `p_sd'
estimates drop t62_sd_high
estimates store t62_sd_high

* The historical core panel was overwritten after 2026-05-21 and no
* longer contains the chain merge. The current enriched panel retains
* the same core observations plus chain_raw and chain_matched. The
* document's N=3,780/23,921 split corresponds to chain_raw, not to the
* later convention that codes unmatched hotels as independent.
preserve
use "`data_chain'", clear
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
keep if cs_sample_focus100 == 1
label variable recent_rating_10 "Recent rating i,t-1 (10-review window)"
gen double ln_RevPAR_clean_w = ln_RevPAR_clean
winsor2 ln_RevPAR_clean_w if cs_sample_focus50 == 1, cut(2.5 97.5) replace

reghdfe ln_RevPAR_clean_w sim_mean `controls' if chain_raw == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_independent
reghdfe ln_RevPAR_clean_w sim_mean `controls' if chain_raw == 1, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t62_chain
quietly bdiff, group(chain_raw) ///
    model(reghdfe ln_RevPAR_clean_w sim_mean `controls', absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
    reps(`bdiff_reps') seed(`seed') nodots first
local p_chain = r(p)
estimates restore t62_chain
estadd scalar Fisher_p = `p_chain'
estimates drop t62_chain
estimates store t62_chain
restore

esttab t62_ra_low t62_ra_high t62_va_low t62_va_high t62_sd_low t62_sd_high ///
    t62_independent t62_chain using "`rtf'", append rtf ///
    order(sim_mean `controls_wlag') cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a Fisher_p, labels("Observations" "Adjusted R-squared" "Fisher p-value") ///
        fmt(%12.0fc %9.3f %9.3f)) ///
    mtitles("Rating acc. low" "Rating acc. high" "Volume acc. low" "Volume acc. high" ///
        "SD acc. low" "SD acc. high" "Independent" "Chain") ///
    label nogap compress ///
    title("Table 6-2. Additional grouped moderating effects; rating_last_5 removed")

************************************************************
* Table 7. Interaction-form moderation
************************************************************

reghdfe ln_RevPAR_clean c.sim_mean##i.h2_low_rating5_ym `controls', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t7_rating

reghdfe ln_RevPAR_clean c.sim_mean##i.h3_low_lag_recent_volumn `controls' ///
    if !missing(h3_low_lag_recent_volumn), ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t7_volume

reghdfe ln_RevPAR_clean_w c.sim_mean##i.h4_low_star4 `controls', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t7_star

esttab t7_rating t7_volume t7_star using "`rtf'", append rtf ///
    order(sim_mean 1.h2_low_rating5_ym 1.h2_low_rating5_ym#c.sim_mean ///
        1.h3_low_lag_recent_volumn 1.h3_low_lag_recent_volumn#c.sim_mean ///
        1.h4_low_star4 1.h4_low_star4#c.sim_mean `controls') ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("Recent rating" "Recent volume" "Hotel star") ///
    label nogap compress ///
    title("Table 7. Interaction-form moderating effects; rating_last_5 removed from RHS")

************************************************************
* Table 8. COVID-19 effects
************************************************************

capture drop covid2020 covid2020_2022
gen byte covid2020 = Year == 2020
gen byte covid2020_2022 = inrange(Year, 2020, 2022)

reghdfe ln_RevPAR_clean sim_mean `controls_wlag' if covid2020_2022 == 0, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_pre2020

reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020 `controls_wlag', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_2020

reghdfe ln_RevPAR_clean c.sim_mean##i.covid2020_2022 `controls_wlag', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_pandemic

reghdfe d_ln_RevPAR c.sim_mean##i.covid2020_2022 `controls_wlag', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t8_growth

esttab t8_pre2020 t8_2020 t8_pandemic t8_growth using "`rtf'", append rtf ///
    order(sim_mean 1.covid2020#c.sim_mean 1.covid2020_2022#c.sim_mean `controls_wlag') ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("Before 2020" "2020 shock" "2020-2022 shock" "2020-2022 growth") ///
    label nogap compress ///
    title("Table 8. COVID-19 effects; rating_last_5 removed")

************************************************************
* Table 9. Alternative ARS measurements
************************************************************

preserve
use "`data_alt'", clear
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
keep if cs_sample_focus100 == 1
merge 1:1 HotelID year_month using `recent_rating10_lookup'
assert _merge == 3
drop _merge
label variable recent_rating_10 "Recent rating i,t-1 (10-review window)"

reghdfe ln_RevPAR_clean lag_sim_mean `controls', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t9_lag
reghdfe ln_RevPAR_clean ars_roll_10 `controls', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t9_roll
reghdfe ln_RevPAR_clean ars_jsd_sim `controls', ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t9_jsd
restore

esttab t9_lag t9_roll t9_jsd using "`rtf'", append rtf ///
    order(lag_sim_mean ars_roll_10 ars_jsd_sim `controls') ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("ARS lag" "ARS roll" "ARS JSD") ///
    label nogap compress ///
    title("Table 9. Alternative ARS measurements; rating_last_5 removed")

************************************************************
* Table 10. Alternative review scopes
************************************************************

preserve
use "`data_scope'", clear
capture confirm numeric variable HotelID
if _rc encode HotelID, gen(hotel_id_num)
else gen long hotel_id_num = HotelID
gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym
keep if cs_sample_focus100 == 1
foreach s in 5 10 15 20 30 {
    label variable sim_mean_`s' "ARS i,t (`s'-review window)"
    label variable ln_recent_volumn_`s' "Recent volume i,t (`s'-review window)"
    label variable recent_sd_`s' "Recent SD i,t (`s'-review window)"
    label variable recent_rating_`s' "Recent rating i,t-1 (`s'-review window)"
}

reghdfe ln_RevPAR_clean sim_mean_5 ln_recent_volumn_5 recent_sd_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc recent_rating_5 ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_s5

reghdfe ln_RevPAR_clean sim_mean ln_recent_volumn recent_sd ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc recent_rating_10 ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_s10

reghdfe ln_RevPAR_clean sim_mean_15 ln_recent_volumn_15 recent_sd_15 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc recent_rating_15 ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_s15

reghdfe ln_RevPAR_clean sim_mean_20 ln_recent_volumn_20 recent_sd_20 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc recent_rating_20 ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_s20

reghdfe ln_RevPAR_clean sim_mean_30 ln_recent_volumn_30 recent_sd_30 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc recent_rating_30 ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store t10_s30
restore

esttab t10_s5 t10_s10 t10_s15 t10_s20 t10_s30 using "`rtf'", append rtf ///
    order(sim_mean_5 sim_mean sim_mean_15 sim_mean_20 sim_mean_30 ///
        ln_recent_volumn_5 ln_recent_volumn ln_recent_volumn_15 ///
        ln_recent_volumn_20 ln_recent_volumn_30 ///
        recent_sd_5 recent_sd recent_sd_15 recent_sd_20 recent_sd_30 ///
        recent_rating_5 recent_rating_10 recent_rating_15 recent_rating_20 recent_rating_30 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR ln_lag_RevPAR_clean) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared") fmt(%12.0fc %9.3f)) ///
    mtitles("5" "10" "15" "20" "30") ///
    varlabels(sim_mean_5 "ARS i,t (5-review window)" ///
        sim_mean "ARS i,t (10-review window)" ///
        sim_mean_15 "ARS i,t (15-review window)" ///
        sim_mean_20 "ARS i,t (20-review window)" ///
        sim_mean_30 "ARS i,t (30-review window)" ///
        ln_recent_volumn_5 "Recent volume i,t (5-review window)" ///
        ln_recent_volumn "Recent volume i,t (10-review window)" ///
        ln_recent_volumn_15 "Recent volume i,t (15-review window)" ///
        ln_recent_volumn_20 "Recent volume i,t (20-review window)" ///
        ln_recent_volumn_30 "Recent volume i,t (30-review window)" ///
        recent_sd_5 "Recent SD i,t (5-review window)" ///
        recent_sd "Recent SD i,t (10-review window)" ///
        recent_sd_15 "Recent SD i,t (15-review window)" ///
        recent_sd_20 "Recent SD i,t (20-review window)" ///
        recent_sd_30 "Recent SD i,t (30-review window)" ///
        recent_rating_5 "Recent rating i,t-1 (5-review window)" ///
        recent_rating_10 "Recent rating i,t-1 (10-review window)" ///
        recent_rating_15 "Recent rating i,t-1 (15-review window)" ///
        recent_rating_20 "Recent rating i,t-1 (20-review window)" ///
        recent_rating_30 "Recent rating i,t-1 (30-review window)" ///
        ln_lag_volumn_acc "Review volume i,t-1" ///
        lag_avg_rating_acc "Rating acc. i,t-1" ///
        lag_sd_acc "Rating SD acc. i,t-1" ///
        ln_avg_com_RevPAR "Competitor RevPAR i,t" ///
        ln_lag_RevPAR_clean "RevPAR i,t-1") ///
    label nogap compress ///
    title("Table 10. Alternative review scopes; rating_last_5 removed")

display as result "Completed. The only result file is: `rtf'"
************************************************************
* End
************************************************************
