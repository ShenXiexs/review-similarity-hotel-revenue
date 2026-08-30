************************************************************
* Formal hotel-cluster bootstrap for the helpfulness mediation.
* Reports normal, percentile, and bias-corrected intervals.
************************************************************

version 17.0
clear all
set more off
set linesize 255

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local outdir "`project'/outputs/paper/rtf-0826"
local rtf "`outdir'/routeAB_helpfulness_bootstrap_1000_260826.rtf"
local csv "`outdir'/routeAB_helpfulness_bootstrap_1000_260826.csv"

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

capture confirm variable ln_RevPAR_clean_w199
if _rc winsor2 ln_RevPAR_clean, cuts(1 99) suffix(_w199)
capture confirm variable ln_lag_RevPAR_clean_w595
if _rc winsor2 ln_lag_RevPAR_clean, cuts(5 95) suffix(_w595)
capture drop avg_helpfulness_scope10_w199 scope10_avg_review_age_years
winsor2 avg_helpfulness_scope10, cuts(1 99) suffix(_w199)
gen double scope10_avg_review_age_years = scope10_avg_review_age_days / 365.25

local controls "recent_sd_10 ln_recent_volumn_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR scope10_avg_review_age_years"
local yvar "ln_RevPAR_clean_w199"
local lvar "ln_lag_RevPAR_clean_w595"

egen byte med_missing = rowmiss(`yvar' sim_mean ///
    avg_helpfulness_scope10 ln_avg_helpfulness_scope10 ///
    avg_helpfulness_scope10_w199 `controls' `lvar')
gen byte med_cc = (med_missing == 0)
drop med_missing

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

tempname results
tempfile summary_results
postfile `results' str16 specification double indirect se normal_p ///
    pct_lo pct_hi bc_lo bc_hi N using "`summary_results'", replace

matrix Boot = J(7, 3, .)
matrix rownames Boot = indirect se normal_p pct_lo pct_hi bc_lo bc_hi
matrix colnames Boot = raw log raw_w199

local specs "raw log raww199"
local col = 0
local seed 260826
foreach spec of local specs {
    local ++col
    if "`spec'" == "raw" local mvar "avg_helpfulness_scope10"
    if "`spec'" == "log" local mvar "ln_avg_helpfulness_scope10"
    if "`spec'" == "raww199" local mvar "avg_helpfulness_scope10_w199"

    capture drop boot_hotel
    bootstrap indirect=r(indirect), reps(1000) seed(`seed') ///
        cluster(hotel_id_num) idcluster(boot_hotel) nodots: ///
        helpful_indirect, mvar(`mvar') sample(med_cc)
    estat bootstrap, percentile bc

    scalar b = _b[indirect]
    scalar se = _se[indirect]
    scalar p = 2 * normal(-abs(b / se))
    matrix CIp = e(ci_percentile)
    matrix CIbc = e(ci_bc)
    scalar pct_lo = CIp[1,1]
    scalar pct_hi = CIp[2,1]
    scalar bc_lo = CIbc[1,1]
    scalar bc_hi = CIbc[2,1]

    matrix Boot[1, `col'] = b
    matrix Boot[2, `col'] = se
    matrix Boot[3, `col'] = p
    matrix Boot[4, `col'] = pct_lo
    matrix Boot[5, `col'] = pct_hi
    matrix Boot[6, `col'] = bc_lo
    matrix Boot[7, `col'] = bc_hi
    post `results' ("`spec'") (b) (se) (p) ///
        (pct_lo) (pct_hi) (bc_lo) (bc_hi) (e(N))
    estimates store indirect_`spec'
    local seed = `seed' + 1
}

esttab matrix(Boot, fmt(5)) using "`rtf'", replace rtf ///
    title("Hotel-Cluster Bootstrap: Helpfulness Indirect Effects") ///
    addnotes("Each column uses 1,000 hotel-cluster bootstrap replications." ///
        "P: percentile 95% confidence interval; BC: bias-corrected 95% confidence interval." ///
        "Outcome is ln(RevPAR) w199; lagged outcome is w595.") ///
    nomtitles nonumbers compress

postclose `results'
use "`summary_results'", clear
export delimited using "`csv'", replace
