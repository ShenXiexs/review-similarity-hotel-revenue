*******************************************************
* run_core_simi_story_exploration_260524.do
* Exploratory screening for two stronger story lines:
* A) ARS main effect and contextual moderators
* B) Review volume / solicitation effect moderated by ARS
* C) Management-response text as engagement proxy
*******************************************************

version 17.0
clear all
set more off
set linesize 255
mata: mata set matafavor speed
capture log close

*******************************************************
************ 0. paths and required packages ************
*******************************************************

local project "/Users/samxie/Research/ReviewSimi_Sales/Code"
local out_root "`project'/outputs/core_simi_260501"
local data_dir "`out_root'/data"
local table_dir "`out_root'/tables_explicit"
local csv_dir "`out_root'/csv"
local log_dir "`out_root'/logs"
local run_id "260524"

local data_text "`data_dir'/core_simi_panel_260501_with_mr_text_260524.dta"
local data_mr "`data_dir'/core_simi_panel_260501_with_mr_260524.dta"
local data_core "`data_dir'/core_simi_panel_260501.dta"

cap mkdir "`table_dir'"
cap mkdir "`csv_dir'"
cap mkdir "`log_dir'"

capture confirm file "`data_text'"
if !_rc {
    local data_main "`data_text'"
    local has_mr_text 1
}
else {
    capture confirm file "`data_mr'"
    if !_rc {
        local data_main "`data_mr'"
        local has_mr_text 0
    }
    else {
        local data_main "`data_core'"
        local has_mr_text 0
    }
}

capture confirm file "`data_main'"
if _rc {
    di as error "Cannot find a usable core panel."
    exit 601
}

capture which reghdfe
if _rc {
    di as error "reghdfe not found. Install it first: ssc install reghdfe, replace"
    exit 199
}

capture which esttab
if _rc {
    di as error "esttab not found. Install it first: ssc install estout, replace"
    exit 199
}

use "`data_main'", clear
log using "`log_dir'/run_core_simi_story_exploration_260524.log", text replace

di as text "Data source: `data_main'"
di as text "MR text variables available: `has_mr_text'"

*******************************************************
************ 1. panel setup and generated variables ****
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

capture drop covid2020 covid2020_2022 post2020 pre_covid
gen byte covid2020 = (Year == 2020)
gen byte covid2020_2022 = inrange(Year, 2020, 2022)
gen byte post2020 = (Year >= 2020)
gen byte pre_covid = (Year <= 2019)

capture drop ln_RevPAR_clean_raw ln_lag_RevPAR_clean_raw
gen double ln_RevPAR_clean_raw = ln_RevPAR_clean
gen double ln_lag_RevPAR_clean_raw = ln_lag_RevPAR_clean

foreach spec in w199 w195 w025975 {
    capture drop ln_RevPAR_clean_`spec' ln_lag_RevPAR_clean_`spec'
    gen double ln_RevPAR_clean_`spec' = ln_RevPAR_clean
    gen double ln_lag_RevPAR_clean_`spec' = ln_lag_RevPAR_clean
}

quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local y_p1 = r(r1)
local y_p99 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 99)
local ly_p1 = r(r1)
local ly_p99 = r(r2)
replace ln_RevPAR_clean_w199 = `y_p1' if ln_RevPAR_clean_w199 < `y_p1' & !missing(ln_RevPAR_clean_w199)
replace ln_RevPAR_clean_w199 = `y_p99' if ln_RevPAR_clean_w199 > `y_p99' & !missing(ln_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p1' if ln_lag_RevPAR_clean_w199 < `ly_p1' & !missing(ln_lag_RevPAR_clean_w199)
replace ln_lag_RevPAR_clean_w199 = `ly_p99' if ln_lag_RevPAR_clean_w199 > `ly_p99' & !missing(ln_lag_RevPAR_clean_w199)

quietly _pctile ln_RevPAR_clean if cs_sample_focus100 == 1, p(1 95)
local y_p1 = r(r1)
local y_p95 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus100 == 1, p(1 95)
local ly_p1 = r(r1)
local ly_p95 = r(r2)
replace ln_RevPAR_clean_w195 = `y_p1' if ln_RevPAR_clean_w195 < `y_p1' & !missing(ln_RevPAR_clean_w195)
replace ln_RevPAR_clean_w195 = `y_p95' if ln_RevPAR_clean_w195 > `y_p95' & !missing(ln_RevPAR_clean_w195)
replace ln_lag_RevPAR_clean_w195 = `ly_p1' if ln_lag_RevPAR_clean_w195 < `ly_p1' & !missing(ln_lag_RevPAR_clean_w195)
replace ln_lag_RevPAR_clean_w195 = `ly_p95' if ln_lag_RevPAR_clean_w195 > `ly_p95' & !missing(ln_lag_RevPAR_clean_w195)

quietly _pctile ln_RevPAR_clean if cs_sample_focus50 == 1, p(2.5 97.5)
local y_p025 = r(r1)
local y_p975 = r(r2)
quietly _pctile ln_lag_RevPAR_clean if cs_sample_focus50 == 1, p(2.5 97.5)
local ly_p025 = r(r1)
local ly_p975 = r(r2)
replace ln_RevPAR_clean_w025975 = `y_p025' if ln_RevPAR_clean_w025975 < `y_p025' & !missing(ln_RevPAR_clean_w025975)
replace ln_RevPAR_clean_w025975 = `y_p975' if ln_RevPAR_clean_w025975 > `y_p975' & !missing(ln_RevPAR_clean_w025975)
replace ln_lag_RevPAR_clean_w025975 = `ly_p025' if ln_lag_RevPAR_clean_w025975 < `ly_p025' & !missing(ln_lag_RevPAR_clean_w025975)
replace ln_lag_RevPAR_clean_w025975 = `ly_p975' if ln_lag_RevPAR_clean_w025975 > `ly_p975' & !missing(ln_lag_RevPAR_clean_w025975)

capture drop ln_RevPAR_clean_w ln_lag_RevPAR_clean_w
gen double ln_RevPAR_clean_w = ln_RevPAR_clean_w199
gen double ln_lag_RevPAR_clean_w = ln_lag_RevPAR_clean_w199

capture drop rel_ln_recent_volumn rel_ln_lag_volumn_acc mean_recent_cym mean_lagvol_cym
bysort CityID ym: egen mean_recent_cym = mean(ln_recent_volumn)
bysort CityID ym: egen mean_lagvol_cym = mean(ln_lag_volumn_acc)
gen double rel_ln_recent_volumn = ln_recent_volumn - mean_recent_cym
gen double rel_ln_lag_volumn_acc = ln_lag_volumn_acc - mean_lagvol_cym

capture drop recent_above10 ln_recent_above10 recent_growth lagvol_over58 low_lagvol_58 high_lagvol_58
gen double recent_above10 = max(recent_volumn - 10, 0) if !missing(recent_volumn)
gen double ln_recent_above10 = ln(recent_above10 + 1)
gen double recent_growth = ln((recent_volumn + 1) / (lag_recent_volumn + 1)) if !missing(recent_volumn, lag_recent_volumn)
gen double lagvol_over58 = max(ln_lag_volumn_acc - 5.8, 0) if !missing(ln_lag_volumn_acc)
gen byte low_lagvol_58 = (ln_lag_volumn_acc < 5.8) if !missing(ln_lag_volumn_acc)
gen byte high_lagvol_58 = (ln_lag_volumn_acc >= 5.8) if !missing(ln_lag_volumn_acc)

capture drop sim_high_global sim_high_hotel_p90
quietly _pctile sim_mean if cs_sample_focus100 == 1, p(75 90)
local sim_p75 = r(r1)
local sim_p90 = r(r2)
gen byte sim_high_global = (sim_mean >= `sim_p75') if !missing(sim_mean)
gen byte sim_high_hotel_p90 = sim_high_p90_hotel if !missing(sim_high_p90_hotel)

foreach v in lag_mr_any lag_mr_count lag_mr_rate lag_mr_text_words lag_mr_avg_text_words lag_mr_quick7_share lag_mr_quick30_share lag_mr_apology_share lag_mr_recovery_share lag_mr_invite_share lag_mr_contact_share lag_mr_personal_share lag_mr_positive_share lag_mr_negtone_share lag_mr_template_share lag_mr_neg_response_rate lag_mr_neg_review_share lag_mr_avg_resp_days lag_mr_mgr_share {
    capture confirm variable `v'
    if !_rc {
        replace `v' = 0 if missing(`v')
    }
}

capture drop ln_lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words inv_lag_mr_resp_days
capture confirm variable lag_mr_count
if !_rc gen double ln_lag_mr_count = ln(lag_mr_count + 1)
capture confirm variable lag_mr_text_words
if !_rc gen double ln_lag_mr_words = ln(lag_mr_text_words + 1)
capture confirm variable lag_mr_avg_text_words
if !_rc gen double ln_lag_mr_avg_words = ln(lag_mr_avg_text_words + 1)
capture confirm variable lag_mr_avg_resp_days
if !_rc gen double inv_lag_mr_resp_days = -lag_mr_avg_resp_days

local z_candidates sim_mean lag_sim_mean d_sim_mean sim_mean_std_hotel sim_mean_5 sim_mean_10 sim_mean_15 sim_mean_20 sim_mean_30 ars_roll_10 lag_ars_roll_10 ars_jsd_sim lag_ars_jsd_sim ln_recent_volumn ln_lag_volumn_acc rel_ln_recent_volumn rel_ln_lag_volumn_acc ln_recent_above10 recent_above10 recent_growth volume_momentum ln_words_acc lagvol_over58 recent_sd rating_recent_gap rating_momentum rating_last_5 lag_avg_rating_acc lag_sd_acc ln_lag_avg_com_RevPAR price_gap zip_n_sample star_class lag_mr_rate lag_mr_count lag_mr_text_words lag_mr_avg_text_words ln_lag_mr_count ln_lag_mr_words ln_lag_mr_avg_words lag_mr_quick7_share lag_mr_quick30_share lag_mr_apology_share lag_mr_recovery_share lag_mr_invite_share lag_mr_contact_share lag_mr_personal_share lag_mr_positive_share lag_mr_negtone_share lag_mr_template_share lag_mr_neg_response_rate lag_mr_neg_review_share lag_mr_avg_resp_days inv_lag_mr_resp_days lag_mr_mgr_share
foreach v of local z_candidates {
    capture confirm variable `v'
    if !_rc {
        capture drop z_`v'
        quietly summarize `v' if cs_sample_focus100 == 1 & !missing(`v')
        if r(N) > 1 & r(sd) > 0 {
            gen double z_`v' = (`v' - r(mean)) / r(sd) if !missing(`v')
        }
        else {
            gen double z_`v' = .
        }
    }
}

capture drop z_ln_recent_volumn_sq z_ln_lag_volumn_acc_sq z_ln_recent_above10_sq z_lagvol_over58_sq
capture confirm variable z_ln_recent_volumn
if !_rc gen double z_ln_recent_volumn_sq = z_ln_recent_volumn^2
capture confirm variable z_ln_lag_volumn_acc
if !_rc gen double z_ln_lag_volumn_acc_sq = z_ln_lag_volumn_acc^2
capture confirm variable z_ln_recent_above10
if !_rc gen double z_ln_recent_above10_sq = z_ln_recent_above10^2
capture confirm variable z_lagvol_over58
if !_rc gen double z_lagvol_over58_sq = z_lagvol_over58^2

tempfile analysis_data
save `analysis_data', replace

*******************************************************
************ 2. controls and scan postfile *************
*******************************************************

local controls_a ln_recent_volumn recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199
local controls_b recent_sd rating_last_5 lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199
local controls_mech recent_sd rating_last_5 ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc lag_avg_rating_month ln_avg_com_RevPAR ln_lag_RevPAR_clean_w199
local mr_controls lag_mr_any z_lag_mr_rate z_ln_lag_mr_words

capture postclose storypost
postfile storypost str8 route str100 model_id str32 depvar str100 sample str80 focal str244 rhs str244 controls double coef se t p N clusters r2_a byte direction_ok str100 notes using "`csv_dir'/story_exploration_candidates_260524.dta", replace

capture program drop run_story_model
program define run_story_model
    syntax , ROUTE(string) MODEL(string) DEPVAR(name) SAMPLE(string) FOCAL(string) RHS(string) CONTROLS(string) [EXPECTED(string) NOTES(string)]

    capture quietly reghdfe `depvar' `rhs' `controls' if `sample', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    if _rc {
        post storypost ("`route'") ("`model'") ("`depvar'") ("`sample'") ("`focal'") ("`rhs'") ("`controls'") (.) (.) (.) (.) (.) (.) (.) (0) ("ERROR `_rc': `notes'")
        exit
    }

    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    local pos = colnumb(`b', "`focal'")
    if missing(`pos') | `pos' <= 0 {
        post storypost ("`route'") ("`model'") ("`depvar'") ("`sample'") ("`focal'") ("`rhs'") ("`controls'") (.) (.) (.) (.) (e(N)) (.) (e(r2_a)) (0) ("DROPPED: `notes'")
        exit
    }

    scalar coef = `b'[1, `pos']
    scalar se = sqrt(`V'[`pos', `pos'])
    scalar tval = coef / se
    capture scalar pval = 2 * ttail(e(df_r), abs(tval))
    if _rc | missing(pval) {
        scalar pval = 2 * normal(-abs(tval))
    }
    capture scalar cl = e(N_clust)
    if _rc {
        scalar cl = .
    }
    scalar dir_ok = 1
    if "`expected'" == "negative" & coef >= 0 scalar dir_ok = 0
    if "`expected'" == "positive" & coef <= 0 scalar dir_ok = 0

    post storypost ("`route'") ("`model'") ("`depvar'") ("`sample'") ("`focal'") ("`rhs'") ("`controls'") (coef) (se) (tval) (pval) (e(N)) (cl) (e(r2_a)) (dir_ok) ("`notes'")
end

*******************************************************
************ 3. systematic candidate screening *********
*******************************************************

local dv_list ln_RevPAR_clean_w199 ln_RevPAR_clean_w195 ln_RevPAR_clean_w025975
local sample_main "cs_sample_focus100 == 1"
local sample_ex20 "cs_sample_focus100 == 1 & Year != 2020"
local sample_post13 "cs_sample_post2013_excl2020 == 1"
local sample_star "cs_sample_focus100 == 1 & !missing(star_class)"

local ars_list z_sim_mean z_lag_sim_mean z_d_sim_mean z_sim_mean_std_hotel z_sim_mean_5 z_sim_mean_10 z_sim_mean_20 z_sim_mean_30 z_ars_roll_10 z_ars_jsd_sim
foreach dv of local dv_list {
    foreach ars of local ars_list {
        capture confirm variable `ars'
        if !_rc {
            run_story_model, route("A") model("A_main_`ars'_`dv'") depvar(`dv') sample("`sample_main'") focal("`ars'") rhs("`ars'") controls("`controls_a'") expected("negative") notes("ARS main effect")
            run_story_model, route("A") model("A_ex20_`ars'_`dv'") depvar(`dv') sample("`sample_ex20'") focal("`ars'") rhs("`ars'") controls("`controls_a'") expected("negative") notes("ARS main effect excluding 2020")
        }
    }
}

local mod_list covid2020_2022 z_ln_lag_avg_com_RevPAR z_price_gap z_zip_n_sample z_star_class z_recent_sd z_rating_recent_gap z_rating_momentum
foreach dv of local dv_list {
    run_story_model, route("A") model("A_covid_`dv'") depvar(`dv') sample("`sample_main'") focal("1.covid2020_2022#c.z_sim_mean") rhs("c.z_sim_mean##i.covid2020_2022") controls("`controls_a'") expected("positive") notes("COVID weakens ARS penalty")

    foreach mod in z_ln_lag_avg_com_RevPAR z_price_gap z_zip_n_sample z_star_class z_recent_sd z_rating_recent_gap z_rating_momentum {
        capture confirm variable `mod'
        if !_rc {
            local smp "`sample_main'"
            if "`mod'" == "z_star_class" local smp "`sample_star'"
            run_story_model, route("A") model("A_mod_`mod'_`dv'") depvar(`dv') sample("`smp'") focal("c.z_sim_mean#c.`mod'") rhs("c.z_sim_mean##c.`mod'") controls("`controls_a'") notes("ARS contextual moderator")
        }
    }
}

local vol_list z_ln_recent_volumn z_ln_recent_above10 z_recent_growth z_volume_momentum z_rel_ln_recent_volumn z_ln_lag_volumn_acc z_rel_ln_lag_volumn_acc z_lagvol_over58 z_ln_words_acc
local ars_int_list z_sim_mean z_sim_mean_std_hotel z_sim_mean_10 z_ars_roll_10 z_ars_jsd_sim
foreach dv of local dv_list {
    foreach vol of local vol_list {
        capture confirm variable `vol'
        if !_rc {
            foreach ars of local ars_int_list {
                capture confirm variable `ars'
                if !_rc {
                    run_story_model, route("B") model("B_`vol'_X_`ars'_`dv'") depvar(`dv') sample("`sample_main'") focal("c.`vol'#c.`ars'") rhs("c.`vol'##c.`ars'") controls("`controls_b'") notes("Volume x ARS")
                    run_story_model, route("B") model("B_ex20_`vol'_X_`ars'_`dv'") depvar(`dv') sample("`sample_ex20'") focal("c.`vol'#c.`ars'") rhs("c.`vol'##c.`ars'") controls("`controls_b'") notes("Volume x ARS excluding 2020")
                }
            }
        }
    }
}

foreach dv of local dv_list {
    run_story_model, route("B") model("B_recent_sq_`dv'") depvar(`dv') sample("`sample_main'") focal("c.z_ln_recent_volumn_sq#c.z_sim_mean") rhs("c.z_ln_recent_volumn##c.z_sim_mean c.z_ln_recent_volumn_sq##c.z_sim_mean") controls("`controls_b'") notes("Recent volume nonlinear moderation")
    run_story_model, route("B") model("B_cum_sq_`dv'") depvar(`dv') sample("`sample_main'") focal("c.z_ln_lag_volumn_acc_sq#c.z_sim_mean") rhs("c.z_ln_lag_volumn_acc##c.z_sim_mean c.z_ln_lag_volumn_acc_sq##c.z_sim_mean") controls("`controls_b'") notes("Cumulative volume nonlinear moderation")
    run_story_model, route("B") model("B_lowvol58_`dv'") depvar(`dv') sample("`sample_main' & low_lagvol_58 == 1") focal("z_sim_mean") rhs("z_sim_mean z_ln_recent_volumn") controls("`controls_b'") expected("negative") notes("ARS in low cumulative-volume months")
    run_story_model, route("B") model("B_highvol58_`dv'") depvar(`dv') sample("`sample_main' & high_lagvol_58 == 1") focal("z_sim_mean") rhs("z_sim_mean z_ln_recent_volumn") controls("`controls_b'") expected("negative") notes("ARS in high cumulative-volume months")
}

local mr_list z_lag_mr_rate z_ln_lag_mr_words z_ln_lag_mr_avg_words z_lag_mr_quick7_share z_lag_mr_apology_share z_lag_mr_recovery_share z_lag_mr_invite_share z_lag_mr_contact_share z_lag_mr_personal_share z_lag_mr_positive_share z_lag_mr_negtone_share z_lag_mr_template_share z_lag_mr_neg_response_rate z_lag_mr_neg_review_share z_inv_lag_mr_resp_days z_lag_mr_mgr_share
capture confirm variable lag_mr_any
if !_rc {
    run_story_model, route("C") model("C_reply_any_revenue") depvar(ln_RevPAR_clean_w199) sample("`sample_main'") focal("lag_mr_any") rhs("lag_mr_any z_sim_mean") controls("`controls_a'") notes("MR any direct revenue effect")
    run_story_model, route("C") model("C_reply_any_X_ARS_revenue") depvar(ln_RevPAR_clean_w199) sample("`sample_main'") focal("1.lag_mr_any#c.z_sim_mean") rhs("c.z_sim_mean##i.lag_mr_any") controls("`controls_a'") notes("MR any x ARS revenue effect")
}
foreach mr of local mr_list {
    capture confirm variable `mr'
    if !_rc {
        run_story_model, route("C") model("C_reply_rev_`mr'") depvar(ln_RevPAR_clean_w199) sample("`sample_main'") focal("`mr'") rhs("`mr' z_sim_mean") controls("`controls_a'") notes("MR text direct revenue effect")
        run_story_model, route("C") model("C_ARS_X_`mr'") depvar(ln_RevPAR_clean_w199) sample("`sample_main'") focal("c.z_sim_mean#c.`mr'") rhs("c.z_sim_mean##c.`mr'") controls("`controls_a'") notes("ARS x MR text/intensity")
        run_story_model, route("C") model("C_recent_triple_`mr'") depvar(ln_RevPAR_clean_w199) sample("`sample_main'") focal("c.z_ln_recent_volumn#c.z_sim_mean#c.`mr'") rhs("c.z_ln_recent_volumn##c.z_sim_mean##c.`mr'") controls("`controls_b'") notes("Recent volume x ARS x MR")
        run_story_model, route("C") model("C_mech_volume_`mr'") depvar(ln_recent_volumn) sample("`sample_main'") focal("`mr'") rhs("`mr'") controls("`controls_mech'") expected("positive") notes("MR predicts later review volume")
        run_story_model, route("C") model("C_mech_ars_`mr'") depvar(sim_mean) sample("`sample_main'") focal("`mr'") rhs("`mr'") controls("`controls_mech'") notes("MR predicts later ARS")
    }
}

postclose storypost
use "`csv_dir'/story_exploration_candidates_260524.dta", clear
gen abs_t = abs(t)
gen sig_10 = (p < .10) if !missing(p)
gen sig_05 = (p < .05) if !missing(p)
gen sig_01 = (p < .01) if !missing(p)
gen story_score = 0
replace story_score = story_score + 5 if p < .01 & direction_ok == 1
replace story_score = story_score + 3 if p >= .01 & p < .05 & direction_ok == 1
replace story_score = story_score + 1 if p >= .05 & p < .10 & direction_ok == 1
replace story_score = story_score + 1 if N >= 10000
replace story_score = story_score - 2 if missing(coef)
sort route -story_score p
export delimited using "`csv_dir'/story_exploration_candidates_260524.csv", replace

*******************************************************
************ 4. complete regression tables *************
*******************************************************

use `analysis_data', clear

estimates clear
local tableA ""
capture quietly reghdfe ln_RevPAR_clean_w199 z_sim_mean `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store ta_sim_w199
    local tableA "`tableA' ta_sim_w199"
}
capture quietly reghdfe ln_RevPAR_clean_w195 z_sim_mean `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store ta_sim_w195
    local tableA "`tableA' ta_sim_w195"
}
capture quietly reghdfe ln_RevPAR_clean_w025975 z_sim_mean `controls_a' if cs_sample_focus50 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store ta_sim_w025
    local tableA "`tableA' ta_sim_w025"
}
capture quietly reghdfe ln_RevPAR_clean_w199 z_sim_mean_std_hotel `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store ta_hotelstd
    local tableA "`tableA' ta_hotelstd"
}
capture confirm variable z_sim_mean_10
if !_rc {
    capture quietly reghdfe ln_RevPAR_clean_w199 z_sim_mean_10 `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    if !_rc {
        est store ta_scope10
        local tableA "`tableA' ta_scope10"
    }
}
capture confirm variable z_ars_jsd_sim
if !_rc {
    capture quietly reghdfe ln_RevPAR_clean_w199 z_ars_jsd_sim `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    if !_rc {
        est store ta_jsd
        local tableA "`tableA' ta_jsd"
    }
}
capture quietly reghdfe ln_RevPAR_clean_w199 c.z_sim_mean##i.covid2020_2022 `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store ta_covid
    local tableA "`tableA' ta_covid"
}

if "`tableA'" != "" {
    esttab `tableA' using "`table_dir'/story_table_a_ars_main_260524.rtf", replace ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("w199" "w195" "w025/975" "hotel std" "scope10" "JSD" "COVID") ///
        nogap compress
    esttab `tableA' using "`csv_dir'/story_table_a_ars_main_260524.csv", replace csv ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("w199" "w195" "w025/975" "hotel std" "scope10" "JSD" "COVID") ///
        nogap
}

estimates clear
local tableAm ""
foreach pair in ///
    "c.z_sim_mean##c.z_recent_sd|am_sd" ///
    "c.z_sim_mean##c.z_rating_recent_gap|am_ratinggap" ///
    "c.z_sim_mean##c.z_rating_momentum|am_ratingmom" ///
    "c.z_sim_mean##c.z_ln_lag_avg_com_RevPAR|am_compete" ///
    "c.z_sim_mean##c.z_price_gap|am_pricegap" ///
    "c.z_sim_mean##c.z_star_class|am_star" {
    gettoken spec estname : pair, parse("|")
    local estname = subinstr("`estname'", "|", "", .)
    local smp "cs_sample_focus100 == 1"
    if "`estname'" == "am_star" local smp "cs_sample_focus100 == 1 & !missing(star_class)"
    capture quietly reghdfe ln_RevPAR_clean_w199 `spec' `controls_a' if `smp', absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    if !_rc {
        est store `estname'
        local tableAm "`tableAm' `estname'"
    }
}
capture quietly reghdfe ln_RevPAR_clean_w199 c.z_sim_mean##i.covid2020_2022 `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store am_covid
    local tableAm "`tableAm' am_covid"
}
if "`tableAm'" != "" {
    esttab `tableAm' using "`table_dir'/story_table_a_moderators_260524.rtf", replace ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("rating sd" "rating gap" "rating mom" "competition" "price gap" "star" "COVID") ///
        nogap compress
    esttab `tableAm' using "`csv_dir'/story_table_a_moderators_260524.csv", replace csv ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("rating sd" "rating gap" "rating mom" "competition" "price gap" "star" "COVID") ///
        nogap
}

estimates clear
local tableB ""
foreach pair in ///
    "c.z_ln_recent_volumn##c.z_sim_mean|tb_recent" ///
    "c.z_ln_recent_above10##c.z_sim_mean|tb_recent10" ///
    "c.z_recent_growth##c.z_sim_mean|tb_growth" ///
    "c.z_rel_ln_recent_volumn##c.z_sim_mean|tb_relrecent" ///
    "c.z_ln_lag_volumn_acc##c.z_sim_mean|tb_cum" ///
    "c.z_lagvol_over58##c.z_sim_mean|tb_cum58" ///
    "c.z_ln_words_acc##c.z_sim_mean|tb_words" {
    gettoken spec estname : pair, parse("|")
    local estname = subinstr("`estname'", "|", "", .)
    capture quietly reghdfe ln_RevPAR_clean_w199 `spec' `controls_b' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    if !_rc {
        est store `estname'
        local tableB "`tableB' `estname'"
    }
}
capture quietly reghdfe ln_RevPAR_clean_w199 c.z_ln_recent_volumn##c.z_sim_mean c.z_ln_recent_volumn_sq##c.z_sim_mean `controls_b' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store tb_recent_sq
    local tableB "`tableB' tb_recent_sq"
}
if "`tableB'" != "" {
    esttab `tableB' using "`table_dir'/story_table_b_volume_ars_260524.rtf", replace ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("recent" "recent>10" "growth" "rel recent" "cumulative" "cum>5.8" "text volume" "recent sq") ///
        nogap compress
    esttab `tableB' using "`csv_dir'/story_table_b_volume_ars_260524.csv", replace csv ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("recent" "recent>10" "growth" "rel recent" "cumulative" "cum>5.8" "text volume" "recent sq") ///
        nogap
}

estimates clear
local tableC ""
foreach pair in ///
    "c.z_sim_mean##c.z_lag_mr_rate|tc_rate" ///
    "c.z_sim_mean##c.z_ln_lag_mr_words|tc_words" ///
    "c.z_sim_mean##c.z_lag_mr_quick7_share|tc_quick" ///
    "c.z_sim_mean##c.z_lag_mr_apology_share|tc_apology" ///
    "c.z_sim_mean##c.z_lag_mr_invite_share|tc_invite" ///
    "c.z_sim_mean##c.z_lag_mr_recovery_share|tc_recovery" ///
    "c.z_sim_mean##c.z_lag_mr_personal_share|tc_personal" ///
    "c.z_sim_mean##c.z_lag_mr_negtone_share|tc_negtone" ///
    "c.z_sim_mean##c.z_lag_mr_template_share|tc_template" ///
    "c.z_ln_recent_volumn##c.z_sim_mean##c.z_ln_lag_mr_avg_words|tc_triple_avgw" ///
    "c.z_ln_recent_volumn##c.z_sim_mean##c.z_lag_mr_quick7_share|tc_triple_quick" ///
    "c.z_ln_recent_volumn##c.z_sim_mean##c.z_lag_mr_apology_share|tc_triple_apol" ///
    "c.z_ln_recent_volumn##c.z_sim_mean##c.z_lag_mr_positive_share|tc_triple_pos" ///
    "c.z_ln_recent_volumn##c.z_sim_mean##c.z_lag_mr_recovery_share|tc_triple_rec" {
    gettoken spec estname : pair, parse("|")
    local estname = subinstr("`estname'", "|", "", .)
    capture quietly reghdfe ln_RevPAR_clean_w199 `spec' `controls_b' lag_mr_any if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    if !_rc {
        est store `estname'
        local tableC "`tableC' `estname'"
    }
}
if "`tableC'" != "" {
    esttab `tableC' using "`table_dir'/story_table_c_mr_text_260524.rtf", replace ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("rate" "words" "quick7" "apology" "invite" "recovery" "personal" "neg tone" "template" "triple avg words" "triple quick7" "triple apology" "triple positive" "triple recovery") ///
        nogap compress
    esttab `tableC' using "`csv_dir'/story_table_c_mr_text_260524.csv", replace csv ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("rate" "words" "quick7" "apology" "invite" "recovery" "personal" "neg tone" "template" "triple avg words" "triple quick7" "triple apology" "triple positive" "triple recovery") ///
        nogap
}

estimates clear
local tableCr ""
foreach pair in ///
    "c.z_sim_mean##i.lag_mr_any|cr_any" ///
    "c.z_sim_mean##c.z_lag_mr_rate|cr_rate" ///
    "c.z_sim_mean##c.z_ln_lag_mr_words|cr_words" ///
    "c.z_sim_mean##c.z_lag_mr_quick7_share|cr_quick" ///
    "c.z_sim_mean##c.z_lag_mr_invite_share|cr_invite" ///
    "c.z_sim_mean##c.z_lag_mr_positive_share|cr_positive" ///
    "c.z_sim_mean##c.z_lag_mr_recovery_share|cr_recovery" ///
    "c.z_sim_mean##c.z_lag_mr_neg_response_rate|cr_negresp" {
    gettoken spec estname : pair, parse("|")
    local estname = subinstr("`estname'", "|", "", .)
    capture quietly reghdfe ln_RevPAR_clean_w199 `spec' `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
    if !_rc {
        est store `estname'
        local tableCr "`tableCr' `estname'"
    }
}
if "`tableCr'" != "" {
    esttab `tableCr' using "`table_dir'/story_table_c_reply_revenue_260524.rtf", replace ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("any reply" "reply rate" "reply words" "quick7" "invite" "positive" "recovery" "neg reply rate") ///
        nogap compress
    esttab `tableCr' using "`csv_dir'/story_table_c_reply_revenue_260524.csv", replace csv ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("any reply" "reply rate" "reply words" "quick7" "invite" "positive" "recovery" "neg reply rate") ///
        nogap
}

estimates clear
local tableM ""
capture quietly reghdfe ln_recent_volumn z_lag_mr_rate z_ln_lag_mr_words z_lag_mr_quick7_share z_lag_mr_apology_share z_lag_mr_recovery_share z_lag_mr_template_share `controls_mech' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store tm_volume
    local tableM "`tableM' tm_volume"
}
capture quietly reghdfe sim_mean z_lag_mr_rate z_ln_lag_mr_words z_lag_mr_quick7_share z_lag_mr_apology_share z_lag_mr_recovery_share z_lag_mr_template_share `controls_mech' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store tm_ars
    local tableM "`tableM' tm_ars"
}
capture quietly reghdfe ln_RevPAR_clean_w199 z_lag_mr_rate z_ln_lag_mr_words z_lag_mr_quick7_share z_lag_mr_apology_share z_lag_mr_recovery_share z_lag_mr_template_share `controls_a' if cs_sample_focus100 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
if !_rc {
    est store tm_revpar
    local tableM "`tableM' tm_revpar"
}
if "`tableM'" != "" {
    esttab `tableM' using "`table_dir'/story_table_c_mr_mechanisms_260524.rtf", replace ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("DV: volume" "DV: ARS" "DV: RevPAR") ///
        nogap compress
    esttab `tableM' using "`csv_dir'/story_table_c_mr_mechanisms_260524.csv", replace csv ///
        star(* 0.10 ** 0.05 *** 0.01 **** 0.001) ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
        mtitles("DV: volume" "DV: ARS" "DV: RevPAR") ///
        nogap
}

log close
