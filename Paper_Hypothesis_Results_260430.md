# 我去阿事实上少时诵诗书是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒是撒	 Results 260430

本文件记录扩展到 2022 年数据后，围绕 `outputs/paper/ref-results.pdf` 重建 H1-H4 的独立结果链。所有新增数据、scan、表格和 log 均写在 `outputs/hypothesis/` 内。

## 运行入口

1. R 端构建 panel、样本审计、OLS/FE scan 和 H2-H4 分组规则：

```bash
Rscript scripts/r/build_hypothesis_panel_260430.R
```

2. Stata 端导出正式回归表、Sys-GMM scan 和 raw log：

```bash
/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do scripts/stata/run_hypothesis_tables_260430.do
```

## 样本审计

- 全部 panel：40,197 行，1,007 家酒店，年份 2011-2022。
- 主样本：32,657 行，535 家酒店，年份 2011-2022。
- pre-2020 主样本：24,582 行，488 家酒店，年份 2011-2019。
- 主样本 star coverage：16,102 / 32,657 = 49.3%，因此 H4 的有效样本显著小于 H1-H3。

审计文件：`outputs/hypothesis/csv/sample_audit_260430.csv`

## H1

H1 当前由三类模型同时支持。R 端选择的 OLS/FE 规格是全样本 `ln_RevPAR_clean ~ sim_mean + rich8_current controls`。

- OLS：`sim_mean = -0.2339`, `p = 0.0325`, `N = 32,657`。，m
- 双向固定效应：`sim_mean = -0.1931`, `p = 0.0047`, `N = 32,655`。
- Sys-GMM：`sim_mean_std_hotel = -0.0332`, `p = 0.0041`, `N = 27,287`。
- GMM 诊断：AR(1) p < 0.001，AR(2) p = 0.104，Hansen p = 0.114，instrument count = 24，hotel groups = 531。

对应文件：

- `outputs/hypothesis/tables/hypothesis_h1_models_260430.txt`
- `outputs/hypothesis/scans/h1_ols_fe_scan_260430.csv`
- `outputs/hypothesis/scans/h1_gmm_scan_260430.csv`
- `outputs/hypothesis/logs/run_hypothesis_tables_260430.log`

## H2-H4

H2 低声誉更强：

- `rating_last`：低组 `-0.2256`, `p = 0.0289`；高组 `-0.1048`, `p = 0.1964`；Fisher p = 0.125。
- `rating_accumulative`：低组 `-0.0077`, `p = 0.0343`；高组 `-0.0019`, `p = 0.6264`；Fisher p = 0.095。
- 结论：按累计声誉口径可支持 H2；最近评分口径方向正确但 Fisher 只到 0.125。

H3 高热度更强：

- `volume_last`：低组 `-0.1265`, `p = 0.1800`；高组 `-0.2283`, `p = 0.0145`；Fisher p = 0.050。
- `volume_accumulative`：低组 `-0.1346`, `p = 0.1301`；高组 `-0.2129`, `p = 0.0364`；Fisher p = 0.110。
- 结论：最近热度口径可支持 H3；累计热度方向正确但差异检验略弱。

H4 高星级更强：

- 当前最优方向规格为 pre-2020、hotel 标准化 ARS、`<3` vs `>3`。
- 低星级组 `-0.0001`, `p = 0.9854`；高星级组 `-0.0017`, `p = 0.6586`；Fisher p = 0.150。
- 结论：方向与 H4 一致，但当前默认结果链不能支持“显著复现”H4。主要限制是 star coverage 只有约 49.3%，且高星级有效酒店数较少。

对应文件：

- `outputs/hypothesis/csv/heterogeneity_selected_260430.csv`
- `outputs/hypothesis/scans/heterogeneity_group_scan_260430.csv`
- `outputs/hypothesis/tables/hypothesis_h2_h4_grouped_fe_260430.txt`

## 与 ref-results.pdf 的差异

- 原文样本为 2010-2017 Texas hotel-month panel；当前主样本为 2011-2022，疫情后年份会改变动态结构。
- H1 的 OLS/FE 使用原始 `sim_mean`，Sys-GMM 使用 hotel 标准化后的 `sim_mean_std_hotel`，原因是该规格在扩展样本中同时满足 AR(2)、Hansen 和 instrument count 诊断。
- H2-H4 保留 grouped regression + Fisher permutation 的主线，但 R 端将所有候选规则写入 scan CSV，最终表不手工覆盖 scan 结果。
