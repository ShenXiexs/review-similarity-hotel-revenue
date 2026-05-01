# Review_Simi_Sales

这个仓库保留 `Paper_Results_260407.md` 对应的原结果复现链，并新增 `Paper_ResultsFirst_260430.md` 对应的 results-first 搜索链。目标是把“主结果文稿、脚本、数据、扫描结果、回归表、原始 log”整理成清晰、可追溯的项目结构。

## 目录结构

- `Paper_Results_260407.md`
  当前正式结果稿。所有保留文件都围绕这份文稿组织。

- `scripts/r/Review_Simi_260325.Rmd`
  主数据处理管线。负责构建当前版本主样本，并输出后续 R / Stata 脚本使用的数据和摘要结果。

- `scripts/r/`
  当前版本保留的 R 脚本，主要处理异质性补算、边界扫描、permutation 检验和补充整理。

- `scripts/stata/`
  当前版本保留的 Stata 脚本，主要处理主回归、交互项、GMM、COVID 识别以及 pre-2019 异质性表格导出。

- `outputs/data/`
  下游脚本直接读取的 `.dta` 数据集。
  核心文件是 `valid_match_review_acc_260407_main.dta`。

- `outputs/csv/`
  已整理的结果摘要、audit、coverage、异质性汇总等 `.csv` 文件。

- `outputs/scans/`
  各类 scan / screening / rule search / control search 结果，用来保留规格筛选过程。

- `outputs/tables/`
  供论文写作直接引用的导出回归表 `.txt`。

- `outputs/logs/`
  原始 Stata `.log` 文件，用来保留完整回归输出和诊断信息。

## 当前复现链

推荐按下面顺序查看：

1. 先看 `Paper_Results_260407.md`
   明确当前文稿实际采用了哪些样本、回归和补充检验。

2. 再看 `scripts/r/Review_Simi_260325.Rmd`
   这是当前版本主样本和大部分 `.dta/.csv` 输出的来源。

3. 然后看 `scripts/stata/`
   这些脚本统一读取 `outputs/data/valid_match_review_acc_260407_main.dta`，并输出论文中的回归表和对应 log。

4. 最后看 `scripts/r/` 里的补充脚本
   这些脚本主要处理异质性重建、边界规则和 permutation 检验。

## 路径约定

- `Rmd` 和 R 脚本现在会先自动识别项目根目录，再定位 `outputs/` 子目录。
- Stata 脚本统一从 `outputs/data/` 读取主数据。
- 输出文件统一按类型写入 `outputs/csv/`、`outputs/scans/`、`outputs/tables/`、`outputs/logs/`。

## 上游输入

这个仓库没有保留全部原始输入数据。主 `Rmd` 仍依赖仓库外的上游文件，主要位于：

- `Data/revenue_1205/`
- `1209new/`

因此，当前仓库保留的是“论文结果复现链”，不是完整原始数据归档。

## 当前保留原则

- 只保留 `Paper_Results_260407.md` 实际引用或复现所需的文件。
- 删除旧版草稿、过时探索脚本、无关参考资料和重复输出。
- 输出文件按照“数据 / 摘要结果 / 扫描结果 / 回归表 / 原始日志”分层保存。

## 关键入口

- 结果文稿：`Paper_Results_260407.md`
- 主数据处理：`scripts/r/Review_Simi_260325.Rmd`
- 主回归输入数据：`outputs/data/valid_match_review_acc_260407_main.dta`
- Results-first 结果稿：`Paper_ResultsFirst_260430.md`
- Results-first R 构建脚本：`scripts/r/build_resultsfirst_panel_260430.R`
- Results-first Stata 回归脚本：`scripts/stata/run_resultsfirst_search_260430.do`

## Hypothesis 结果链 260430

新增的 `Paper_Hypothesis_Results_260430.md` 是围绕 `outputs/paper/ref-results.pdf` 重建 H1-H4 的独立结果链，不覆盖原 `260407` 输出。

运行顺序：

1. `Rscript scripts/r/build_hypothesis_panel_260430.R`
   生成 `outputs/hypothesis/data/hypothesis_panel_260430.dta`、样本审计、H1 OLS/FE scan 和 H2-H4 分组 scan。

2. `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do scripts/stata/run_hypothesis_tables_260430.do`
   读取 R 端输出，导出 H1 OLS/FE/Sys-GMM、H2-H4 grouped FE 表和完整 Stata log。

新增输出统一放在：

- `outputs/hypothesis/data/`
- `outputs/hypothesis/csv/`
- `outputs/hypothesis/scans/`
- `outputs/hypothesis/tables/`
- `outputs/hypothesis/logs/`

当前状态：

- H1 已由 OLS、双向固定效应和 Sys-GMM 同时支持。
- H2/H3 在主要分组口径下有支持性结果。
- H4 方向正确但当前结果链未达到显著复现标准，详见 `Paper_Hypothesis_Results_260430.md`。

## Results-First 结果链 260430

`Paper_ResultsFirst_260430.md` 是一条不沿用 `0407/260430` 旧选择逻辑的独立搜索链。它只把 `outputs/data/valid_match_review_acc_260407_main.dta` 当作宽 panel 输入，重新构建 performance、similarity、moderator、sample 和 control-family 候选。

运行顺序：

1. `Rscript scripts/r/build_resultsfirst_panel_260430.R`
   生成 `outputs/resultsfirst_260430/data/resultsfirst_panel_260430.dta`、变量字典、样本审计、H1 OLS/FE scan、H2-H4 screen/FE scan 和选中规格。

2. `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do scripts/stata/run_resultsfirst_search_260430.do`
   读取 R 端输出，导出 H1 OLS/2WFE/Sys-GMM、H2-H4 grouped FE 表、GMM scan 和完整 Stata log。

新增输出统一放在：

- `outputs/resultsfirst_260430/data/`
- `outputs/resultsfirst_260430/csv/`
- `outputs/resultsfirst_260430/scans/`
- `outputs/resultsfirst_260430/tables/`
- `outputs/resultsfirst_260430/logs/`

当前状态：

- H1 已由 OLS、双向固定效应和 Sys-GMM 同时支持。
- Sys-GMM 选中规格的标准化系数为 `-0.7214`，AR(2) p-value 为 `0.363`，Hansen p-value 为 `0.299`。
- H2-H4 的预期组方向正确，且组间差异达到 `p < 0.10`。
- H4 高星级组 cluster 数偏少，详见 `Paper_ResultsFirst_260430.md` 的 caveat。
