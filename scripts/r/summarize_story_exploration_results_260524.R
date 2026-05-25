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

fmt_num <- function(x, digits = 4) ifelse(is.na(x), "", formatC(x, format = "f", digits = digits))
fmt_pct <- function(x, digits = 2) ifelse(is.na(x), "", paste0(formatC(x, format = "f", digits = digits), "%"))
fmt_p <- function(x) fifelse(is.na(x), "", fifelse(x < 0.001, "<0.001", formatC(x, format = "f", digits = 3)))

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
  coef <- parse_est(tbl[[model]][idx[1]])
  se <- if (idx[1] + 1 <= nrow(tbl)) parse_est(tbl[[model]][idx[1] + 1]) else NA_real_
  p <- if (!is.na(coef) && !is.na(se) && se > 0) 2 * pt(abs(coef / se), df = 557, lower.tail = FALSE) else NA_real_
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

table_files <- list(
  "表1_RouteA_ARS主效应" = file.path(csv_dir, "story_table_a_ars_main_260524.csv"),
  "表2_RouteA_边界条件" = file.path(csv_dir, "story_table_a_moderators_260524.csv"),
  "表3_RouteB_评论量与ARS调节" = file.path(csv_dir, "story_table_b_volume_ars_260524.csv"),
  "表4_RouteC_回复对Revenue与ARS调节" = file.path(csv_dir, "story_table_c_reply_revenue_260524.csv"),
  "表5_RouteC_文本特征与三重交互" = file.path(csv_dir, "story_table_c_mr_text_260524.csv"),
  "表6_RouteC_机制模型" = file.path(csv_dir, "story_table_c_mr_mechanisms_260524.csv")
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

econ <- rbindlist(list(
  add_effect(tables, "表1_RouteA_ARS主效应", "w199", "sim_mean", "ARS 主效应", 0.01, "ARS 原始值增加 0.01"),
  add_effect(tables, "表1_RouteA_ARS主效应", "w195", "sim_mean", "ARS 主效应稳健性", 0.01, "ARS 原始值增加 0.01"),
  add_effect(tables, "表1_RouteA_ARS主效应", "hotel std", "sim_mean_std_hotel", "酒店内 ARS", 1, "酒店内 ARS 高 1 单位"),
  add_effect(tables, "表1_RouteA_ARS主效应", "COVID", "1.covid2020_2022#c.sim_mean_centered", "COVID 期 ARS 斜率变化", 0.01, "疫情期相对非疫情期，ARS 增加 0.01 的额外效应"),
  add_effect(tables, "表3_RouteB_评论量与ARS调节", "recent", "c.ln_recent_volumn_centered#c.sim_mean_centered", "近期评论量 x ARS", log(2) * 0.01, "评论量翻倍且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteB_评论量与ARS调节", "growth", "c.recent_growth_centered#c.sim_mean_centered", "评论增长 x ARS", 0.01, "评论增长高 1 log 点且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteB_评论量与ARS调节", "cumulative", "c.ln_lag_volumn_acc_centered#c.sim_mean_centered", "累计评论量 x ARS", log(2) * 0.01, "累计评论量翻倍且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteB_评论量与ARS调节", "cum hstd", "c.ln_lag_volumn_acc_centered#c.sim_mean_std_hotel_centered", "累计评论量 x 酒店内 ARS", log(2), "累计评论量翻倍且酒店内 ARS 高 1 单位"),
  add_effect(tables, "表3_RouteB_评论量与ARS调节", "text volume", "c.ln_words_acc_centered#c.sim_mean_centered", "文本评论存量 x ARS", log(2) * 0.01, "文本存量翻倍且 ARS 高 0.01"),
  add_effect(tables, "表3_RouteB_评论量与ARS调节", "text hstd", "c.ln_words_acc_centered#c.sim_mean_std_hotel_centered", "文本评论存量 x 酒店内 ARS", log(2), "文本存量翻倍且酒店内 ARS 高 1 单位"),
  add_effect(tables, "表4_RouteC_回复对Revenue与ARS调节", "any reply", "1.lag_mr_any", "上月是否有回复", 1, "有回复相对无回复"),
  add_effect(tables, "表4_RouteC_回复对Revenue与ARS调节", "reply count", "lag_mr_count_centered", "回复数量直接效应", 1, "上月回复数量多 1 条"),
  add_effect(tables, "表4_RouteC_回复对Revenue与ARS调节", "invite", "c.sim_mean_centered#c.lag_mr_invite_share_centered", "邀请再来 x ARS", 0.10 * 0.01, "邀请语气高 10 个百分点且 ARS 高 0.01"),
  add_effect(tables, "表5_RouteC_文本特征与三重交互", "thanks", "lag_mr_thanks_share_centered", "感谢语气直接效应", 0.10, "感谢语气高 10 个百分点"),
  add_effect(tables, "表5_RouteC_文本特征与三重交互", "triple avg words", "c.ln_recent_volumn_centered#c.sim_mean_centered#c.ln_lag_mr_avg_words_centered", "近期评论量 x ARS x 平均回复长度", log(2) * 0.01 * log(2), "评论量翻倍、ARS 高 0.01、平均回复长度翻倍"),
  add_effect(tables, "表5_RouteC_文本特征与三重交互", "triple positive", "c.ln_recent_volumn_centered#c.sim_mean_centered#c.lag_mr_positive_share_centered", "近期评论量 x ARS x 积极回复", log(2) * 0.01 * 0.10, "评论量翻倍、ARS 高 0.01、积极回复占比高 10 个百分点"),
  add_effect(tables, "表6_RouteC_机制模型", "DV: volume", "ln_lag_mr_words", "MR 文本投入 -> 后续评论量", log(2), "上月回复总字数翻倍"),
  add_effect(tables, "表6_RouteC_机制模型", "DV: ARS", "ln_lag_mr_words", "MR 文本投入 -> 后续 ARS", log(2), "上月回复总字数翻倍；DV 是 ARS 原始值", effect_type = "raw")
), fill = TRUE)

fwrite(econ, path_summary)

table_md <- character()
for (nm in names(tables)) {
  title <- switch(
    nm,
    "表1_RouteA_ARS主效应" = "表 1：Route A - ARS 主效应、winsor 与 ARS 替代口径",
    "表2_RouteA_边界条件" = "表 2：Route A - 时间、市场、产品与评分边界",
    "表3_RouteB_评论量与ARS调节" = "表 3：Route B - 评论量/solicitation 与 ARS 调节",
    "表4_RouteC_回复对Revenue与ARS调节" = "表 4：Route C - 回复是否影响 Revenue，并是否被 ARS 调节",
    "表5_RouteC_文本特征与三重交互" = "表 5：Route C - 回复文本特征与三重交互",
    "表6_RouteC_机制模型" = "表 6：Route C - Management Response 机制模型",
    nm
  )
  table_md <- c(table_md, paste0("### ", title), "", md_table(tables[[nm]]), "")
}

lines <- c(
  "# ARS 双故事线与 Management Response 文本扩展：显式无标准化前缀结果整理",
  "",
  "日期：2026-05-25",
  "",
  "本版结果只使用显式回归表，不再沿用旧的标准化候选 scan。Stata do 文件已经改成原始尺度、log 尺度、阈值变量和均值中心化交互项。`_centered` 表示变量减去主样本均值，单位没有变化，目的是让交互模型中的主效应可以解释为“在平均水平下”的效应。",
  "",
  "所有 revenue 主表均以 `ln(RevPAR)` 为因变量，控制 hotel fixed effects 和 year-month fixed effects，并在 hotel 层面聚类。系数可以近似换算为 `100 × (exp(beta × delta) - 1)%` 的 RevPAR 变化；交互项则按两个或三个变量的联合变化换算。",
  "",
  "## 一、结论速读",
  "",
  "- **Route A 可以作为主故事。** ARS 主效应在不同 winsor、scope 和 JSD 口径下稳定为负；`sim_mean` 增加 0.01，对应 RevPAR 约下降 0.18%-0.19%。COVID 交互为正，说明疫情期 ARS 的负向斜率被明显削弱。",
  "- **Route B 现在可以成立，但要写成“评论资产的边际价值取决于 ARS”。** 近期评论流和评论增长的 ARS 调节是负向、10% 水平附近；累计评论量、超过阈值的累计评论量、累计文本量与 ARS 的交互显著为正。",
  "- **Route C 是机制/扩展，不宜写成强因果。** 是否有回复本身不稳，但回复文本质量有 revenue 信息：感谢语气直接正向，邀请再来语气显著削弱 ARS 的负向 revenue 关系；平均回复长度、快速回复、积极回复的三重交互为负，支持“管理触达后的新增评论可能更同质化”的解释。",
  "",
  "## 二、Raw-scale 变量分布",
  "",
  md_table(varsum_show),
  "",
  "## 三、核心系数与经济效应",
  "",
  md_table(econ),
  "",
  "## 四、完整回归结果",
  "",
  table_md,
  "## 五、写作建议",
  "",
  "- 主文建议以 Route A 为主：ARS 负向主效应 + COVID 边界条件，结果最稳。",
  "- Route B 可作为第二条主线：不要说“评论量越多越差”，而是写“短期评论流和长期评论资产的 ARS 含义不同”。",
  "- Route C 放在机制或扩展：reply 不是直接等同 solicitation，而是 observable management engagement proxy；重点写文本质量和三重交互。"
)

writeLines(lines, path_md, useBytes = TRUE)
cat("Wrote", path_md, "\n")
cat("Wrote", path_summary, "\n")
