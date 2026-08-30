************************************************************
* Exploratory mediation: ARS -> average helpfulness -> RevPAR
* M uses the exact Scope-10 review pool underlying sim_mean.
************************************************************

version 17.0
clear all
set more off
set linesize 255

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local outdir "`project'/outputs/paper/rtf-0826"
local rtf "`outdir'/routeAB_helpfulness_mediation_260826.rtf"
local summary_csv "`outdir'/routeAB_helpfulness_mediation_260826.csv"

capture mkdir "`outdir'"
capture confirm file "`data'"
if _rc exit 601
foreach cmd in reghdfe winsor2 esttab {
    capture which `cmd'
    if _rc exit 199
}

use "`data'", clear
keep if cs_sample_focus100 == 1

capture confirm variable hotel_id_num
if _rc {
    capture confirm numeric variable HotelID
    if _rc encode HotelID, gen(hotel_id_num)
    else gen long hotel_id_num = HotelID
}
capture confirm variable ym
if _rc gen int ym = monthly(year_month, "YM")
format ym %tm
sort hotel_id_num ym

foreach cut in 199 195 595 {
    local low = substr("`cut'", 1, 1)
    local high = substr("`cut'", 2, 2)
    capture confirm variable ln_RevPAR_clean_w`cut'
    if _rc winsor2 ln_RevPAR_clean, cuts(`low' `high') suffix(_w`cut')
    capture confirm variable ln_lag_RevPAR_clean_w`cut'
    if _rc winsor2 ln_lag_RevPAR_clean, cuts(`low' `high') suffix(_w`cut')
}

capture confirm variable avg_helpfulness_scope10_w199
if _rc winsor2 avg_helpfulness_scope10, cuts(1 99) suffix(_w199)
capture drop scope10_avg_review_age_years
gen double scope10_avg_review_age_years = scope10_avg_review_age_days / 365.25

label variable sim_mean "ARS"
label variable ln_avg_helpfulness_scope10 "ln(1 + average helpful votes)"
label variable avg_helpfulness_scope10_w199 "Average helpful votes, w199"
label variable scope10_avg_review_age_years "Average review age, years"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating"
label variable lag_sd_acc "Accumulated rating SD"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"

local controls "recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR scope10_avg_review_age_years"

capture program drop med_indirect
program define med_indirect, rclass
    syntax, YVAR(name) LVAR(name) MVAR(name) SAMPLE(name)
    local panel_id hotel_id_num
    capture confirm variable boot_hotel
    if !_rc local panel_id boot_hotel

    quietly reghdfe `mvar' sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        scope10_avg_review_age_years `lvar' if `sample', ///
        absorb(`panel_id' ym)
    scalar a_path = _b[sim_mean]

    quietly reghdfe `yvar' sim_mean `mvar' ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        scope10_avg_review_age_years `lvar' if `sample', ///
        absorb(`panel_id' ym)
    return scalar indirect = a_path * _b[`mvar']
end

tempname results
tempfile summary_results
postfile `results' str18 specification str20 path double b se p N ///
    using "`summary_results'", replace

local specs "primary matched195 matched595 raw_w199"
local write_mode "replace"
local seed 260826

foreach spec of local specs {
    if "`spec'" == "primary" {
        local yvar "ln_RevPAR_clean_w199"
        local lvar "ln_lag_RevPAR_clean_w595"
        local mvar "ln_avg_helpfulness_scope10"
        local title "Primary: Y w199, lagged Y w595, log helpfulness"
        local reps 500
    }
    else if "`spec'" == "matched195" {
        local yvar "ln_RevPAR_clean_w195"
        local lvar "ln_lag_RevPAR_clean_w195"
        local mvar "ln_avg_helpfulness_scope10"
        local title "Robustness: Y w195, lagged Y w195, log helpfulness"
        local reps 200
    }
    else if "`spec'" == "matched595" {
        local yvar "ln_RevPAR_clean_w595"
        local lvar "ln_lag_RevPAR_clean_w595"
        local mvar "ln_avg_helpfulness_scope10"
        local title "Robustness: Y w595, lagged Y w595, log helpfulness"
        local reps 200
    }
    else {
        local yvar "ln_RevPAR_clean_w199"
        local lvar "ln_lag_RevPAR_clean_w595"
        local mvar "avg_helpfulness_scope10_w199"
        local title "Robustness: Y w199, lagged Y w595, raw helpfulness w199"
        local reps 200
    }

    capture drop med_cc
    egen byte med_missing = rowmiss(`yvar' sim_mean `mvar' `controls' `lvar')
    gen byte med_cc = (med_missing == 0)
    drop med_missing

    quietly reghdfe `mvar' sim_mean `controls' `lvar' if med_cc, ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store a_`spec'
    scalar a_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
    post `results' ("`spec'") ("a: X -> M") ///
        (_b[sim_mean]) (_se[sim_mean]) (a_p) (e(N))

    quietly reghdfe `yvar' sim_mean `controls' `lvar' if med_cc, ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store total_`spec'
    scalar c_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
    post `results' ("`spec'") ("c: total X") ///
        (_b[sim_mean]) (_se[sim_mean]) (c_p) (e(N))

    quietly reghdfe `yvar' sim_mean `mvar' `controls' `lvar' if med_cc, ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store direct_`spec'
    scalar cp_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
    post `results' ("`spec'") ("cprime: direct") ///
        (_b[sim_mean]) (_se[sim_mean]) (cp_p) (e(N))
    scalar b_p = 2 * ttail(e(df_r), abs(_b[`mvar'] / _se[`mvar']))
    post `results' ("`spec'") ("b: M -> Y") ///
        (_b[`mvar']) (_se[`mvar']) (b_p) (e(N))

    esttab a_`spec' total_`spec' direct_`spec' using "`rtf'", ///
        `write_mode' rtf ///
        keep(sim_mean `mvar' `controls' `lvar') ///
        order(sim_mean `mvar' `controls' `lvar') ///
        mtitles("M equation" "Y: total effect" "Y: X and M") ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        stats(N N_clust r2_a, ///
            labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
            fmt(%12.0fc %12.0fc %9.3f)) ///
        title("`title'") ///
        addnotes("M is computed from the exact review pool underlying ARS." ///
            "Hotel and calendar-month fixed effects are included; standard errors are clustered by hotel.") ///
        label nogap compress
    local write_mode "append"

    capture drop boot_hotel
    bootstrap indirect=r(indirect), reps(`reps') seed(`seed') ///
        cluster(hotel_id_num) idcluster(boot_hotel) nodots: ///
        med_indirect, yvar(`yvar') lvar(`lvar') mvar(`mvar') sample(med_cc)
    estimates store indirect_`spec'
    scalar ind_p = 2 * normal(-abs(_b[indirect] / _se[indirect]))
    post `results' ("`spec'") ("indirect a*b") ///
        (_b[indirect]) (_se[indirect]) (ind_p) (e(N))

    local seed = `seed' + 1
}

esttab indirect_primary indirect_matched195 indirect_matched595 ///
    indirect_raw_w199 using "`rtf'", append rtf ///
    keep(indirect) ///
    mtitles("Primary" "Matched w195" "Matched w595" "Raw M, w199") ///
    cells(b(star fmt(5)) se(par fmt(5))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    title("Cluster-bootstrap indirect effects") ///
    addnotes("Primary uses 500 hotel-cluster bootstrap replications; robustness specifications use 200." ///
        "The indirect effect is the product of the ARS-to-helpfulness and helpfulness-to-Revenue coefficients.") ///
    nogap compress

postclose `results'
use "`summary_results'", clear
export delimited using "`summary_csv'", replace
