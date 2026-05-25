library(data.table)

RUN_ID <- "260524"

detect_project_dir <- function() {
  candidates <- unique(c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE),
    "/Users/samxie/Research/ReviewSimi_Sales/Code"
  ))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "Paper_Results_260407.md")) &&
        dir.exists(file.path(candidate, "scripts")) &&
        dir.exists(file.path(candidate, "outputs"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Cannot locate project root.")
}

fmt_num <- function(x, digits = 4) {
  ifelse(is.na(x), "", formatC(x, format = "f", digits = digits))
}

fmt_p <- function(x) {
  fifelse(is.na(x), "", fifelse(x < 0.001, "<0.001", formatC(x, format = "f", digits = 3)))
}

pct_from_log_coef <- function(x, digits = 2) {
  ifelse(is.na(x), "", paste0(formatC(100 * (exp(x) - 1), format = "f", digits = digits), "%"))
}

clean_term <- function(x) {
  replacements <- c(
    "z_sim_mean" = "ARS(z)",
    "z_sim_mean_std_hotel" = "ARS within-hotel std",
    "z_ars_jsd_sim" = "JSD ARS(z)",
    "z_sim_mean_10" = "ARS scope10(z)",
    "z_sim_mean_20" = "ARS scope20(z)",
    "z_ln_recent_volumn" = "recent volume(z)",
    "z_ln_lag_volumn_acc" = "cumulative volume(z)",
    "z_lagvol_over58" = "cumulative volume above 5.8(z)",
    "z_ln_words_acc" = "text volume stock(z)",
    "z_ln_lag_mr_words" = "lag MR text words(z)",
    "z_lag_mr_invite_share" = "lag MR invite share(z)",
    "z_lag_mr_positive_share" = "lag MR positive share(z)",
    "z_lag_mr_quick7_share" = "lag MR quick7 share(z)",
    "1.covid2020_2022#c.z_sim_mean" = "ARS x 2020-2022"
  )
  out <- x
  for (nm in names(replacements)) out <- gsub(nm, replacements[[nm]], out, fixed = TRUE)
  out
}

md_table <- function(dt) {
  if (nrow(dt) == 0) return("")
  dt <- copy(dt)
  for (j in names(dt)) set(dt, j = j, value = as.character(dt[[j]]))
  header <- paste0("| ", paste(names(dt), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(dt)), collapse = " | "), " |")
  rows <- apply(dt, 1, function(row) paste0("| ", paste(gsub("\\|", "/", row), collapse = " | "), " |"))
  paste(c(header, sep, rows), collapse = "\n")
}

read_esttab_csv <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- gsub("(^|,)=\\\"", "\\1\\\"", lines, perl = TRUE)
  df <- fread(text = paste(lines, collapse = "\n"), header = FALSE, fill = TRUE, data.table = TRUE)
  df[] <- lapply(df, as.character)
  df[is.na(df)] <- ""
  if (nrow(df) >= 3) {
    header <- as.character(unlist(df[2]))
    header[1] <- "变量"
    header[header == ""] <- paste0("模型", which(header == ""))
    body <- df[-c(1, 2, 3)]
    setnames(body, make.unique(header, sep = "_"))
    return(body)
  }
  df
}

project_dir <- detect_project_dir()
out_root <- file.path(project_dir, "outputs/core_simi_260501")
csv_dir <- file.path(out_root, "csv")
research_dir <- file.path(out_root, "research")
dir.create(research_dir, recursive = TRUE, showWarnings = FALSE)

path_candidates <- file.path(csv_dir, sprintf("story_exploration_candidates_%s.csv", RUN_ID))
path_audit <- file.path(csv_dir, sprintf("management_response_text_audit_%s.csv", RUN_ID))
path_md <- file.path(research_dir, sprintf("core_simi_story_exploration_results_%s.md", RUN_ID))

if (!file.exists(path_candidates)) stop("Missing candidate CSV: ", path_candidates)
if (!file.exists(path_audit)) stop("Missing audit CSV: ", path_audit)

candidates <- fread(path_candidates)
audit <- fread(path_audit)

top_by_route <- function(route_value, n = 12) {
  x <- candidates[route == route_value & !is.na(coef)]
  setorder(x, -story_score, p)
  x <- head(x, n)
  data.table(
    route = x$route,
    model = x$model_id,
    focal = clean_term(x$focal),
    coef = fmt_num(x$coef),
    se = fmt_num(x$se),
    p = fmt_p(x$p),
    N = formatC(x$N, format = "d", big.mark = ","),
    note = x$notes
  )
}

top_a <- top_by_route("A", 10)
top_b <- top_by_route("B", 10)
top_c <- top_by_route("C", 12)

top_c_revenue <- candidates[
  route == "C" &
    depvar == "ln_RevPAR_clean_w199" &
    !is.na(coef) &
    grepl("revenue effect|direct revenue|ARS x MR|Recent volume x ARS x MR", notes)
]
setorder(top_c_revenue, p)
top_c_revenue <- head(top_c_revenue, 12)
top_c_revenue <- top_c_revenue[, .(
  model = model_id,
  focal = clean_term(focal),
  coef = fmt_num(coef),
  `RevPAR含义` = pct_from_log_coef(coef),
  se = fmt_num(se),
  p = fmt_p(p),
  N = formatC(N, format = "d", big.mark = ","),
  note = notes
)]

pick_effect <- function(label, pattern, type) {
  x <- candidates[grepl(pattern, model_id) & !is.na(coef)]
  if (nrow(x) == 0) return(NULL)
  setorder(x, p)
  x <- x[1]
  data.table(
    结果 = label,
    核心项 = clean_term(x$focal),
    系数 = fmt_num(x$coef),
    `RevPAR百分比/边际变化` = pct_from_log_coef(x$coef),
    p = fmt_p(x$p),
    解释 = type
  )
}

econ_effects <- rbindlist(Filter(Negate(is.null), list(
  pick_effect("A: ARS 主效应", "^A_main_z_sim_mean_ln_RevPAR_clean_w199$", "ARS 增加 1 个标准差，RevPAR 约下降该百分比。"),
  pick_effect("A: within-hotel ARS", "^A_main_z_sim_mean_std_hotel_ln_RevPAR_clean_w199$", "同一酒店内部 ARS 高 1 个标准差，RevPAR 约下降该百分比。"),
  pick_effect("A: COVID 边界", "^A_covid_ln_RevPAR_clean_w199$", "疫情期 ARS 斜率相对非疫情期增加该百分点，说明负向效应被削弱。"),
  pick_effect("B: recent volume x ARS", "^B_z_ln_recent_volumn_X_z_sim_mean_ln_RevPAR_clean_w199$", "ARS 高 1 个标准差时，近期评论量对 RevPAR 的边际收益改变该百分点。"),
  pick_effect("B: cumulative volume x ARS", "^B_z_ln_lag_volumn_acc_X_z_sim_mean_ln_RevPAR_clean_w199$", "ARS 高 1 个标准差时，累计评论量对 RevPAR 的边际收益改变该百分点。"),
  pick_effect("B: text volume x ARS", "^B_z_ln_words_acc_X_z_sim_mean_std_hotel_ln_RevPAR_clean_w199$", "ARS 高 1 个标准差时，文本评论存量对 RevPAR 的边际收益改变该百分点。"),
  pick_effect("C: any reply -> revenue", "^C_reply_any_revenue$", "上月有管理回复相对无回复，RevPAR 约变化该百分比；当前不显著。"),
  pick_effect("C: recovery reply -> revenue", "^C_reply_rev_z_lag_mr_recovery_share$", "服务恢复词占比高 1 个标准差，RevPAR 约变化该百分比。"),
  pick_effect("C: quick reply -> revenue", "^C_reply_rev_z_lag_mr_quick7_share$", "快速回复占比高 1 个标准差，RevPAR 约变化该百分比。"),
  pick_effect("C: invite reply x ARS", "^C_ARS_X_z_lag_mr_invite_share$", "邀请再来语气高 1 个标准差时，ARS 对 RevPAR 的斜率增加该百分点。"),
  pick_effect("C: positive reply triple", "^C_recent_triple_z_lag_mr_positive_share$", "积极回复语气高 1 个标准差时，recent volume x ARS 的边际效应改变该百分点。")
)), fill = TRUE)

sig_summary <- candidates[!is.na(coef), .(
  models = .N,
  sig_10 = sum(p < 0.10, na.rm = TRUE),
  sig_05 = sum(p < 0.05, na.rm = TRUE),
  sig_01 = sum(p < 0.01, na.rm = TRUE)
), by = route]
setorder(sig_summary, route)

audit_wide <- audit[, .(metric, value)]

table_files <- list(
  "表 1：Route A ARS 主效应、winsor 与 ARS 替代口径" = file.path(csv_dir, "story_table_a_ars_main_260524.csv"),
  "表 2：Route A 情境调节：评分、市场、产品、COVID" = file.path(csv_dir, "story_table_a_moderators_260524.csv"),
  "表 3：Route B 评论量/文本量与 ARS 调节" = file.path(csv_dir, "story_table_b_volume_ars_260524.csv"),
  "表 4：Route C Management Response 文本特征与交互" = file.path(csv_dir, "story_table_c_mr_text_260524.csv"),
  "表 5：Route C Reply 对 Revenue 的直接效应与 ARS 调节" = file.path(csv_dir, "story_table_c_reply_revenue_260524.csv"),
  "表 6：Route C Management Response 机制结果" = file.path(csv_dir, "story_table_c_mr_mechanisms_260524.csv")
)

table_md <- character()
for (title in names(table_files)) {
  path <- table_files[[title]]
  if (file.exists(path)) {
    table_md <- c(table_md, paste0("### ", title), "", md_table(read_esttab_csv(path)), "")
  }
}

lines <- c(
  "# ARS 双故事线与 Management Response 文本扩展：强结果探索整理",
  "",
  "日期：2026-05-24",
  "",
  "本轮输出不是最终确认性模型，而是按照老师讨论后的两条故事线做的结构化探索：一方面让 ARS 作为主效应，另一方面让评论量/solicitation 作为主效应、ARS 作为调节。Management Response 只作为可观察的管理参与或 solicitation proxy，不直接写成因果 solicitation。",
  "",
  "## 一、数据与变量构建",
  "",
  paste0("- MR 文本 panel：`outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_", RUN_ID, ".dta`"),
  paste0("- 候选模型 scan：`outputs/core_simi_260501/csv/story_exploration_candidates_", RUN_ID, ".csv`"),
  paste0("- Stata do：`scripts/stata/run_core_simi_story_exploration_", RUN_ID, ".do`"),
  paste0("- Response 文本构建 R：`scripts/r/build_management_response_text_panel_", RUN_ID, ".R`"),
  "",
  "新增 response 文本变量包括：回复长度、7/30 天内快速回复、感谢、道歉、邀请再来、服务恢复、联系方式、个性化、积极语气、负面问题语气、模板化回复、manager/management 身份、针对低分评论的回复等。所有 MR 主变量均按 hotel-month 聚合后 lag 一期进入回归。",
  "",
  "### `z_` 前缀是什么意思",
  "",
  "`z_` 表示变量已经标准化：`z_x = (x - mean(x)) / sd(x)`。因此，`z_sim_mean` 增加 1，不是 ARS 原始值增加 1，而是 ARS 增加 1 个样本标准差。这样做的好处是不同量纲的变量可以直接比较系数大小。本文中大多数 `z_` 变量是在 `cs_sample_focus100 == 1` 的主样本中标准化。",
  "",
  "因为 revenue DV 是 `ln(RevPAR)`，所以系数可以近似理解为百分比变化：`100 × (exp(coef) - 1)%`。例如系数 `-0.0068` 约等于 RevPAR 下降 `0.68%`；交互项系数 `0.0047` 约等于某个边际效应提高 `0.47` 个百分点。",
  "",
  "### Audit",
  "",
  md_table(audit_wide),
  "",
  "### Scan 覆盖",
  "",
  md_table(sig_summary[, .(
    路线 = route,
    候选模型数 = models,
    `p<0.10` = sig_10,
    `p<0.05` = sig_05,
    `p<0.01` = sig_01
  )]),
  "",
  "### 经济效益速读",
  "",
  md_table(econ_effects),
  "",
  "## 二、主要结论",
  "",
  "### Route A：ARS 作为主效应",
  "",
  "ARS 主效应比上一轮更稳。`sim_mean` 的标准化版本、within-hotel 标准化版本、scope ARS 和 JSD ARS 都呈显著负向。完整表中，`ARS within-hotel std` 在 w199 DV 下为 `-0.0056`，SE `0.0019`，1% 水平显著；JSD ARS 在 w199 下为 `-0.0077`，SE `0.0027`，1% 水平显著。COVID 交互仍显著为正，说明疫情期 ARS 负向关系被削弱。",
  "",
  "市场和产品特征交互仍不是最强项。竞争 RevPAR、price gap、star 的主效应或控制项有解释力，但 `ARS × 市场/产品` 本身没有形成稳定强结果。因此 Route A 最适合写成：评论越相似，信息增量越低，RevPAR 越弱；疫情是目前最清楚的情境边界。",
  "",
  "### Route B：评论量/solicitation 作为主效应，ARS 作为调节",
  "",
  "这条线比上一版明显增强，但故事需要拆成“近期流量”和“累计评论资产”两层。近期评论量本身显著正向，`recent volume × ARS` 仍是负向但主要在 10% 附近；累计评论量、超过阈值的累计评论量、以及文本量存量与 ARS 的交互显著为正。完整表中，`cumulative volume × ARS` 为 `0.0069`，SE `0.0025`；`cum>5.8 × ARS` 为 `0.0083`，SE `0.0028`；`text volume stock × ARS` 为 `0.0067`，SE `0.0026`。",
  "",
  "可写的故事是：短期内，新增评论如果高度重复，会降低评论流量的边际价值；但长期累计评论资产里，高一致性/高 ARS 可能代表稳定可验证的质量信号，因此对 RevPAR 更有利。也就是说，评论量不是简单越多越好，而是取决于评论资产处在短期流入还是长期存量场景。",
  "",
  "### Route C：Management Response 文本作为 solicitation / engagement proxy",
  "",
  "MR 文本变量现在分成两类 revenue 结果。第一类是 reply 是否直接影响 RevPAR：`lag_mr_any` 本身为正但不显著，说明“只要有回复”并不能稳定带来收入提升；更细的文本质量变量更有信息，`recovery share` 对 RevPAR 为正且约 5% 显著，`quick7 share` 为正且约 10% 显著。第二类是 reply 是否被 ARS 调节：`invite share × ARS` 显著为正，完整表为 `0.0047`，SE `0.0017`，说明带有邀请再来语气的回复环境中，ARS 对 revenue 的负向关系被削弱。",
  "",
  "三重交互里，`recent volume × ARS × positive wording` 和 `recent volume × ARS × avg response words` 为负且显著，说明在高回复文本投入或积极回复语境下，近期评论量的 ARS 调节更强，符合“管理触达/solicitation 后带来的评论可能更同质化”的解释。",
  "",
  "机制表显示 response 文本投入强烈预测后续评论量：`lag MR text words -> ln_recent_volumn` 为 `0.0646`，SE `0.0080`，非常显著。同时 quick response 和 recovery share 对 RevPAR 有弱正向结果。需要注意，response rate、apology、recovery 在机制模型中对评论量/ARS 的符号有时为负，可能反映这些回复出现在服务问题或低评论情境中，因此不能直接写成“回复越多越好”。",
  "",
  "## 三、Top 候选模型",
  "",
  "### Route A Top",
  "",
  md_table(top_a),
  "",
  "### Route B Top",
  "",
  md_table(top_b),
  "",
  "### Route C Top",
  "",
  md_table(top_c),
  "",
  "### Route C Revenue Top",
  "",
  md_table(top_c_revenue),
  "",
  "## 四、完整回归结果",
  "",
  "说明：表中为系数；下一行括号内为酒店聚类稳健标准误。显著性：`* p<0.10`，`** p<0.05`，`*** p<0.01`，`**** p<0.001`。表 1 到表 5 都以 revenue，即 `ln(RevPAR)`，作为 DV；表 6 是机制表，同时报告 review volume、ARS 和 RevPAR。所有 RevPAR 主表均控制 hotel fixed effects 和 year-month fixed effects，并聚类到 hotel 层面。",
  "",
  "每张 revenue 表的经济解释规则一致：非交互项系数代表该变量增加 1 单位时 RevPAR 的百分比变化；如果变量带 `z_`，1 单位就是 1 个标准差。交互项系数代表边际效应改变多少个百分点。例如 `c.z_ln_lag_volumn_acc#c.z_sim_mean = 0.0069` 表示 ARS 高 1 个标准差时，累计评论量对 RevPAR 的边际收益约提高 0.69 个百分点。",
  "",
  table_md,
  "## 五、写作建议",
  "",
  "- 主文优先使用 Route A：ARS 负向主效应 + COVID 边界条件，结果最稳定，理论也最干净。",
  "- Route B 可以作为第二条主故事或机制扩展：评论量有正效应，但 ARS 改变评论量的经济含义；短期流入与长期存量的方向不同，要明确区分。",
  "- Route C 适合作为 solicitation/engagement proxy：不要只写“有无回复”，要写 reply 文本质量。当前结果显示 recovery/quick response 对 revenue 有弱正向直接关系，invite wording 会调节 ARS-revenue 关系，文本长度和 positive wording 更适合写成三重交互机制。",
  "- 市场/产品调节目前不强，除非老师特别想保留，建议放到 robustness 或 exploratory appendix。"
)

writeLines(lines, path_md, useBytes = TRUE)
cat("Wrote", path_md, "\n")
