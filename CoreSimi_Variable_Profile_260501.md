# Core-Simi 260501 Variable Profile

## Files

- Final regression do-file: `scripts/stata/run_core_simi_explicit_regressions_260501.do`
- Input data: `outputs/core_simi_260501/data/core_simi_panel_260501.dta`
- Descriptive-statistics code: `scripts/stata/descriptive_core_simi_variables_260501.do`
- Descriptive-statistics output: `outputs/core_simi_260501/summary/desc_stats_core_simi_260501.csv`
- Correlation output: `outputs/core_simi_260501/summary/corr_core_simi_260501.csv`
- Descriptive log: `outputs/core_simi_260501/summary/descriptive_core_simi_variables_260501.log`

## Dataset Volume

| Item | Value |
|---|---:|
| DTA file size | 68.22 MB |
| Observations | 40,197 |
| Variables in DTA | 223 |
| Hotels | 1,007 |
| Cities | 4 |
| ZIP groups | 172 |
| Months | 136 |
| Year range | 2011-2022 |
| Month range | 2011-01 to 2022-09 |

## Focus100 Baseline Sample Size

The baseline review-volume sample used in the final H1-H4 and COVID regressions is `cs_sample_focus100 == 1`. In this sample:

| Item | Value |
|---|---:|
| Observations / hotel-month rows | 34,791 |
| Hotels | 565 |
| Average cumulative reviews per hotel | 611.70 |
| Median cumulative reviews per hotel | 353 |
| Review range per hotel | 100-8,391 |
| Average hotel-month rows per hotel | 61.58 |
| Median hotel-month rows per hotel | 58 |
| Hotel-month row range per hotel | 2-134 |
| Distinct calendar months | 136 |
| Year range | 2011-2022 |

## Sample Flags

| Sample variable | Meaning | Observations | Hotels |
|---|---|---:|---:|
| `cs_sample_full` | Full constructed panel sample | 40,197 | 1,007 |
| `cs_sample_focus50` | Focus sample with at least 50 review-related observations/coverage threshold | 37,541 | 670 |
| `cs_sample_focus100` | Main baseline focus sample, used by final H1-H4/COVID regressions | 34,791 | 565 |
| `cs_sample_exclude2020` | Sample excluding 2020 observations | 37,107 | 998 |
| `cs_sample_post2013` | Sample after 2013 start window | 36,908 | 1,006 |

## Source Variables From DTA

| Variable | Role in do-file | Chinese description |
|---|---|---|
| `HotelID` | Panel id source | 酒店 ID；脚本会转成 `hotel_id_num` 用于 `xtset`、cluster 和 fixed effects。 |
| `Year` | Time control / sample split | 年份；用于 COVID、pre-COVID、post-2013、exclude-2020 等窗口。 |
| `Mon` | Time control | 月份；用于 Sys-GMM 的 `i.Year i.Mon` test variants。 |
| `year_month` | Monthly date source | 年月字符串；脚本转成 Stata monthly variable `ym`。 |
| `Zip` | Geographic grouping | 邮编；COVID H2 分组中转成 `zip_num` 后按 `Zip x ym` 取中位数。 |
| `CityID` | Geographic grouping | 城市 ID；H3/H5 中用于 `CityID x ym` median grouping。 |
| `ln_RevPAR_clean` | Main dependent variable | 酒店绩效，清洗后 RevPAR 的对数。 |
| `ln_RevPAR_clean_w` | Generated dependent variable | `ln_RevPAR_clean` 的 winsorized 版本，脚本内生成。 |
| `d_ln_RevPAR` | Alternative dependent variable | RevPAR 对数变化，用于部分 COVID/growth 和 H3 规格。 |
| `sim_mean` | Main independent variable | 核心 review similarity 变量；所有正式 H1-H4 模型必须使用它。 |
| `ln_recent_volumn` | Control | 近期评论数量的对数。 |
| `recent_sd` | Control / H5 moderator | 近期评分或评论分布的标准差；也用于 H5 分组。 |
| `rating_last_5` | Control / H2 moderator | 最近 5 条评论评分，用于声誉控制和 H2 低/高声誉分组。 |
| `ln_lag_volumn_acc` | Control / H3 moderator | 累计评论数量滞后项的对数，用于 popularity 控制和 H3 alternative grouping。 |
| `lag_recent_volumn` | H3 moderator | 滞后近期评论数量，用于 popularity median grouping。 |
| `lag_avg_rating_acc` | Control / H2 alternative moderator | 累计平均评分滞后项。 |
| `lag_sd_acc` | Control | 累计评分标准差滞后项。 |
| `lag_avg_rating_month` | Control / H2 alternative moderator | 月度平均评分滞后项。 |
| `lag_rating_last_5` | COVID H2 moderator | 最近 5 条评分的滞后项，用于 COVID reputation grouping。 |
| `ln_avg_com_RevPAR` | Control | 竞争酒店平均 RevPAR 的对数。 |
| `ln_lag_RevPAR_clean` | Dynamic control / GMM variable | 滞后酒店绩效；H1 OLS/FE 控制项，Sys-GMM 中作为 GMM-style instrument 的变量。 |
| `ln_lag_RevPAR_clean_w` | Generated dynamic control | `ln_lag_RevPAR_clean` 的 winsorized 版本，脚本内生成并用于 test variants。 |
| `star_class` | H4 moderator | 酒店星级；H4 用于低/高端酒店分组。 |
| `cs_sample_full` | Sample flag | 全样本标记。 |
| `cs_sample_focus50` | Sample flag | focus50 样本标记。 |
| `cs_sample_focus100` | Main sample flag | 主要基准样本标记；H1-H4 和 COVID extension 主要使用。 |
| `cs_sample_exclude2020` | Sample flag | 排除 2020 年样本标记。 |
| `cs_sample_post2013` | Sample flag | 2013 年以后样本标记。 |

## Generated Variables In The Do-File

| Variable | Construction | Chinese description |
|---|---|---|
| `hotel_id_num` | `encode HotelID` or copy numeric `HotelID` | 数值型酒店 ID，用于 panel setting、cluster 和 FE。 |
| `ym` | `monthly(year_month, "YM")` | Stata 月度时间变量，用于 `xtset`、年月固定效应。 |
| `cs_covid2020` | `Year == 2020` | 2020 年 COVID dummy，早期 GMM alternative tests 使用。 |
| `cs_covid2021` | `Year == 2021` | 2021 年 COVID dummy。 |
| `cs_covid2022` | `Year == 2022` | 2022 年 COVID dummy。 |
| `h2_med_rating5_ym` | `bysort ym: median(rating_last_5)` | 每月最近 5 条评分中位数。 |
| `h2_low_rating5_ym` | `rating_last_5 < h2_med_rating5_ym` | H2 低声誉组，低于月度中位数为 1。 |
| `h2_med_lag_avg_rating_acc` | `bysort ym: median(lag_avg_rating_acc)` | 每月累计评分滞后项中位数。 |
| `h2_low_lag_avg_rating_acc` | `lag_avg_rating_acc <= h2_med_lag_avg_rating_acc` | H2 alternative 低声誉组。 |
| `h2_med_lag_avg_rating_month` | `bysort ym: median(lag_avg_rating_month)` | 描述统计脚本补充生成；用于支持当前 do 中引用的 H2.2 分组变量。 |
| `h2_low_lag_avg_rating_month` | `lag_avg_rating_month <= h2_med_lag_avg_rating_month` | H2.2 低声誉组；当前 main do 引用但未显式生成，需复核。 |
| `h3_med_lag_recent_volumn` | `bysort CityID ym: median(lag_recent_volumn)` | 城市-月份层面的滞后近期评论数量中位数。 |
| `h3_low_lag_recent_volumn` | `lag_recent_volumn < h3_med_lag_recent_volumn` | H3 低热度组，低于城市-月份中位数为 1。 |
| `h3_med_ln_lag_volumn_acc` | `median(ln_lag_volumn_acc)` | 全样本累计评论量对数中位数。 |
| `h3_low_ln_lag_volumn_acc` | `ln_lag_volumn_acc < h3_med_ln_lag_volumn_acc` | H3 alternative 低热度组。 |
| `h4_low_star35` | `star_class <= 3.5` and pre-COVID | H4 低端酒店组；pre-COVID 且星级不高于 3.5 为 1。 |
| `h5_med_recent_sd` | `bysort CityID ym: median(recent_sd)` | 城市-月份层面的近期评分分散度中位数。 |
| `h5_low_recent_sd` | `recent_sd < h5_med_recent_sd` | H5 低分散度组。 |
| `covid2020` | `Year == 2020` | COVID 2020 shock dummy。 |
| `covid2020_2022` | `inrange(Year, 2020, 2022)` | COVID pandemic period dummy。 |
| `post2020` | `Year >= 2020` | 2020 年及以后 dummy。 |
| `pre_covid` | `Year <= 2019` | COVID 前样本 dummy。 |
| `zip_num` | `egen group(Zip)` | 数值型 ZIP 分组变量。 |
| `h2_covid_med_zipym` | `bysort zip_num ym: median(lag_rating_last_5)` | ZIP-月份层面的 COVID H2 声誉中位数。 |
| `h2_covid_lowrep` | `lag_rating_last_5 < h2_covid_med_zipym` | COVID H2 低声誉组。 |
| `h3_covid_med_all` | `median(lag_recent_volumn)` | COVID H3 全样本热度中位数。 |
| `h3_covid_lowpop` | `lag_recent_volumn < h3_covid_med_all` | COVID H3 低热度组。 |
| `h4_covid_lowstar3` | `star_class <= 3` | COVID H4 低星级组。 |
| `h2_pre`, `h3_pre`, `h4_pre` | Group variables restricted to `Year <= 2019` | 分期 bdiff 的 pre-COVID 分组变量。 |
| `h2_shock`, `h3_shock`, `h4_shock` | Group variables restricted to `Year == 2020` | 分期 bdiff 的 2020 shock 分组变量。 |
| `h2_pandemic`, `h3_pandemic`, `h4_pandemic` | Group variables restricted to `Year in 2020-2022` | 分期 bdiff 的 pandemic 分组变量。 |

## Factor And Interaction Terms

These are not standalone variables in the DTA. Stata expands them at runtime:

| Term | Meaning |
|---|---|
| `i.ym` | Year-month fixed/time dummies in Sys-GMM and interaction models. |
| `i.Year`, `i.Mon` | Year and month dummies in GMM test variants. |
| `c.sim_mean##i.group` | Heterogeneity interaction: similarity slope differs by group. |
| `c.sim_mean##i.group##i.covid2020_2022` | Triple interaction: similarity slope differs by group and COVID window. |

## Current Cleanup Notes

- The current do-file contains `h2_med_rating5_ym3` in the construction of `h2_low_rating5_ym`. This variable is not in the DTA and is not generated earlier; it is likely a typo for `h2_med_rating5_ym`.
- The current do-file references `h2_low_lag_avg_rating_month` in H2.2, but does not explicitly generate it. The descriptive script generates it as a monthly median split of `lag_avg_rating_month` so it can be summarized, but the main regression do should be cleaned before a final full rerun.

## Descriptive Statistics And Correlation Code

Run this script from the project root:

```stata
do scripts/stata/descriptive_core_simi_variables_260501.do
```

The script recreates the generated variables, then exports:

```text
outputs/core_simi_260501/summary/desc_stats_core_simi_260501.csv
outputs/core_simi_260501/summary/corr_core_simi_260501.csv
outputs/core_simi_260501/summary/descriptive_core_simi_variables_260501.log
```

The core descriptive-statistics logic is:

```stata
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
use `desc_dta', clear
export delimited using "outputs/core_simi_260501/summary/desc_stats_core_simi_260501.csv", replace
```

The core correlation logic is:

```stata
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
export delimited using "outputs/core_simi_260501/summary/corr_core_simi_260501.csv", replace
restore
```

## Selected Descriptive Statistics In Focus100

These numbers come from `desc_stats_core_simi_260501.csv`.

| Variable | N | Mean | Median | SD | Variance |
|---|---:|---:|---:|---:|---:|
| `ln_RevPAR_clean` | 34,154 | 4.261 | 4.303 | 0.704 | 0.496 |
| `ln_RevPAR_clean_w` | 34,154 | 4.262 | 4.303 | 0.654 | 0.428 |
| `d_ln_RevPAR` | 33,488 | 0.003 | -0.004 | 0.397 | 0.158 |
| `sim_mean` | 34,765 | 0.294 | 0.290 | 0.044 | 0.002 |
| `ln_recent_volumn` | 34,791 | 2.714 | 2.639 | 0.391 | 0.152 |
| `recent_sd` | 34,765 | 1.122 | 1.165 | 0.392 | 0.154 |
| `rating_last_5` | 34,791 | 3.866 | 4.000 | 1.085 | 1.176 |
| `ln_lag_volumn_acc` | 34,226 | 5.543 | 5.574 | 1.204 | 1.449 |
| `lag_recent_volumn` | 34,226 | 16.639 | 14.000 | 10.134 | 102.695 |
| `lag_avg_rating_acc` | 34,226 | 3.947 | 4.017 | 0.507 | 0.257 |
| `lag_sd_acc` | 34,199 | 1.095 | 1.104 | 0.231 | 0.054 |
| `ln_avg_com_RevPAR` | 34,791 | 4.288 | 4.266 | 0.743 | 0.552 |
| `ln_lag_RevPAR_clean` | 33,617 | 4.265 | 4.305 | 0.696 | 0.485 |
| `star_class` | 17,063 | 3.032 | 3.000 | 0.676 | 0.456 |
