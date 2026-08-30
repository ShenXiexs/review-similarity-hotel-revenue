************************************************************
* Exploratory mediation: ARS -> recent review volume -> RevPAR
* Uses the focus100 sample in the canonical Route A/B dataset.
************************************************************

version 17.0
clear all
set more off
set linesize 255

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local data "`project'/outputs/core_simi_260501/data/routeAB_heterogeneity_final_260715.dta"
local outdir "`project'/outputs/paper/rtf-0826"
local rtf "`outdir'/routeAB_recent_review_volume_mediation_260826.rtf"
local summary_csv "`outdir'/routeAB_recent_review_volume_mediation_260826.csv"

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

label variable sim_mean "ARS"
label variable ln_recent_volumn_10 "ln(Recent review volume)"
label variable recent_sd_10 "Recent rating SD"
label variable lag_avg_rating_month "Rating month, t-1"
label variable rating_last_5 "Rating last 5, t"
label variable ln_lag_volumn_acc "ln(Accumulated review volume)"
label variable lag_avg_rating_acc "Accumulated rating, t-1"
label variable lag_sd_acc "Accumulated rating SD, t-1"
label variable ln_avg_com_RevPAR "ln(Competitor RevPAR)"

* The mediator is excluded from this control list by construction.
local controls "recent_sd_10 lag_avg_rating_month rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ln_avg_com_RevPAR"

capture program drop volume_indirect
program define volume_indirect, rclass
    syntax, YVAR(name) LVAR(name) SAMPLE(name)
    local panel_id hotel_id_num
    capture confirm variable boot_hotel
    if !_rc local panel_id boot_hotel

    quietly reghdfe ln_recent_volumn_10 sim_mean ///
        recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR `lvar' if `sample', ///
        absorb(`panel_id' ym)
    scalar a_path = _b[sim_mean]

    quietly reghdfe `yvar' sim_mean ln_recent_volumn_10 ///
        recent_sd_10 lag_avg_rating_month rating_last_5 ///
        ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc ///
        ln_avg_com_RevPAR `lvar' if `sample', ///
        absorb(`panel_id' ym)
    return scalar indirect = a_path * _b[ln_recent_volumn_10]
end

tempname results
tempfile summary_results
postfile `results' str18 specification str20 path double b se p N ///
    using "`summary_results'", replace

local specs "primary matched195 matched595"
local write_mode "replace"
local seed 260826

foreach spec of local specs {
    if "`spec'" == "primary" {
        local yvar "ln_RevPAR_clean_w199"
        local lvar "ln_lag_RevPAR_clean_w595"
        local title "Primary: Y w199 and lagged Y w595"
        local reps 500
    }
    else if "`spec'" == "matched195" {
        local yvar "ln_RevPAR_clean_w195"
        local lvar "ln_lag_RevPAR_clean_w195"
        local title "Robustness: Y and lagged Y w195"
        local reps 200
    }
    else {
        local yvar "ln_RevPAR_clean_w595"
        local lvar "ln_lag_RevPAR_clean_w595"
        local title "Robustness: Y and lagged Y w595"
        local reps 200
    }

    capture drop med_missing
    capture drop med_cc
    egen byte med_missing = rowmiss(`yvar' sim_mean ln_recent_volumn_10 ///
        `controls' `lvar')
    gen byte med_cc = (med_missing == 0)
    drop med_missing

    quietly reghdfe ln_recent_volumn_10 sim_mean `controls' `lvar' if med_cc, ///
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

    quietly reghdfe `yvar' sim_mean ln_recent_volumn_10 `controls' `lvar' ///
        if med_cc, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    estimates store direct_`spec'
    scalar cp_p = 2 * ttail(e(df_r), abs(_b[sim_mean] / _se[sim_mean]))
    post `results' ("`spec'") ("cprime: direct") ///
        (_b[sim_mean]) (_se[sim_mean]) (cp_p) (e(N))
    scalar b_p = 2 * ttail(e(df_r), ///
        abs(_b[ln_recent_volumn_10] / _se[ln_recent_volumn_10]))
    post `results' ("`spec'") ("b: M -> Y") ///
        (_b[ln_recent_volumn_10]) (_se[ln_recent_volumn_10]) (b_p) (e(N))

    esttab a_`spec' total_`spec' direct_`spec' using "`rtf'", ///
        `write_mode' rtf ///
        keep(sim_mean ln_recent_volumn_10 `controls' `lvar') ///
        order(sim_mean ln_recent_volumn_10 `controls' `lvar') ///
        mtitles("M equation" "Y: total effect" "Y: X and M") ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        stats(N N_clust r2_a, ///
            labels("Observations" "Hotel clusters" "Adjusted R-squared") ///
            fmt(%12.0fc %12.0fc %9.3f)) ///
        title("`title'") ///
        addnotes("Exploratory mediation: ARS -> recent review volume -> RevPAR." ///
            "Hotel and calendar-month fixed effects are included; standard errors are clustered by hotel.") ///
        label nogap compress
    local write_mode "append"

    capture drop boot_hotel
    bootstrap indirect=r(indirect), reps(`reps') seed(`seed') ///
        cluster(hotel_id_num) idcluster(boot_hotel) nodots: ///
        volume_indirect, yvar(`yvar') lvar(`lvar') sample(med_cc)
    estimates store indirect_`spec'
    scalar ind_p = 2 * normal(-abs(_b[indirect] / _se[indirect]))
    post `results' ("`spec'") ("indirect a*b") ///
        (_b[indirect]) (_se[indirect]) (ind_p) (e(N))

    local seed = `seed' + 1
}

esttab indirect_primary indirect_matched195 indirect_matched595 ///
    using "`rtf'", append rtf keep(indirect) ///
    mtitles("Primary" "Matched w195" "Matched w595") ///
    cells(b(star fmt(5)) se(par fmt(5))) ///
    star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
    title("Cluster-bootstrap indirect effects") ///
    addnotes("Primary uses 500 hotel-cluster bootstrap replications; robustness specifications use 200." ///
        "The indirect effect is the product of the ARS-to-volume and volume-to-Revenue coefficients.") ///
    nogap compress

postclose `results'
use "`summary_results'", clear
export delimited using "`summary_csv'", replace
