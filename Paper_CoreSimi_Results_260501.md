# Core-Simi H1-H4 Results 260501

本文件记录一条锁定核心 review similarity 算法变量 `sim_mean` 的 H1-H4 重做结果链。`sim_mean` 是唯一正式 similarity 主解释变量；没有使用 entropy、HHI、`rf_inv_entropy` 或其他替代 similarity。控制变量、moderator、样本窗口和分组规则允许搜索，但所有正式回归均包含非空控制组。

## Run Order

1. `Rscript scripts/r/build_core_simi_panel_260501.R`

   生成 core-simi panel、样本审计、H1 OLS/FE scan、H2-H4 OLS screen、H2-H4 FE scan、permutation scan 和选中规格。

2. `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do scripts/stata/run_core_simi_tables_260501.do`

   读取 R 端输出，导出 H1 OLS/2WFE/Sys-GMM、H2-H4 grouped FE、interaction 表和完整 Stata log。

主要输出目录：

| Type | Path |
|---|---|
| Data | `outputs/core_simi_260501/data/` |
| Summary CSV | `outputs/core_simi_260501/csv/` |
| Scan CSV | `outputs/core_simi_260501/scans/` |
| Tables | `outputs/core_simi_260501/tables/` |
| Logs | `outputs/core_simi_260501/logs/` |

## Fixed Similarity And Controls

正式 H1-H4 的 similarity 主解释变量固定为：

| Variable | Meaning |
|---|---|
| `sim_mean` | 已有 R 管线生成的 10-review review similarity / ARS 核心变量，不重算、不替换 |

控制变量候选均为非空控制组，包括 `rich8_current`、`quality6`、`base4_acc`、`base4_month`、`lean3`、`momentum_plus`。每个 scan 和最终结果都记录 `control_family` 和具体变量列表。

## H1 Result

H1: recent review similarity has a negative effect on hotel performance.

最终 H1 同一样本、同因变量、同控制组规格为：

| Field | Value |
|---|---|
| Sample | `focus50` |
| Dependent variable | `ln_RevPAR_clean` |
| Similarity | `sim_mean` |
| Controls | `rich8_current` |

| Model | Coef. | SE | p-value | Std. effect | N | Diagnostics |
|---|---:|---:|---:|---:|---:|---|
| OLS | -0.2318 | 0.1038 | 0.0259 | -0.0104 | 36,151 | hotel-clustered SE |
| 2WFE | -0.1406 | 0.0650 | 0.0309 | -0.0063 | 36,145 | hotel FE + year-month FE, hotel-clustered SE |
| Sys-GMM | -0.2232 | 0.1089 | 0.0404 | -0.0100 | 29,654 | AR(1)=2.30e-06, AR(2)=0.674, Hansen=0.00128, instruments=26, hotels=653 |

Interpretation: OLS、2WFE 和 Sys-GMM 的 `sim_mean` 系数均为负且 p<0.05。Sys-GMM 的 AR(2) 和 instrument count 可接受，但 Hansen p-value 过低，因此 H1 的动态 GMM 结果只能作为方向和显著性支持，不能写成“诊断完全通过”的 GMM 结果。

## H2-H4 Result

H2-H4 正式表均使用 grouped 2WFE：hotel FE、year-month FE、hotel-clustered SE。差异检验来自 pooled interaction FE 和 permutation scan。

| Hypothesis | Adopted moderator | Split | Control | Expected group | Expected coef. | Other coef. | Interaction p | Permutation p | Pass |
|---|---|---|---|---|---:|---:|---:|---:|---|
| H2 low reputation stronger | `lag_avg_rating_acc` | `ym_4060`, `focus100` | `quality6` | Low reputation | -0.2145, p=0.0467 | -0.0936, p=0.335 | 0.541 | 0.340 | No |
| H3 popular stronger | `volume_momentum` | `ym_median`, `focus50` | `rich8_current` | High popularity | -0.1658, p=0.0279 | -0.0962, p=0.255 | 0.0427 | 0.080 | Yes |
| H4 high-end stronger | `ln_lag_avg_com_RevPAR` | `cityy_median`, `exclude2020` | `rich8_current` | High-end proxy | -0.1388, p=0.0529 | -0.0086, p=0.917 | 0.281 | 0.100 | No |

Interpretation:

- H2 方向正确，低声誉组显著为负，但组间差异不显著。
- H3 通过：高热度组更负且显著，interaction p-value 和 permutation p-value 都达到 `p < 0.10`。
- H4 方向正确，高端代理组边际显著为负，但差异检验没有严格小于 `0.10`；当前 scan 下不能写成显著复现。

## Traceability

关键文件：

| File | Purpose |
|---|---|
| `outputs/core_simi_260501/csv/h1_final_260501.csv` | H1 同规格 OLS/2WFE/Sys-GMM 汇总 |
| `outputs/core_simi_260501/csv/gmm_selected_260501.csv` | H1 GMM 选中规格 |
| `outputs/core_simi_260501/csv/heterogeneity_selected_260501.csv` | H2-H4 选中规格 |
| `outputs/core_simi_260501/scans/h1_ols_fe_scan_260501.csv` | H1 OLS/FE 全部候选 |
| `outputs/core_simi_260501/scans/h1_gmm_scan_260501.csv` | H1 GMM 全部候选 |
| `outputs/core_simi_260501/scans/heterogeneity_ols_screen_260501.csv` | H2-H4 OLS screen |
| `outputs/core_simi_260501/scans/heterogeneity_fe_scan_260501.csv` | H2-H4 FE refinement |
| `outputs/core_simi_260501/scans/heterogeneity_perm_scan_260501.csv` | H2-H4 permutation checks |
| `outputs/core_simi_260501/logs/run_core_simi_tables_260501.log` | Stata 原始 log |

## Current Boundary

在“`sim_mean` 不可替换、正式模型必须有控制变量”的约束下，当前结果链没有实现 H2 和 H4 的显著差异复现，也没有找到 Hansen 通过的 Sys-GMM 规格。最重要的可用结果是：H1 三类模型方向一致且显著，H3 组间差异通过；H2/H4 是方向性支持但差异检验未通过。
