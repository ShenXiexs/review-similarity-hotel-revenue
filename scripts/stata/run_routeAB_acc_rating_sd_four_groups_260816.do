************************************************************
* Route A/B: accumulated-rating x accumulated-rating-SD
* four-group heterogeneity analysis.
*
* Input: routeAB_heterogeneity_final_260715.dta
* Groups: CityID x month medians on the common complete-case sample.
* Models: hotel FE + month FE; SE clustered by hotel.
* Robustness: 3 x 3 combinations of winsorized current and lagged RevPAR.
************************************************************

version 17.0
clear all
set more off
set linesize 255

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local input   "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local outdir  "`project'/outputs/core_simi_260501/research/results"

capture mkdir "`project'/outputs/core_simi_260501/research"
capture mkdir "`outdir'"

capture log close _all
log using "`outdir'/routeAB_acc_rating_sd_four_groups_260816.log", replace text name(fourgroups)

use "`input'", clear

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
sort hotel_id_num ym

************************************************************
* 1. Construct the requested global winsorized variants.
************************************************************

capture confirm variable ln_RevPAR_clean_w199
if _rc winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
capture confirm variable ln_lag_RevPAR_clean_w199
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 99) suffix(_w199)

capture confirm variable ln_RevPAR_clean_w195
if _rc winsor2 ln_RevPAR_clean, cuts(1 95) suffix(_w195)
capture confirm variable ln_lag_RevPAR_clean_w195
if _rc winsor2 ln_lag_RevPAR_clean, cuts(1 95) suffix(_w195)

capture confirm variable ln_RevPAR_clean_w595
if _rc winsor2 ln_RevPAR_clean, cuts(5 95) suffix(_w595)
capture confirm variable ln_lag_RevPAR_clean_w595
if _rc winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

label variable ln_RevPAR_clean_w199 "ln(RevPAR), winsorized 1-99"
label variable ln_lag_RevPAR_clean_w199 "Lagged ln(RevPAR), winsorized 1-99"
label variable ln_RevPAR_clean_w195 "ln(RevPAR), winsorized 1-95"
label variable ln_lag_RevPAR_clean_w195 "Lagged ln(RevPAR), winsorized 1-95"
label variable ln_RevPAR_clean_w595 "ln(RevPAR), winsorized 5-95"
label variable ln_lag_RevPAR_clean_w595 "Lagged ln(RevPAR), winsorized 5-95"

************************************************************
* 2. Rebuild the common sample and CityID x ym median groups.
* Low is strictly below the median; high includes median ties.
************************************************************

capture drop het_missing_four het_base_cc_four
egen byte het_missing_four = rowmiss(ln_RevPAR_clean_w199 sim_mean ///
    recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
    ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
    ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199)
gen byte het_base_cc_four = (het_missing_four == 0)
label variable het_base_cc_four "Four-group common complete-case sample"

capture drop het_med_acc_rating_four het_med_acc_sd_four
capture drop het_high_acc_rating_four het_high_acc_sd_four
capture drop het_acc_rating_sd_g4

bysort CityID ym: egen double het_med_acc_rating_four = ///
    median(lag_avg_rating_acc) if het_base_cc_four == 1
bysort CityID ym: egen double het_med_acc_sd_four = ///
    median(lag_sd_acc) if het_base_cc_four == 1

gen byte het_high_acc_rating_four = .
replace het_high_acc_rating_four = 0 if het_base_cc_four == 1 & ///
    lag_avg_rating_acc < het_med_acc_rating_four
replace het_high_acc_rating_four = 1 if het_base_cc_four == 1 & ///
    lag_avg_rating_acc >= het_med_acc_rating_four

gen byte het_high_acc_sd_four = .
replace het_high_acc_sd_four = 0 if het_base_cc_four == 1 & ///
    lag_sd_acc < het_med_acc_sd_four
replace het_high_acc_sd_four = 1 if het_base_cc_four == 1 & ///
    lag_sd_acc >= het_med_acc_sd_four

gen byte het_acc_rating_sd_g4 = .
replace het_acc_rating_sd_g4 = 1 if het_high_acc_rating_four == 0 & het_high_acc_sd_four == 0
replace het_acc_rating_sd_g4 = 2 if het_high_acc_rating_four == 0 & het_high_acc_sd_four == 1
replace het_acc_rating_sd_g4 = 3 if het_high_acc_rating_four == 1 & het_high_acc_sd_four == 0
replace het_acc_rating_sd_g4 = 4 if het_high_acc_rating_four == 1 & het_high_acc_sd_four == 1

label define acc_rating_sd_g4 ///
    1 "Low accumulated rating / Low accumulated SD" ///
    2 "Low accumulated rating / High accumulated SD" ///
    3 "High accumulated rating / Low accumulated SD" ///
    4 "High accumulated rating / High accumulated SD", replace
label values het_acc_rating_sd_g4 acc_rating_sd_g4
label variable het_acc_rating_sd_g4 "Accumulated rating x accumulated rating SD (four groups)"

label variable sim_mean "ARS"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable lag_avg_rating_month "Recent rating"
label variable rating_last_5 "Rating of last 5 reviews"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating"
label variable lag_sd_acc "Accumulated rating SD"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"

tab het_acc_rating_sd_g4 if het_base_cc_four == 1, missing

* Export group sample sizes and distinct hotel counts.
preserve
keep if het_base_cc_four == 1 & !missing(het_acc_rating_sd_g4)
bysort het_acc_rating_sd_g4 hotel_id_num: gen byte hotel_tag_four = (_n == 1)
collapse (count) observations=hotel_id_num (sum) hotels=hotel_tag_four, by(het_acc_rating_sd_g4)
decode het_acc_rating_sd_g4, gen(group_label)
order het_acc_rating_sd_g4 group_label observations hotels
export delimited using "`outdir'/routeAB_acc_rating_sd_four_group_counts_260816.csv", replace nolabel
restore

* Save a derived analysis panel; the 260715 source file is not overwritten.
compress
save "`outdir'/routeAB_acc_rating_sd_four_groups_panel_260816.dta", replace

************************************************************
* 3. Separate four-group regressions for all 3 x 3 variants.
************************************************************

local controls "recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR"
local cuts "199 195 595"

estimates clear
tempname regpost
postfile `regpost' str3 outcome_cut str3 lag_cut byte group ///
    double b_sim se_sim p_sim N N_clust r2_a ///
    using "`outdir'/routeAB_acc_rating_sd_four_groups_results_260816.dta", replace

foreach ycut of local cuts {
    foreach lcut of local cuts {
        local depvar "ln_RevPAR_clean_w`ycut'"
        local lagvar "ln_lag_RevPAR_clean_w`lcut'"

        forvalues g = 1/4 {
            quietly reghdfe `depvar' sim_mean `controls' `lagvar' ///
                if het_base_cc_four == 1 & het_acc_rating_sd_g4 == `g', ///
                absorb(hotel_id_num ym) vce(cluster hotel_id_num)

            estimates store m_`ycut'_`lcut'_g`g'

            scalar b_four  = _b[sim_mean]
            scalar se_four = _se[sim_mean]
            scalar p_four  = 2 * ttail(e(df_r), abs(b_four / se_four))
            scalar n_four  = e(N)
            capture scalar nc_four = e(N_clust)
            if _rc scalar nc_four = .
            scalar r2a_four = e(r2_a)

            post `regpost' ("`ycut'") ("`lcut'") (`g') ///
                (b_four) (se_four) (p_four) (n_four) (nc_four) (r2a_four)
        }
    }
}
postclose `regpost'

preserve
use "`outdir'/routeAB_acc_rating_sd_four_groups_results_260816.dta", clear
label define acc_rating_sd_g4 ///
    1 "Low accumulated rating / Low accumulated SD" ///
    2 "Low accumulated rating / High accumulated SD" ///
    3 "High accumulated rating / Low accumulated SD" ///
    4 "High accumulated rating / High accumulated SD", replace
label values group acc_rating_sd_g4
decode group, gen(group_label)
order outcome_cut lag_cut group group_label b_sim se_sim p_sim N N_clust r2_a
sort outcome_cut lag_cut group
save "`outdir'/routeAB_acc_rating_sd_four_groups_results_260816.dta", replace
export delimited using "`outdir'/routeAB_acc_rating_sd_four_groups_results_260816.csv", replace nolabel
restore

************************************************************
* 4. RTF tables.
************************************************************

* User-requested reference specification: outcome w199, lagged outcome w595.
esttab m_199_595_g1 m_199_595_g2 m_199_595_g3 m_199_595_g4 ///
    using "`outdir'/routeAB_acc_rating_sd_four_groups_main_w199_lagw595_260816.rtf", ///
    replace rtf ///
    mtitles("Low rating / Low SD" "Low rating / High SD" ///
        "High rating / Low SD" "High rating / High SD") ///
    order(sim_mean `controls' ln_lag_RevPAR_clean_w595) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N N_clust r2_a, ///
        labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
        fmt(%12.0fc %12.0fc %9.3f)) ///
    title("Accumulated Rating x Accumulated Rating SD: Four Groups") ///
    label nogap compress

* Compact matched-cut robustness table; report only the ARS coefficient.
esttab m_199_199_g1 m_199_199_g2 m_199_199_g3 m_199_199_g4 ///
       m_195_195_g1 m_195_195_g2 m_195_195_g3 m_195_195_g4 ///
       m_595_595_g1 m_595_595_g2 m_595_595_g3 m_595_595_g4 ///
    using "`outdir'/routeAB_acc_rating_sd_four_groups_matched_winsor_260816.rtf", ///
    replace rtf keep(sim_mean) ///
    mtitles("199 LL" "199 LH" "199 HL" "199 HH" ///
        "195 LL" "195 LH" "195 HL" "195 HH" ///
        "595 LL" "595 LH" "595 HL" "595 HH") ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N N_clust r2_a, ///
        labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
        fmt(%12.0fc %12.0fc %9.3f)) ///
    title("ARS Coefficients Across Matched Winsorization Specifications") ///
    label nogap compress

************************************************************
* 5. Pooled interaction tests of the four economically relevant
*    pairwise differences in ARS slopes, for all 3 x 3 variants.
*    These complement separate regressions and do not depend on bdiff.
************************************************************

tempname diffpost
postfile `diffpost' str3 outcome_cut str3 lag_cut str34 contrast ///
    double b_diff se_diff p_diff N N_clust ///
    using "`outdir'/routeAB_acc_rating_sd_four_groups_differences_260816.dta", replace

foreach ycut of local cuts {
    foreach lcut of local cuts {
        local depvar "ln_RevPAR_clean_w`ycut'"
        local lagvar "ln_lag_RevPAR_clean_w`lcut'"

        quietly reghdfe `depvar' c.sim_mean##ib1.het_acc_rating_sd_g4 ///
            `controls' `lagvar' if het_base_cc_four == 1, ///
            absorb(hotel_id_num ym) vce(cluster hotel_id_num)

        scalar pooled_n = e(N)
        capture scalar pooled_nc = e(N_clust)
        if _rc scalar pooled_nc = .

        * High SD minus low SD among low-rating observations: G2 - G1.
        quietly lincom 2.het_acc_rating_sd_g4#c.sim_mean
        post `diffpost' ("`ycut'") ("`lcut'") ("SD effect | low rating: G2-G1") ///
            (r(estimate)) (r(se)) (r(p)) (pooled_n) (pooled_nc)

        * High SD minus low SD among high-rating observations: G4 - G3.
        quietly lincom 4.het_acc_rating_sd_g4#c.sim_mean - ///
            3.het_acc_rating_sd_g4#c.sim_mean
        post `diffpost' ("`ycut'") ("`lcut'") ("SD effect | high rating: G4-G3") ///
            (r(estimate)) (r(se)) (r(p)) (pooled_n) (pooled_nc)

        * High rating minus low rating among low-SD observations: G3 - G1.
        quietly lincom 3.het_acc_rating_sd_g4#c.sim_mean
        post `diffpost' ("`ycut'") ("`lcut'") ("Rating effect | low SD: G3-G1") ///
            (r(estimate)) (r(se)) (r(p)) (pooled_n) (pooled_nc)

        * High rating minus low rating among high-SD observations: G4 - G2.
        quietly lincom 4.het_acc_rating_sd_g4#c.sim_mean - ///
            2.het_acc_rating_sd_g4#c.sim_mean
        post `diffpost' ("`ycut'") ("`lcut'") ("Rating effect | high SD: G4-G2") ///
            (r(estimate)) (r(se)) (r(p)) (pooled_n) (pooled_nc)
    }
}
postclose `diffpost'

preserve
use "`outdir'/routeAB_acc_rating_sd_four_groups_differences_260816.dta", clear
sort outcome_cut lag_cut contrast
save "`outdir'/routeAB_acc_rating_sd_four_groups_differences_260816.dta", replace
export delimited using "`outdir'/routeAB_acc_rating_sd_four_groups_differences_260816.csv", replace
restore

************************************************************
* 6. Attempt bdiff for the four key pairwise comparisons in
*    the user's reference specification (w199 outcome / w595 lag).
*    Output is retained in the text log because bdiff is an add-on.
************************************************************

capture which bdiff
if !_rc {
    capture program drop run_bdiff_four_pair
    program define run_bdiff_four_pair, rclass
        syntax, LOW(integer) HIGH(integer) SEED(integer)
        preserve
        keep if inlist(het_acc_rating_sd_g4, `low', `high') & het_base_cc_four == 1
        gen byte bdiff_four_group = (het_acc_rating_sd_g4 == `high')
        noisily bdiff, group(bdiff_four_group) ///
            model(reghdfe ln_RevPAR_clean_w199 sim_mean ///
                recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
                ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
                ln_avg_com_RevPAR ln_lag_RevPAR_clean_w595, ///
                absorb(hotel_id_num ym) cluster(hotel_id_num)) ///
            reps(100) seed(`seed') first
        local pair_bdiff = r(bdiff)
        local pair_p = r(p)
        restore
        return scalar bdiff = `pair_bdiff'
        return scalar p = `pair_p'
    end

    tempname bdiffpost
    postfile `bdiffpost' str34 contrast double b0_minus_b1 p_permutation ///
        using "`outdir'/routeAB_acc_rating_sd_four_groups_bdiff_260816.dta", replace

    di as text "BDIFF: G2 versus G1 (SD difference within low rating)"
    capture noisily run_bdiff_four_pair, low(1) high(2) seed(2608161)
    if !_rc post `bdiffpost' ("SD effect | low rating: G1-G2") (r(bdiff)) (r(p))
    di as text "BDIFF: G4 versus G3 (SD difference within high rating)"
    capture noisily run_bdiff_four_pair, low(3) high(4) seed(2608162)
    if !_rc post `bdiffpost' ("SD effect | high rating: G3-G4") (r(bdiff)) (r(p))
    di as text "BDIFF: G3 versus G1 (rating difference within low SD)"
    capture noisily run_bdiff_four_pair, low(1) high(3) seed(2608163)
    if !_rc post `bdiffpost' ("Rating effect | low SD: G1-G3") (r(bdiff)) (r(p))
    di as text "BDIFF: G4 versus G2 (rating difference within high SD)"
    capture noisily run_bdiff_four_pair, low(2) high(4) seed(2608164)
    if !_rc post `bdiffpost' ("Rating effect | high SD: G2-G4") (r(bdiff)) (r(p))

    postclose `bdiffpost'
    preserve
    use "`outdir'/routeAB_acc_rating_sd_four_groups_bdiff_260816.dta", clear
    export delimited using "`outdir'/routeAB_acc_rating_sd_four_groups_bdiff_260816.csv", replace
    restore
}
else {
    di as error "bdiff is not installed; pooled interaction difference tests were completed instead."
}

di as result "Four-group analysis completed."
log close fourgroups
