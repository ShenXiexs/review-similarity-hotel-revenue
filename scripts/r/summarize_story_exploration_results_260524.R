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
    if (file.exists(file.path(candidate, "README.md")) &&
        dir.exists(file.path(candidate, "scripts")) &&
        dir.exists(file.path(candidate, "outputs"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Cannot locate project root.")
}

fmt_num <- function(x, digits = 4) {
  out <- rep("", length(x))
  ok <- !is.na(x) & is.finite(x)
  out[ok] <- formatC(x[ok], format = "f", digits = digits)
  out
}
fmt_pct <- function(x, digits = 2) {
  out <- rep("", length(x))
  ok <- !is.na(x) & is.finite(x)
  out[ok] <- paste0(formatC(x[ok], format = "f", digits = digits), "%")
  out
}
fmt_p <- function(x) {
  out <- rep("", length(x))
  ok <- !is.na(x) & is.finite(x)
  out[ok] <- ifelse(x[ok] < 0.001, "<0.001", formatC(x[ok], format = "f", digits = 3))
  out
}

parse_est <- function(x) {
  x <- gsub("\"", "", x, fixed = TRUE)
  x <- gsub("=", "", x, fixed = TRUE)
  x <- gsub("\\*", "", x)
  x <- gsub("[()]", "", x)
  suppressWarnings(as.numeric(trimws(x)))
}

pct_from_log <- function(beta, delta = 1) 100 * (exp(beta * delta) - 1)

md_table <- function(dt) {
  if (is.null(dt) || nrow(dt) == 0) return("")
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
  header <- as.character(unlist(df[2]))
  header[1] <- "变量"
  header[header == ""] <- paste0("模型", which(header == ""))
  body <- df[-c(1, 2, 3)]
  setnames(body, make.unique(header, sep = "_"))
  body
}

get_cell <- function(tbl, term, model) {
  if (!model %in% names(tbl)) return(NA_character_)
  idx <- which(tbl[["变量"]] == term)
  if (!length(idx)) return(NA_character_)
  tbl[[model]][idx[1]]
}

get_est <- function(tbl, term, model) {
  if (!model %in% names(tbl)) return(list(coef = NA_real_, se = NA_real_, p = NA_real_, n = NA_real_))
  idx <- which(tbl[["变量"]] == term)
  n <- parse_est(get_cell(tbl, "Observations", model))
  if (!length(idx)) return(list(coef = NA_real_, se = NA_real_, p = NA_real_, n = n))
  coef_raw <- tbl[[model]][idx[1]]
  coef <- parse_est(coef_raw)
  se <- if (idx[1] + 1 <= nrow(tbl)) parse_est(tbl[[model]][idx[1] + 1]) else NA_real_
  p <- if (!is.na(coef) && !is.na(se) && se > 0) 2 * pt(abs(coef / se), df = 557, lower.tail = FALSE) else NA_real_
  if (is.na(p) && grepl("\\*\\*\\*\\*", coef_raw)) p <- 0.0005
  if (is.na(p) && grepl("\\*\\*\\*", coef_raw)) p <- 0.005
  if (is.na(p) && grepl("\\*\\*", coef_raw)) p <- 0.025
  if (is.na(p) && grepl("\\*", coef_raw)) p <- 0.075
  list(coef = coef, se = se, p = p, n = n)
}

add_effect <- function(items, table_name, model, term, label, delta, rule, effect_type = "log_pct") {
  est <- get_est(items[[table_name]], term, model)
  effect <- if (effect_type == "raw") fmt_num(est$coef * delta, 4) else fmt_pct(pct_from_log(est$coef, delta))
  data.table(
    表 = table_name,
    模型 = model,
    核心项 = term,
    解释标签 = label,
    系数 = fmt_num(est$coef),
    SE = fmt_num(est$se),
    p值 = fmt_p(est$p),
    N = ifelse(is.na(est$n), "", formatC(est$n, format = "d", big.mark = ",")),
    `经济效应` = effect,
    `换算口径` = rule
  )
}

project_dir <- detect_project_dir()
out_root <- file.path(project_dir, "outputs/core_simi_260501")
csv_dir <- file.path(out_root, "csv")
research_dir <- file.path(out_root, "research")
results_dir <- file.path(research_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

path_md <- file.path(results_dir, sprintf("core_simi_story_exploration_results_%s.md", RUN_ID))
path_summary <- file.path(csv_dir, sprintf("story_exploration_rawscale_summary_%s.csv", RUN_ID))
path_varsum <- file.path(csv_dir, sprintf("story_variable_summary_%s.csv", RUN_ID))
path_profile_audit <- file.path(csv_dir, sprintf("story_profile_merge_audit_%s.csv", RUN_ID))

table_files <- list(
  "表1_RouteA_ARS主效应" = file.path(csv_dir, "story_table_a_ars_main_260524.csv"),
  "表2_RouteA_边界条件" = file.path(csv_dir, "story_table_a_moderators_260524.csv"),
  "表3_RouteA_Profile产品边界" = file.path(csv_dir, "story_table_a_profile_product_260524.csv"),
  "表4_RouteA_Profile合成产品边界" = file.path(csv_dir, "story_table_a_profile_composite_260526.csv"),
  "表5_RouteA_Profile单项设施风格附录" = file.path(csv_dir, "story_table_a_profile_flags_260524.csv"),
  "表6_RouteD_Review情感与ARS" = file.path(csv_dir, "story_table_d_review_sentiment_260526.csv"),
  "表7_RouteD_Review情感 refined" = file.path(csv_dir, "story_table_d_review_sentiment_refined_260526.csv"),
  "表8_RouteB_评论量与ARS调节" = file.path(csv_dir, "story_table_b_volume_ars_260524.csv"),
  "表9_RouteC_回复对Revenue与ARS调节" = file.path(csv_dir, "story_table_c_reply_revenue_260524.csv"),
  "表10_RouteC_文本特征与三重交互" = file.path(csv_dir, "story_table_c_mr_text_260524.csv"),
  "表11_RouteC_被回复评论对象" = file.path(csv_dir, "story_table_c2_replied_review_260526.csv"),
  "表12_RouteC_机制模型" = file.path(csv_dir, "story_table_c_mr_mechanisms_260524.csv")
)

missing_tables <- names(table_files)[!file.exists(unlist(table_files))]
if (length(missing_tables)) stop("Missing Stata table CSVs: ", paste(missing_tables, collapse = ", "))

tables <- lapply(table_files, read_esttab_csv)
varsum <- if (file.exists(path_varsum)) fread(path_varsum) else data.table(variable = character())
if (nrow(varsum)) {
  varsum_show <- varsum[, .(变量 = variable, 均值 = fmt_num(mean), SD = fmt_num(sd), P25 = fmt_num(p25), P75 = fmt_num(p75))]
} else {
  varsum_show <- data.table()
}

profile_audit <- if (file.exists(path_profile_audit)) fread(path_profile_audit) else data.table()
if (nrow(profile_audit)) {
  profile_audit_show <- data.table(
    指标 = c("profile 原始酒店数", "profile 重复 HotelID 行", "panel 行匹配", "panel 酒店匹配", "原 star_class_raw 缺失行", "可由 profile 补星级行", "补完后 star_class_final_raw 缺失行", "profile Travelers' Choice 酒店", "profile Best of the Best 酒店", "focus100 Travelers' Choice 行", "focus100 Travelers' Choice 酒店"),
    数值 = c(
      formatC(profile_audit$profile_rows, format = "d", big.mark = ","),
      formatC(profile_audit$profile_duplicate_id_rows, format = "d", big.mark = ","),
      paste0(formatC(profile_audit$panel_rows_matched, format = "d", big.mark = ","), " / ", formatC(profile_audit$panel_rows, format = "d", big.mark = ","), " (", fmt_pct(100 * profile_audit$row_match_rate), ")"),
      paste0(formatC(profile_audit$panel_hotels_matched, format = "d", big.mark = ","), " / ", formatC(profile_audit$panel_hotels, format = "d", big.mark = ","), " (", fmt_pct(100 * profile_audit$hotel_match_rate), ")"),
      formatC(profile_audit$star_missing_before, format = "d", big.mark = ","),
      formatC(profile_audit$star_fillable_from_profile, format = "d", big.mark = ","),
      formatC(profile_audit$star_missing_after, format = "d", big.mark = ","),
      formatC(profile_audit$profile_travelers_choice_hotels, format = "d", big.mark = ","),
      formatC(profile_audit$profile_best_of_best_hotels, format = "d", big.mark = ","),
      formatC(profile_audit$focus100_travelers_choice_rows, format = "d", big.mark = ","),
      formatC(profile_audit$focus100_travelers_choice_hotels, format = "d", big.mark = ",")
    )
  )
} else {
  profile_audit_show <- data.table()
}

econ <- rbindlist(list(
  add_effect(tables, "表1_RouteA_ARS主效应", "w199", "sim_mean", "ARS 主效应", 0.01, "ARS 原始值增加 0.01"),
  add_effect(tables, "表1_RouteA_ARS主效应", "w195", "sim_mean", "ARS 主效应稳健性", 0.01, "ARS 原始值增加 0.01"),
  add_effect(tables, "表1_RouteA_ARS主效应", "hotel std", "sim_mean_std_hotel", "酒店内 ARS", 1, "酒店内 ARS 高 1 单位"),
  add_effect(tables, "表1_RouteA_ARS主效应", "COVID", "1.covid2020_2022#c.sim_mean_centered", "COVID 期 ARS 斜率变化", 0.01, "疫情期相对非疫情期，ARS 增加 0.01 的额外效应"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "TA class", "c.sim_mean_centered#c.hotel_class_profile_raw_centered", "TA 星级 x ARS", 0.01, "TA 星级高 1 星且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "quality", "c.sim_mean_centered#c.tp_quality_index_centered", "Profile 质量 x ARS", 0.01, "Profile 质量评分高 1 分且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "service", "c.sim_mean_centered#c.tp_service_quality_centered", "服务质量 x ARS", 0.01, "服务质量评分高 1 分且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "price", "c.sim_mean_centered#c.ln_tp_price_mid_centered", "价格定位 x ARS", log(2) * 0.01, "Profile 价格翻倍且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "rooms", "c.sim_mean_centered#c.ln_tp_room_centered", "酒店规模 x ARS", log(2) * 0.01, "房间数翻倍且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "rank pct", "c.sim_mean_centered#c.tp_rank_pct_centered", "TA 排名百分位 x ARS", 0.10 * 0.01, "排名百分位高 10 个百分点且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "amenities", "c.sim_mean_centered#c.tp_amenity_count_centered", "Amenities 数量 x ARS", 10 * 0.01, "Amenities 多 10 项且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteA_Profile产品边界", "choice", "1.travelers_choice_flag#c.sim_mean_centered", "Travelers Choice x ARS", 0.01, "有 Travelers Choice 且 ARS 高 0.01"),
  add_effect(tables, "表4_RouteA_Profile合成产品边界", "recreation", "c.sim_mean_centered#c.amen_rec_index_centered", "娱乐设施指数 x ARS", 0.01, "娱乐设施指数高 1 项且 ARS 高 0.01"),
  add_effect(tables, "表4_RouteA_Profile合成产品边界", "service", "c.sim_mean_centered#c.amen_serv_index_centered", "基础服务设施指数 x ARS", 0.01, "基础服务设施指数高 1 项且 ARS 高 0.01"),
  add_effect(tables, "表4_RouteA_Profile合成产品边界", "business amenity", "c.sim_mean_centered#c.amen_bus_index_centered", "商务设施指数 x ARS", 0.01, "商务设施指数高 1 项且 ARS 高 0.01"),
  add_effect(tables, "表4_RouteA_Profile合成产品边界", "upscale", "1.style_upscale#c.sim_mean_centered", "高端风格 x ARS", 0.01, "高端风格且 ARS 高 0.01"),
  add_effect(tables, "表4_RouteA_Profile合成产品边界", "choice", "1.travelers_choice_flag#c.sim_mean_centered", "Travelers Choice x ARS", 0.01, "有 Travelers Choice 且 ARS 高 0.01"),
  add_effect(tables, "表6_RouteD_Review情感与ARS", "ARS syuzhet", "sent_avg_syuzhet_centered", "Syuzhet 情感 -> ARS", 1, "月均 Syuzhet 情感高 1 分；DV 是 ARS 原始值", effect_type = "raw"),
  add_effect(tables, "表6_RouteD_Review情感与ARS", "ARS bing", "sent_avg_bing_centered", "Bing 情感 -> ARS", 1, "月均 Bing 情感高 1 分；DV 是 ARS 原始值", effect_type = "raw"),
  add_effect(tables, "表6_RouteD_Review情感与ARS", "Rev afinn", "c.sim_mean_centered#c.sent_avg_afinn_centered", "ARS x AFINN 情感 -> Revenue", 0.01, "ARS 高 0.01 且月均 AFINN 情感高 1 分"),
  add_effect(tables, "表7_RouteD_Review情感 refined", "ARS net bing", "sent_net_pos_bing_centered", "Bing 净正向占比 -> ARS", 0.10, "净正向占比高 10 个百分点；DV 是 ARS 原始值", effect_type = "raw"),
  add_effect(tables, "表7_RouteD_Review情感 refined", "Rev net x ARS", "c.sim_mean_centered#c.sent_net_pos_bing_centered", "ARS x 净正向占比 -> Revenue", 0.10 * 0.01, "净正向占比高 10 个百分点且 ARS 高 0.01"),
  add_effect(tables, "表7_RouteD_Review情感 refined", "Rev neg x ARS", "c.sim_mean_centered#c.sent_neg_share_bing_centered", "ARS x 负向占比 -> Revenue", 0.10 * 0.01, "负向占比高 10 个百分点且 ARS 高 0.01"),
  add_effect(tables, "表7_RouteD_Review情感 refined", "Rev high x ARS", "1.high_sent_bing#c.sim_mean_centered", "高情感月份 x ARS", 0.01, "高情感月且 ARS 高 0.01"),
  add_effect(tables, "表8_RouteB_评论量与ARS调节", "recent", "c.ln_recent_volumn_centered#c.sim_mean_centered", "近期评论量 x ARS", log(2) * 0.01, "评论量翻倍且 ARS 高 0.01"),
  add_effect(tables, "表8_RouteB_评论量与ARS调节", "cumulative", "c.ln_lag_volumn_acc_centered#c.sim_mean_centered", "累计评论量 x ARS", log(2) * 0.01, "累计评论量翻倍且 ARS 高 0.01"),
  add_effect(tables, "表8_RouteB_评论量与ARS调节", "text volume", "c.ln_words_acc_centered#c.sim_mean_centered", "文本评论存量 x ARS", log(2) * 0.01, "文本存量翻倍且 ARS 高 0.01"),
  add_effect(tables, "表9_RouteC_回复对Revenue与ARS调节", "any reply", "1.lag_mr_any", "上月是否有回复", 1, "有回复相对无回复"),
  add_effect(tables, "表9_RouteC_回复对Revenue与ARS调节", "reply count", "lag_mr_count_centered", "回复数量直接效应", 1, "上月回复数量多 1 条"),
  add_effect(tables, "表9_RouteC_回复对Revenue与ARS调节", "invite", "c.sim_mean_centered#c.lag_mr_invite_share_centered", "邀请再来 x ARS", 0.10 * 0.01, "邀请语气高 10 个百分点且 ARS 高 0.01"),
  add_effect(tables, "表10_RouteC_文本特征与三重交互", "thanks", "lag_mr_thanks_share_centered", "感谢语气直接效应", 0.10, "感谢语气高 10 个百分点"),
  add_effect(tables, "表10_RouteC_文本特征与三重交互", "triple positive", "c.ln_recent_volumn_centered#c.sim_mean_centered#c.lag_mr_positive_share_centered", "近期评论量 x ARS x 积极回复", log(2) * 0.01 * 0.10, "评论量翻倍、ARS 高 0.01、积极回复占比高 10 个百分点"),
  add_effect(tables, "表11_RouteC_被回复评论对象", "Rev neg x ARS", "c.sim_mean_centered#c.lag_mr_rep_neg_share_centered", "ARS x 被回复负面评论占比", 0.10 * 0.01, "被回复负面评论占比高 10 个百分点且 ARS 高 0.01"),
  add_effect(tables, "表11_RouteC_被回复评论对象", "Rev low x ARS", "c.sim_mean_centered#c.lag_mr_rep_low_share_centered", "ARS x 被回复低评分评论占比", 0.10 * 0.01, "被回复低评分评论占比高 10 个百分点且 ARS 高 0.01"),
  add_effect(tables, "表11_RouteC_被回复评论对象", "DV volume", "lag_mr_rep_low_share", "被回复低评分评论占比 -> 后续评论量", 0.10, "被回复低评分评论占比高 10 个百分点"),
  add_effect(tables, "表11_RouteC_被回复评论对象", "DV ARS", "lag_mr_rep_low_share", "被回复低评分评论占比 -> 后续 ARS", 0.10, "被回复低评分评论占比高 10 个百分点；DV 是 ARS 原始值", effect_type = "raw"),
  add_effect(tables, "表12_RouteC_机制模型", "DV: volume", "ln_lag_mr_words", "MR 文本投入 -> 后续评论量", log(2), "上月回复总字数翻倍"),
  add_effect(tables, "表12_RouteC_机制模型", "DV: ARS", "ln_lag_mr_words", "MR 文本投入 -> 后续 ARS", log(2), "上月回复总字数翻倍；DV 是 ARS 原始值", effect_type = "raw")
), fill = TRUE)

fwrite(econ, path_summary)

table_md <- character()
for (nm in names(tables)) {
  title <- switch(
    nm,
    "表1_RouteA_ARS主效应" = "表 1：Route A - ARS 主效应、winsor 与 ARS 替代口径",
    "表2_RouteA_边界条件" = "表 2：Route A - 时间、市场、产品与评分边界",
    "表3_RouteA_Profile产品边界" = "表 3：Route A - Hotel Profile 产品特征边界",
    "表4_RouteA_Profile合成产品边界" = "表 4：Route A - Hotel Profile 合成产品维度边界",
    "表5_RouteA_Profile单项设施风格附录" = "表 5：Route A - Hotel Profile 单项设施与风格附录",
    "表6_RouteD_Review情感与ARS" = "表 6：Route D - Review 情感、ARS 与 Revenue 调节",
    "表7_RouteD_Review情感 refined" = "表 7：Route D - Review 情感 refined 口径",
    "表8_RouteB_评论量与ARS调节" = "表 8：Route B - 评论量/solicitation 与 ARS 调节",
    "表9_RouteC_回复对Revenue与ARS调节" = "表 9：Route C - 回复是否影响 Revenue，并是否被 ARS 调节",
    "表10_RouteC_文本特征与三重交互" = "表 10：Route C - 回复文本特征与三重交互",
    "表11_RouteC_被回复评论对象" = "表 11：Route C - 被回复评论对象与 complaint handling proxy",
    "表12_RouteC_机制模型" = "表 12：Route C - Management Response 机制模型",
    nm
  )
  table_md <- c(table_md, paste0("### ", title), "", md_table(tables[[nm]]), "")
}

lines <- c(
  "# ARS 双故事线与 Management Response 文本扩展：显式无标准化前缀结果整理",
  "",
  "日期：2026-05-25",
  "",
  "本版结果只使用显式回归表，不再沿用旧的标准化候选 scan。Stata do 文件已经改成原始尺度、log 尺度、阈值变量和均值中心化交互项。`_centered` 表示变量减去主样本均值，单位没有变化，目的是让交互模型中的主效应可以解释为“在平均水平下”的效应。本版新增 `hotel_profile_TP.csv` 的 TripAdvisor 产品特征，并在内存里把 `star_class` 缺失值用 profile 的 `hotel_class` 补成 `star_class_final`，不覆盖原 `.dta`。",
  "",
  "所有 revenue 主表均以 `ln(RevPAR)` 为因变量，控制 hotel fixed effects 和 year-month fixed effects，并在 hotel 层面聚类。系数可以近似换算为 `100 × (exp(beta × delta) - 1)%` 的 RevPAR 变化；交互项则按两个或三个变量的联合变化换算。",
  "",
  "## 一、结论速读",
  "",
  "- **Route A 可以作为主故事。** ARS 主效应在不同 winsor、scope 和 JSD 口径下稳定为负；`sim_mean` 增加 0.01，对应 RevPAR 约下降 0.18%-0.19%。COVID 交互为正，说明疫情期 ARS 的负向斜率被明显削弱。Hotel Profile 补充后，产品边界可以看 `star_class_final`、TA 星级、价格定位、酒店规模、质量评分、rank、amenities、设施和风格标签的 ARS 异质性。",
  "- **Route D 支持“情感质量影响 ARS”，但 refined 口径显示 revenue 证据更偏探索。** 使用 `syuzhet` 包的 Syuzhet、Bing、AFINN、NRC 四种词典，月均 review 情感整体能解释 ARS；新增的净正向占比、负向占比、per-100-word AFINN 和高/低情感分组显示，高情感月份会改变 ARS 的 revenue 斜率，但不宜写成强因果。",
  "- **Route B 现在可以成立，但要写成“评论资产的边际价值取决于 ARS”。** 近期评论流和评论增长的 ARS 调节是负向、10% 水平附近；累计评论量、超过阈值的累计评论量、累计文本量与 ARS 的交互显著为正。",
  "- **Route C 是机制/扩展，不宜写成强因果。** 是否有回复本身不稳，但回复文本质量有 revenue 信息；新增的“被回复评论对象”结果显示，酒店回应低评分、负面情感或 room/service complaint 评论后，后续评论量和 ARS 有可解释变化，更适合作为 observable complaint handling / engagement proxy。",
  "- **Travelers' Choice 已修复。** 之前交互被忽略的原因是字符串 badge 被 `destring, force` 转成 missing；现在用原字符串匹配 `Travelers' Choice` 和 `Best of the Best`。主效应被 hotel FE 吸收是正常的，交互项可估计但目前不强。",
  "",
  "## 二、Hotel Profile 合并 Audit",
  "",
  md_table(profile_audit_show),
  "",
  "## 三、Raw-scale 变量分布",
  "",
  md_table(varsum_show),
  "",
  "## 四、核心系数与经济效应",
  "",
  md_table(econ),
  "",
  "## 五、完整回归结果",
  "",
  table_md,
  "## 六、写作建议",
  "",
  "- 主文建议以 Route A 为主：ARS 负向主效应 + COVID 边界条件，结果最稳；产品特征用合成维度写，单项设施/风格只放附录。profile 产品变量是 time-invariant，所以在 hotel FE 下只能解释 `ARS × product feature` 的异质性。",
  "- Review 情感结果可放在 ARS 机制解释：更正向的评论文本更异质、更少重复，因此 ARS 下降；高/低情感和净正向占比可以作为补充的 revenue 调节探索。",
  "- Route B 可作为第二条主线：不要说“评论量越多越差”，而是写“短期评论流和长期评论资产的 ARS 含义不同”。",
  "- Route C 放在机制或扩展：reply 不是直接等同 solicitation，而是 observable management engagement / complaint handling proxy；重点写回复文本质量、被回复评论对象，以及 revenue/volume/ARS 三类结果。"
)

writeLines(lines, path_md, useBytes = TRUE)
cat("Wrote", path_md, "\n")
cat("Wrote", path_summary, "\n")
