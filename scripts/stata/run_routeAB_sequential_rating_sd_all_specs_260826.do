************************************************************
* Sequential four-group regressions:
* A. Rating first, then rating SD within rating group.
* B. Rating SD first, then rating within rating-SD group.
* All 3 x 3 outcome/lagged-outcome winsor combinations.
************************************************************

version 17.0
clear all
set more off
set linesize 255

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local outdir "`project'/outputs/paper/rtf-0826"
local rtf "`outdir'/routeAB_sequential_rating_sd_all_specs_260826.rtf"
local summary_csv "`outdir'/routeAB_sequential_rating_sd_all_specs_260826.csv"

capture mkdir "`outdir'"
capture confirm file "`data'"
if _rc exit 601
foreach cmd in reghdfe winsor2 esttab {
    capture which `cmd'
    if _rc exit 199
}

use "`data'", clear
keep if revtot_final >= 100

capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
capture confirm variable ym
if _rc gen int ym = monthly(year_month, "YM")
format ym %tm
xtset hotel_id_num ym

label variable sim_mean "ARS"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating"
label variable lag_sd_acc "Accumulated rating SD"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"

foreach cut in 199 195 595 {
    local low = substr("`cut'", 1, 1)
    local high = substr("`cut'", 2, 2)
    capture confirm variable ln_RevPAR_clean_w`cut'
    if _rc winsor2 ln_RevPAR_clean, cuts(`low' `high') suffix(_w`cut')
    capture confirm variable ln_lag_RevPAR_clean_w`cut'
    if _rc winsor2 ln_lag_RevPAR_clean, cuts(`low' `high') suffix(_w`cut')
    label variable ln_lag_RevPAR_clean_w`cut' "Lagged ln(RevPAR), w`cut'"
}

local controls "recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR"

capture drop seq_missing seq_base_cc
egen byte seq_missing = rowmiss(ln_RevPAR_clean sim_mean `controls' ln_lag_RevPAR_clean)
gen byte seq_base_cc = (seq_missing == 0)

************************************************************
* Order A: rating first; SD split within rating group.
************************************************************

capture drop rs_med_rating rs_high_rating rs_med_sd rs_high_sd rs_group
bysort CityID ym: egen double rs_med_rating = median(lag_avg_rating_acc) if seq_base_cc
gen byte rs_high_rating = .
replace rs_high_rating = 0 if lag_avg_rating_acc < rs_med_rating & seq_base_cc
replace rs_high_rating = 1 if lag_avg_rating_acc >= rs_med_rating & seq_base_cc

bysort CityID ym rs_high_rating: egen double rs_med_sd = median(lag_sd_acc) if seq_base_cc
gen byte rs_high_sd = .
replace rs_high_sd = 0 if lag_sd_acc < rs_med_sd & seq_base_cc
replace rs_high_sd = 1 if lag_sd_acc >= rs_med_sd & seq_base_cc

gen byte rs_group = 1 + 2 * rs_high_rating + rs_high_sd if seq_base_cc

************************************************************
* Order B: SD first; rating split within SD group.
************************************************************

capture drop sr_med_sd sr_high_sd sr_med_rating sr_high_rating sr_group
bysort CityID ym: egen double sr_med_sd = median(lag_sd_acc) if seq_base_cc
gen byte sr_high_sd = .
replace sr_high_sd = 0 if lag_sd_acc < sr_med_sd & seq_base_cc
replace sr_high_sd = 1 if lag_sd_acc >= sr_med_sd & seq_base_cc

bysort CityID ym sr_high_sd: egen double sr_med_rating = median(lag_avg_rating_acc) if seq_base_cc
gen byte sr_high_rating = .
replace sr_high_rating = 0 if lag_avg_rating_acc < sr_med_rating & seq_base_cc
replace sr_high_rating = 1 if lag_avg_rating_acc >= sr_med_rating & seq_base_cc

gen byte sr_group = 1 + 2 * sr_high_rating + sr_high_sd if seq_base_cc

label define four_group_lbl ///
    1 "Low rating / Low SD" 2 "Low rating / High SD" ///
    3 "High rating / Low SD" 4 "High rating / High SD", replace
label values rs_group four_group_lbl
label values sr_group four_group_lbl

tempname results
tempfile summary_results
postfile `results' str12 split_order str4 outcome_w str4 lag_w ///
    byte group str24 group_label double b se p N N_clust r2_a ///
    using "`summary_results'", replace

local write_mode "replace"
foreach order in rs sr {
    if "`order'" == "rs" {
        local order_title "Rating first, then SD"
    }
    else {
        local order_title "SD first, then rating"
    }

    foreach ycut in 199 195 595 {
        foreach lcut in 199 195 595 {
            local yvar "ln_RevPAR_clean_w`ycut'"
            local lvar "ln_lag_RevPAR_clean_w`lcut'"

            forvalues group = 1/4 {
                quietly reghdfe `yvar' sim_mean `controls' `lvar' ///
                    if `order'_group == `group', ///
                    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
                estimates store `order'_y`ycut'_l`lcut'_g`group'

                local group_label : label four_group_lbl `group'
                scalar sim_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
                post `results' ("`order'") ("w`ycut'") ("w`lcut'") ///
                    (`group') ("`group_label'") (_b[sim_mean]) (_se[sim_mean]) ///
                    (sim_p) (e(N)) (e(N_clust)) (e(r2_a))
            }

            esttab `order'_y`ycut'_l`lcut'_g1 ///
                `order'_y`ycut'_l`lcut'_g2 ///
                `order'_y`ycut'_l`lcut'_g3 ///
                `order'_y`ycut'_l`lcut'_g4 ///
                using "`rtf'", `write_mode' rtf ///
                keep(sim_mean `controls' `lvar') ///
                order(sim_mean `controls' `lvar') ///
                mtitles("Low rating / Low SD" "Low rating / High SD" ///
                    "High rating / Low SD" "High rating / High SD") ///
                cells(b(star fmt(3)) se(par fmt(3))) ///
                star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
                stats(N N_clust r2_a, ///
                    labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
                    fmt(%12.0fc %12.0fc %9.3f)) ///
                title("`order_title': outcome w`ycut', lagged outcome w`lcut'") ///
                addnotes("Sequential City x month median splits are used." ///
                    "Hotel and calendar-month fixed effects are included; standard errors are clustered by hotel.") ///
                label nogap compress

            local write_mode "append"
        }
    }
}

postclose `results'
use "`summary_results'", clear
sort split_order outcome_w lag_w group
export delimited using "`summary_csv'", replace
