# Code Research Map

## Three Layers

当前项目建议固定按三层理解：

1. 主结果层
   `sim_mean / ARS` 对 `RevPAR` 的主效应、异质性、COVID、GMM、稳健性。

2. 故事扩展层
   `scripts/stata/run_core_simi_story_exploration_260524.do` 对 Route A/B/C/D 的系统化扩展。

3. 构数层
   management response、review sentiment、profile merge、alternative ARS、scope ARS 的面板增强脚本。

## Core Data

### 主面板

- `outputs/core_simi_260501/data/core_simi_panel_260501.dta`
  - core-simi 主结果链基础面板
  - 关键内容：`sim_mean`、`RevPAR_clean`、`ln_RevPAR_clean`、rating/volume/recent controls、竞争压力变量、sample flags、chain variables、star variables、H2-H4 groups

- `outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta`
  - story exploration 主输入
  - 在主面板基础上加入：
    - management response 月度与滞后变量
    - alternative ARS / scope ARS
    - review sentiment 月度与滞后变量
    - replied-review targeting variables

- `outputs/hypothesis/data/hypothesis_panel_260430.dta`
  - 围绕旧 H1-H4 的独立假设链
  - 更适合复现旧假设，不是当前扩展研究的主面板

### 辅助增强面板

- `outputs/core_simi_260501/data/management_response_text_monthly_260524.dta`
- `outputs/core_simi_260501/data/review_sentiment_monthly_260526.dta`
- `outputs/core_simi_260501/data/core_simi_panel_260501_with_altars.dta`
- `outputs/core_simi_260501/data/core_simi_panel_260501_with_scope_ars.dta`

## Core Do Files

- `scripts/stata/run_core_simi_tables_260501.do`
  - R 端 scan 选中规格的定稿导出器
  - 输出 H1-H4 OLS / 2WFE / GMM / grouped FE 表

- `scripts/stata/run_core_simi_explicit_regressions_260501.do`
  - 当前主结果层最完整的显式 do 文件
  - 覆盖 H1-H6、COVID、alternative ARS、scope robustness

- `scripts/stata/run_core_simi_story_exploration_260524.do`
  - 当前两条导师路径的主承载文件
  - 已经覆盖：
    - Route A：ARS 主效应 + COVID + 产品边界
    - Route B：评论量 / 评论资产 × ARS
    - Route C：management response / reply engagement
    - Route D：review sentiment × ARS

## Core Construction Scripts

- `scripts/r/build_core_simi_panel_260501.R`
- `scripts/r/build_management_response_text_panel_260524.R`
- `scripts/r/build_review_sentiment_panel_260526.R`
- `scripts/r/build_alt_ars_260509.R`
- `scripts/r/build_scope_ars_260509.R`

## Route 1: ARS As Main Effect

### 已经有的内容

- 主效应：`sim_mean -> ln_RevPAR_clean / RevPAR_clean`
- 模型：OLS、2WFE、Sys-GMM
- 经典异质性：H2 reputation、H3 popularity、H4 star / high-end
- 扩展异质性：H5 recent review dispersion、H6 chain vs independent
- 时间边界：pre-COVID / 2020 / 2020-2022
- 产品边界：`hotel_profile_TP.csv` merge 后的星级、质量、服务、价格、规模、rank、amenities、style、`travelers_choice_flag`
- 算法稳健性：`sim_mean_std_hotel`、`ars_roll_10`、`ars_jsd_sim`、`sim_mean_5/10/15/20/30`

### 可以直接继续做的主题

- 市场边界 / 竞争压力
  - 可直接用：`high_comp_zip_full`、`high_comp_city_full`、`zip_n_*`、`city_n_*`、`comp_zip_mean_excl_*`、`comp_city_mean_excl_*`、`gap_zip_mean_*`、`gap_city_mean_*`、`price_gap`
  - 研究问题：
    - 竞争越激烈，ARS 的负效应是否更强
    - 相对同城/同 zip 的市场定位偏离越大，ARS 是否更重要

- 产品边界进一步系统化
  - vertical quality：`star_class_final_raw`、`tp_quality_index`、`tp_service_quality`、`tp_rank_pct`
  - horizontal differentiation：`amenity_*`、`style_*`、`tp_amenity_count`
  - price/scale：`ln_tp_price_mid`、`ln_tp_room`、`ln_tp_review_count`

- 平台/评论环境边界
  - 可直接用：`sent_avg_*`、`sent_net_pos_*`、`sent_neg_share_*`、`recent_sd`、`sd_acc`、`rating_momentum`、`review_freshness`

- 经营组织边界
  - 可直接用：`chain`、`independent`、`chain_small`、`chain3_small`

### 2026-06-05 快速结果：市场边界

对应脚本：`scripts/stata/run_routeA_market_boundaries_260605.do`

- 主效应稳健：`sim_mean` 在 9 个市场边界规格里几乎都保持负向，且多数规格显著，系数大致在 `-0.139` 到 `-0.166`。
- 高竞争 dummy 交互没有出来：
  - `high_comp_zip_full × ARS` 不显著
  - `high_comp_city_full × ARS` 也没有额外差异
- 市场厚度交互没有出来：
  - `zip_n_full × ARS` 不显著
  - `city_n_full × ARS` 不显著
- 竞争者表现与相对定位交互目前也不强：
  - `ln_comp_zip_mean_excl_full × ARS` 不显著
  - `ln_comp_city_mean_excl_full × ARS` 不显著
  - `gap_zip_mean_full × ARS` 不显著
  - `gap_city_mean_full × ARS` 不显著
  - `price_gap × ARS` 不显著

当前解释：

- 这轮 Route A 市场边界的第一结论不是“哪条边界显著通过”，而是“ARS 的负向主效应对不同市场结构度量都比较稳”。
- 如果后续还要继续做市场边界，优先把这一块写成 robustness / boundary exploration，而不是主文的强异质性证据。

## Route 2: ARS As Moderator

### 已经有的内容

- 评论量 × ARS
  - `ln_recent_volumn × sim_mean`
  - `volume_momentum × sim_mean`
  - `ln_lag_volumn_acc × sim_mean`
  - `ln_words_acc × sim_mean`
  - threshold / nonlinear 版本已做

- management response × ARS
  - `lag_mr_any`
  - `lag_mr_rate`
  - `lag_mr_count`
  - `ln_lag_mr_words`
  - `ln_lag_mr_avg_words`
  - `lag_mr_quick7_share`
  - `lag_mr_invite_share`
  - `lag_mr_recovery_share`
  - `lag_mr_positive_share`

- reply 文本三重交互
  - `volume × ARS × reply-style`
  - quick / positive / recovery / avg-length 已做

- reply targeting
  - `lag_mr_rep_neg_share`
  - `lag_mr_rep_low_share`
  - `lag_mr_rep_complaint_share`
  - `lag_mr_rep_service_share`
  - `lag_mr_rep_room_share`
  - `lag_mr_rep_clean_share`
  - `lag_mr_rep_value_share`

- mechanism DV
  - 后续 `review volume`
  - 后续 `ARS`
  - 后续 `RevPAR`

### 可以直接继续做的主题

- engagement 强度细分
  - coverage：`lag_mr_any`、`lag_mr_rate`
  - effort：`lag_mr_count`、`ln_lag_mr_words`、`ln_lag_mr_avg_words`
  - speed：`lag_mr_quick7_share`、`lag_mr_quick30_share`、`lag_mr_avg_resp_days`
  - tone：`lag_mr_thanks_share`、`lag_mr_apology_share`、`lag_mr_positive_share`、`lag_mr_negtone_share`
  - personalization / standardization：`lag_mr_personal_share`、`lag_mr_template_share`、`lag_mr_mgr_share`

- 被回复对象选择策略
  - 回复低分评论
  - 回复负向评论
  - 回复 complaint-heavy 评论

- 评论生产机制
  - 回复是否提升下月评论量
  - 回复是否改变下月 ARS
  - 回复是否改变下月 sentiment

### 2026-06-05 快速结果：回复对象策略

对应脚本：`scripts/stata/run_routeB_mr_targeting_260605.do`

- revenue moderation 这块目前还不强：
  - `complaint share × ARS` 不显著
  - `service share × ARS` 不显著
  - `room share × ARS` 不显著
  - `clean share × ARS` 不显著
  - `value share × ARS` 不显著
  - `reply rate × ARS × complaint share` 三重交互也不显著
- 但 ARS 主效应本身仍然稳：
  - 在所有 targeting revenue 规格里，`sim_mean` 都保持显著负向，系数大致在 `-0.147` 到 `-0.190`
- mechanism 这块更有信息量：
  - `lag_mr_rep_complaint_share` 预测后续评论量下降，但预测后续 `ARS` 上升
  - `lag_mr_rep_clean_share` 预测后续评论量下降，且后续 sentiment 更负
  - `lag_mr_rep_value_share` 预测后续评论量下降、后续 `ARS` 下降、后续 sentiment 更负
  - `lag_mr_rep_room_share` 预测后续 `ARS` 明显下降
  - `lag_mr_rate` 预测后续评论量下降
  - `lag_mr_count` 与 `ln_lag_mr_words` 则预测后续评论量上升；其中 `ln_lag_mr_words` 同时预测后续 `ARS` 上升、后续 sentiment 更正向

当前解释：

- “回复谁”对当期 revenue slope 的调节暂时还没有打出来。
- 但“回复对象策略”确实会影响后续 review production，尤其是：
  - 后续评论量
  - 后续 ARS
  - 部分情况下的后续 sentiment
- 因此这条更适合继续往“management response 改变后续评论生产环境”去写，而不是直接写成“management response 改变当期 ARS 对 revenue 的边际效应”。

## Data Boundaries

### 已确认可继续利用的来源

- `full-data/hotel_profile_TP.csv`
  - `hotel_id_ta` 是数值型 `HotelID`
  - 后续 profile merge 默认沿用当前转换规则

- `full-data/tp_data_new.csv`
  - 还可继续用：`help_votes`、`contributions`、`trip_type`、`stay_date`、`quality`、`review_title`、`review_text`、`propertys`、`room_features`、`room_type`、`all_languages`、`walkers`、`restaurants`、`attractions`

- `full-data/allTPreview_sample1000.csv`
  - 可继续做 sample1000 级别的 review/response 试验构数

### 当前缺口

- `full-data/allTPreview.csv` 当前不在本机目录

这意味着：

- full-sample MR / sentiment 增强面板已经存在，可以继续做回归
- 若要新增 full-sample review-level / response-level 构数，只能：
  - 继续用已有增强 panel
  - 或先做 sample1000 试验
  - 或补回 `allTPreview.csv`

## Script Style Defaults

后续新增 `do` 文件固定遵循以下规则：

- 每个模块前写 1-3 行研究注释
- 所有正式回归显式写出：
  - 因变量
  - 核心自变量
  - 交互项
  - 控制变量
  - 固定效应
  - 聚类方式
- 不把关键 RHS 藏进 wrapper / program
- 可以用少量局部宏保存通用控制组，但模型行必须一眼能读懂

## Current New Files

本轮新增的研究脚本：

- `scripts/stata/run_routeA_market_boundaries_260605.do`
- `scripts/stata/run_routeB_mr_targeting_260605.do`

二者都按“显式回归 + 注释解释”的风格撰写。
