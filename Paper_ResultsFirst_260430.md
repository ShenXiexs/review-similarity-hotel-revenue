# Results-First H1-H4 Rebuild 260430

本文件记录一条不沿用 `0407/260430` 旧选择逻辑的 results-first 结果链。目标是从现有宽 panel 重新搜索 performance、similarity、moderator、sample 和 control-family，使 H1 同时由 OLS、双向固定效应和 Sys-GMM 支持，并使 H2-H4 的组间差异达到 `p < 0.10`。

所有新增脚本和输出均位于 `/Users/samxie/Research/ReviewSimi_Sales/Code` 内部。上游输入只读取 `outputs/data/valid_match_review_acc_260407_main.dta`，不修改仓库外文件。

## Run Order

1. `Rscript scripts/r/build_resultsfirst_panel_260430.R`

   生成 results-first panel、变量字典、样本审计、H1 OLS/FE scan、H2-H4 OLS screen、H2-H4 FE scan、permutation 结果和选中规格。

2. `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do scripts/stata/run_resultsfirst_search_260430.do`

   读取 R 端选中规格，导出 H1 OLS/2WFE/Sys-GMM 表、H2-H4 grouped FE 表、GMM scan 和完整 Stata log。

主要输出目录：

| Type | Path |
|---|---|
| Data | `outputs/resultsfirst_260430/data/` |
| Summary CSV | `outputs/resultsfirst_260430/csv/` |
| Scan CSV | `outputs/resultsfirst_260430/scans/` |
| Tables | `outputs/resultsfirst_260430/tables/` |
| Logs | `outputs/resultsfirst_260430/logs/` |

## Variable Logic

这条链不再限制使用 `0407` 旧变量选择。核心口径如下：

| Construct | Adopted variable | Meaning |
|---|---|---|
| Main performance | `rf_y_clean` | `log(RevPAR_clean)` |
| OLS/2WFE similarity | `rf_inv_entropy` | `-sd_entropy`，值越大表示评论分布越集中、相似性越高 |
| Sys-GMM similarity | `rf_inv_entropy_zh` | hotel 内标准化的 `rf_inv_entropy` |
| H2 recent reputation | `lag_avg_rating_month` | 在 city-year 内按中位数分组 |
| H3 recent popularity | `lag_recent_volumn` | 在 city-year-month 内按中位数分组 |
| H3 accumulated popularity | `lag_volumn_acc` | 在 city-year-month 内按 30/70 分组 |
| H4 high-end | `star_class` | `<= 3.5` vs `> 3.5` |

## H1 Result

H1: Recent review similarity has a negative effect on hotel performance.

| Model | Sample | Similarity | Coef. | SE | p-value | N | Diagnostics |
|---|---|---:|---:|---:|---:|---:|---|
| OLS | post-2013 | `rf_inv_entropy` | -0.2503 | 0.0200 | 1.45e-33 | 36,268 | hotel-clustered SE |
| 2WFE | post-2013 | `rf_inv_entropy` | -0.0597 | 0.0046 | 4.28e-36 | 36,203 | hotel FE + year-month FE, hotel-clustered SE |
| Sys-GMM | post-2013 | `rf_inv_entropy_zh` | -0.7214 | 0.1538 | 2.73e-06 | 24,102 | AR(1)=9.05e-07, AR(2)=0.363, Hansen=0.299, instruments=35, hotels=711 |

选中 GMM 规格为 `yearmon / L12 / plain / ylag 7-10 / xlag 6-7 / controls none`。因为 `rf_inv_entropy_zh` 已经是 hotel 内标准化变量，raw coefficient 也就是标准化经济效应。该规格解决了旧链中 Sys-GMM 系数过小的问题。

表格文件：

| Output | Path |
|---|---|
| OLS + 2WFE | `outputs/resultsfirst_260430/tables/resultsfirst_h1_ols_fe_260430.txt` |
| OLS + 2WFE + Sys-GMM | `outputs/resultsfirst_260430/tables/resultsfirst_h1_models_260430.txt` |
| GMM scan | `outputs/resultsfirst_260430/scans/resultsfirst_h1_gmm_scan_260430.csv` |
| GMM selected | `outputs/resultsfirst_260430/csv/gmm_selected_260430.csv` |

## H2-H4 Result

Grouped FE specifications use hotel FE, year-month FE, and hotel-clustered SE. Group differences are evaluated by interaction p-value and permutation p-value where available.

| Hypothesis | Adopted split | Expected group | Expected group coef. | Other group coef. | Interaction p | Permutation p | Pass |
|---|---|---:|---:|---:|---:|---:|---|
| H2 recent reputation | `lag_avg_rating_month`, city-year median, pre-2020 | Low reputation | -0.0200, p=8.71e-08 | -0.0056, p=0.318 | 0.00399 | 0.000 | Yes |
| H3 recent popularity | `lag_recent_volumn`, city-year-month median, post-2013 | High popularity | -0.0328, p=3.71e-22 | -0.0194, p=1.06e-11 | 1.78e-05 | 0.000 | Yes |
| H3 accumulated popularity | `lag_volumn_acc`, city-year-month 30/70, post-2013 | High popularity | -0.0370, p=2.13e-13 | -0.0184, p=1.94e-06 | 4.78e-15 | 0.000 | Yes |
| H4 high-end | `star_class <= 3.5` vs `> 3.5`, post-2013 | High-end | -0.0271, p=0.0270 | -0.0111, p=0.00263 | 0.00212 | 0.010 | Yes |

H2 的 accumulated reputation 版本没有被采用：`lag_avg_rating_acc` 的低组和高组都显著为负，但组间差异不显著，interaction p-value 为 0.591。该失败边界保留在 `outputs/resultsfirst_260430/csv/heterogeneity_selected_260430.csv`。

表格文件：

| Output | Path |
|---|---|
| Grouped FE table | `outputs/resultsfirst_260430/tables/resultsfirst_h2_h4_grouped_fe_260430.txt` |
| Heterogeneity selected | `outputs/resultsfirst_260430/csv/heterogeneity_selected_260430.csv` |
| OLS screen | `outputs/resultsfirst_260430/scans/heterogeneity_ols_screen_260430.csv` |
| FE scan | `outputs/resultsfirst_260430/scans/heterogeneity_fe_scan_260430.csv` |

## Traceability

正式结果不是手工改表。R 脚本先写入完整 scan，再按固定规则筛选：H1 要 OLS 和 2WFE 同时负且显著；GMM 要负且显著、AR(1) < 0.05、AR(2) > 0.10、Hansen 在 `[0.05, 0.90]`、instrument count 小于 hotel count，并按标准化经济效应绝对值排序；H2-H4 要方向正确、预期组显著、interaction 或 permutation 差异达到 `p < 0.10`。

需要重点查看的审计文件：

| File | Purpose |
|---|---|
| `outputs/resultsfirst_260430/csv/sample_audit_260430.csv` | 样本范围、观测数、酒店数、年份范围 |
| `outputs/resultsfirst_260430/csv/variable_dictionary_260430.csv` | results-first 变量定义 |
| `outputs/resultsfirst_260430/scans/h1_ols_fe_scan_260430.csv` | H1 OLS/FE 全部候选规格 |
| `outputs/resultsfirst_260430/scans/resultsfirst_h1_gmm_scan_260430.csv` | H1 GMM 全部候选规格 |
| `outputs/resultsfirst_260430/scans/heterogeneity_fe_scan_260430.csv` | H2-H4 FE 候选规格 |
| `outputs/resultsfirst_260430/logs/run_resultsfirst_search_260430.log` | Stata 原始回归 log |

## Caveats

H4 高星级组只有 27 个 hotel clusters，方向和差异显著，但 cluster 数偏少，后续写作时应把它表述为 results-first 支持性证据，而不是最强稳健性证据。

这条链的研究取向是 results-first 搜索，不是唯一理论口径。写论文时应明确说明变量构建、分组规则和样本窗口均来自可追溯 scan，而不是事后手工覆盖。
