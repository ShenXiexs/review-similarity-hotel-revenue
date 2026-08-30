************************************************************
* Helpfulness scale comparison:
* log1p votes versus unlogged raw average helpful votes.
************************************************************

version 17.0
clear all
set more off
set linesize 255

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local outdir "`project'/outputs/paper/rtf-0826"
local rtf "`outdir'/routeAB_helpfulness_log_vs_raw_260826.rtf"
local csv "`outdir'/routeAB_helpfulness_log_vs_raw_260826.csv"

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

capture confirm variable ln_RevPAR_clean_w199
if _rc winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
capture confirm variable ln_lag_RevPAR_clean_w595
if _rc winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)

capture drop avg_helpfulness_scope10_w199
winsor2 avg_helpfulness_scope10, cuts(1 99) suffix(_w199)
capture drop scope10_avg_review_age_years
gen double scope10_avg_review_age_years = scope10_avg_review_age_days / 365.25

label variable sim_mean "ARS"
label variable avg_helpfulness_scope10 "Average helpful votes, raw"
label variable avg_helpfulness_scope10_w199 "Average helpful votes, raw w199"
label variable ln_avg_helpfulness_scope10 "ln(1 + average helpful votes)"
label variable scope10_avg_review_age_years "Average review age, years"
label variable recent_sd_10 "Recent rating SD"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating"
label variable lag_sd_acc "Accumulated rating SD"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"

local controls "recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR scope10_avg_review_age_years"
local yvar "ln_RevPAR_clean_w199"
local lvar "ln_lag_RevPAR_clean_w595"

egen byte med_missing = rowmiss(`yvar' sim_mean ///
    avg_helpfulness_scope10 ln_avg_helpfulness_scope10 ///
    avg_helpfulness_scope10_w199 `controls' `lvar')
gen byte med_cc = (med_missing == 0)
drop med_missing

tempname results
tempfile summary_results
postfile `results' str16 section str16 specification str24 statistic ///
    double value se p N using "`summary_results'", replace

************************************************************
* Descriptives and correlations on the common sample.
************************************************************

matrix Desc = J(3, 7, .)
matrix rownames Desc = raw_votes log1p_votes raw_votes_w199
matrix colnames Desc = mean sd p50 p95 p99 max zero_share
quietly count if med_cc
scalar common_n = r(N)

local row = 0
foreach mvar in avg_helpfulness_scope10 ln_avg_helpfulness_scope10 ///
    avg_helpfulness_scope10_w199 {
    local ++row
    quietly summarize `mvar' if med_cc, detail
    matrix Desc[`row', 1] = r(mean)
    matrix Desc[`row', 2] = r(sd)
    matrix Desc[`row', 3] = r(p50)
    matrix Desc[`row', 4] = r(p95)
    matrix Desc[`row', 5] = r(p99)
    matrix Desc[`row', 6] = r(max)
    quietly count if `mvar' == 0 & med_cc
    matrix Desc[`row', 7] = r(N) / common_n
}

esttab matrix(Desc, fmt(4)) using "`rtf'", replace rtf ///
    title("Table 1. Helpfulness Distribution on the Common Sample") ///
    nomtitles nonumbers compress

matrix Corr = J(3, 4, .)
matrix rownames Corr = raw_votes log1p_votes raw_votes_w199
matrix colnames Corr = Pearson Spearman Partial N

quietly reghdfe `yvar' sim_mean `controls' `lvar' if med_cc, ///
    absorb(hotel_id_num ym) residuals(y_residual)

local row = 0
local specs "raw log raww199"
foreach spec of local specs {
    local ++row
    if "`spec'" == "raw" local mvar "avg_helpfulness_scope10"
    if "`spec'" == "log" local mvar "ln_avg_helpfulness_scope10"
    if "`spec'" == "raww199" local mvar "avg_helpfulness_scope10_w199"

    quietly correlate `mvar' `yvar' if med_cc
    scalar pearson = r(rho)

    capture drop rank_m rank_y
    egen double rank_m = rank(`mvar') if med_cc
    egen double rank_y = rank(`yvar') if med_cc
    quietly correlate rank_m rank_y if med_cc
    scalar spearman = r(rho)

    capture drop m_residual
    quietly reghdfe `mvar' sim_mean `controls' `lvar' if med_cc, ///
        absorb(hotel_id_num ym) residuals(m_residual)
    quietly correlate m_residual y_residual if med_cc
    scalar partial = r(rho)
    quietly count if med_cc
    scalar corr_n = r(N)

    matrix Corr[`row', 1] = pearson
    matrix Corr[`row', 2] = spearman
    matrix Corr[`row', 3] = partial
    matrix Corr[`row', 4] = corr_n

    post `results' ("correlation") ("`spec'") ("Pearson with ln RevPAR") ///
        (pearson) (.) (.) (corr_n)
    post `results' ("correlation") ("`spec'") ("Spearman with ln RevPAR") ///
        (spearman) (.) (.) (corr_n)
    post `results' ("correlation") ("`spec'") ("Partial correlation") ///
        (partial) (.) (.) (corr_n)
}

esttab matrix(Corr, fmt(4 4 4 0)) using "`rtf'", append rtf ///
    title("Table 2. Helpfulness and ln(RevPAR) Correlations") ///
    addnotes("Pearson and Spearman correlations use the common regression sample." ///
        "Partial correlations remove ARS, controls, hotel fixed effects, and calendar-month fixed effects.") ///
    nomtitles nonumbers compress

************************************************************
* Mediation regressions and cluster-bootstrap indirect effect.
************************************************************

capture program drop helpful_indirect
program define helpful_indirect, rclass
    syntax, MVAR(name) SAMPLE(name)
    local panel_id hotel_id_num
    capture confirm variable boot_hotel
    if !_rc local panel_id boot_hotel

    quietly reghdfe `mvar' sim_mean ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        scope10_avg_review_age_years ln_lag_RevPAR_clean_w595 if `sample', ///
        absorb(`panel_id' ym)
    scalar a_path = _b[sim_mean]

    quietly reghdfe ln_RevPAR_clean_w199 sim_mean `mvar' ///
        recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR ///
        scope10_avg_review_age_years ln_lag_RevPAR_clean_w595 if `sample', ///
        absorb(`panel_id' ym)
    return scalar indirect = a_path * _b[`mvar']
end

quietly reghdfe `yvar' sim_mean `controls' `lvar' if med_cc, ///
    absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store total
scalar total_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
post `results' ("mediation") ("common") ("c: total X") ///
    (_b[sim_mean]) (_se[sim_mean]) (total_p) (e(N))

local seed 260826
foreach spec of local specs {
    if "`spec'" == "raw" local mvar "avg_helpfulness_scope10"
    if "`spec'" == "log" local mvar "ln_avg_helpfulness_scope10"
    if "`spec'" == "raww199" local mvar "avg_helpfulness_scope10_w199"

    quietly reghdfe `mvar' sim_mean `controls' `lvar' if med_cc, ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store a_`spec'
    scalar a_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
    post `results' ("mediation") ("`spec'") ("a: X -> M") ///
        (_b[sim_mean]) (_se[sim_mean]) (a_p) (e(N))

    quietly reghdfe `yvar' sim_mean `mvar' `controls' `lvar' if med_cc, ///
        absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store direct_`spec'
    scalar direct_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
    post `results' ("mediation") ("`spec'") ("cprime: direct X") ///
        (_b[sim_mean]) (_se[sim_mean]) (direct_p) (e(N))
    scalar b_p = 2 * ttail(e(df_r), abs(_b[`mvar'] / _se[`mvar']))
    post `results' ("mediation") ("`spec'") ("b: M -> Y") ///
        (_b[`mvar']) (_se[`mvar']) (b_p) (e(N))

    capture drop boot_hotel
    bootstrap indirect=r(indirect), reps(500) seed(`seed') ///
        cluster(hotel_id_num) idcluster(boot_hotel) nodots: ///
        helpful_indirect, mvar(`mvar') sample(med_cc)
    estimates store indirect_`spec'
    scalar indirect_p = 2 * normal(-abs(_b[indirect] / _se[indirect]))
    post `results' ("mediation") ("`spec'") ("indirect a*b") ///
        (_b[indirect]) (_se[indirect]) (indirect_p) (e(N))
    local seed = `seed' + 1
}

esttab total a_raw direct_raw a_log direct_log a_raww199 direct_raww199 ///
    using "`rtf'", append rtf ///
    keep(sim_mean avg_helpfulness_scope10 ln_avg_helpfulness_scope10 ///
        avg_helpfulness_scope10_w199 `controls' `lvar') ///
    order(sim_mean avg_helpfulness_scope10 ln_avg_helpfulness_scope10 ///
        avg_helpfulness_scope10_w199 `controls' `lvar') ///
    mtitles("Y: total" "Raw: M" "Raw: Y" "Log: M" "Log: Y" ///
        "Raw w199: M" "Raw w199: Y") ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    stats(N N_clust r2_a, ///
        labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
        fmt(%12.0fc %12.0fc %9.3f)) ///
    title("Table 3. Helpfulness Mediation: Log versus Raw Votes") ///
    addnotes("Outcome is ln(RevPAR) w199; lagged outcome is w595." ///
        "Hotel and calendar-month fixed effects are included; standard errors are clustered by hotel.") ///
    label nogap compress

esttab indirect_raw indirect_log indirect_raww199 using "`rtf'", append rtf ///
    keep(indirect) mtitles("Raw" "Log1p" "Raw w199") ///
    cells(b(star fmt(5)) se(par fmt(5))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    title("Table 4. Hotel-Cluster Bootstrap Indirect Effects") ///
    addnotes("Each specification uses 500 hotel-cluster bootstrap replications.") ///
    nogap compress

postclose `results'
use "`summary_results'", clear
export delimited using "`csv'", replace
