# Review_Simi_Sales

这个仓库保留 `outputs/core_simi_260501/research/archive/Paper_Results_260407.md` 对应的原结果复现链，并新增围绕核心 `sim_mean` 变量的 H1-H4 复现链。目标是把“主结果文稿、脚本、数据、扫描结果、回归表、原始 log”整理成清晰、可追溯的项目结构。

## 目录结构

- `outputs/core_simi_260501/research/`
  研究文档统一放在这里，并按 `plans/`、`results/`、`archive/`、`reference/`、`figures/` 分类。

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

1. 先看 `outputs/core_simi_260501/research/archive/Paper_Results_260407.md`
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

- 只保留归档结果文稿实际引用或复现所需的文件。
- 删除旧版草稿、过时探索脚本、无关参考资料和重复输出。
- 输出文件按照“数据 / 摘要结果 / 扫描结果 / 回归表 / 原始日志”分层保存。

## 关键入口

- 结果文稿：`outputs/core_simi_260501/research/archive/Paper_Results_260407.md`
- 主数据处理：`scripts/r/Review_Simi_260325.Rmd`
- 主回归输入数据：`outputs/data/valid_match_review_acc_260407_main.dta`
- Core-simi 结果稿：`outputs/core_simi_260501/research/results/Paper_CoreSimi_Results_260501.md`
- Core-simi R 构建脚本：`scripts/r/build_core_simi_panel_260501.R`
- Core-simi Stata 回归脚本：`scripts/stata/run_core_simi_tables_260501.do`

## Hypothesis 结果链 260430

新增的 `outputs/core_simi_260501/research/archive/Paper_Hypothesis_Results_260430.md` 是围绕 `outputs/paper/ref-results.pdf` 重建 H1-H4 的独立结果链，不覆盖原 `260407` 输出。

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
- H4 方向正确但当前结果链未达到显著复现标准，详见 `outputs/core_simi_260501/research/archive/Paper_Hypothesis_Results_260430.md`。

## Core-Simi 结果链 260501

`outputs/core_simi_260501/research/results/Paper_CoreSimi_Results_260501.md` 是一条锁定核心 review similarity 变量 `sim_mean` 的独立搜索链。它只把 `outputs/data/valid_match_review_acc_260407_main.dta` 当作宽 panel 输入，允许搜索 performance、control-family、moderator、sample 和分组规则，但 H1-H4 的主解释变量始终是 `sim_mean`。

运行顺序：

1. `Rscript scripts/r/build_core_simi_panel_260501.R`
   生成 `outputs/core_simi_260501/data/core_simi_panel_260501.dta`、变量字典、样本审计、H1 OLS/FE scan、H2-H4 screen/FE scan 和选中规格。

2. `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do scripts/stata/run_core_simi_tables_260501.do`
   读取 R 端输出，导出 H1 OLS/2WFE/Sys-GMM、H2-H4 grouped FE 表、GMM scan 和完整 Stata log。

新增输出统一放在：

- `outputs/core_simi_260501/data/`
- `outputs/core_simi_260501/csv/`
- `outputs/core_simi_260501/scans/`
- `outputs/core_simi_260501/tables/`
- `outputs/core_simi_260501/logs/`

当前状态：

- H1-H4 的 review similarity 主解释变量固定为 `sim_mean`。
- H1 的 OLS、双向固定效应和 Sys-GMM 系数均为负且 p<0.05；但 Sys-GMM 的 Hansen p-value 过低，详见 `outputs/core_simi_260501/research/results/Paper_CoreSimi_Results_260501.md`。
- H3 的异质性差异通过 `p < 0.10`。
- H2/H4 方向正确，但当前 core-simi 约束下组间差异未显著通过。
