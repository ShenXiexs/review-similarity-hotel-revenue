# Review_Simi_Sales

这个仓库目前只保留 `Paper_Results_260407.md` 对应的一条结果复现链，目标是把“主结果文稿、脚本、数据、扫描结果、回归表、原始 log”整理成一套单一且清晰的项目结构。

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
