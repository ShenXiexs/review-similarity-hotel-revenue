library(dplyr)
library(readr)
library(haven)
library(fixest)
library(tidyr)
library(stringr)

if ("setFixest_notes" %in% getNamespaceExports("fixest")) {
  setFixest_notes(FALSE)
}

project_dir <- "/Users/samxie/Research/ReviewSimi_Sales/Code"
output_root <- file.path(project_dir, "outputs")
data_dir <- file.path(output_root, "data")
csv_dir <- file.path(output_root, "csv")

for (dir_path in c(output_root, data_dir, csv_dir)) {
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
}

path_panel <- file.path(data_dir, "valid_match_review_acc_260407_main.dta")
path_sample_audit <- file.path(csv_dir, "sample_audit_260407.csv")
path_out_core <- file.path(csv_dir, "heterogeneity_pre2019_core_260407.csv")
path_out_diff <- file.path(csv_dir, "heterogeneity_pre2019_diff_tests_260407.csv")
path_out_star_cov <- file.path(csv_dir, "star_pre2019_coverage_260407.csv")

audit_sig_cutoff <- 0.05
perm_reps_base <- 250L
perm_reps_refine <- 1000L

control_family_specs <- tibble(
  control_family = c("rich8_current", "quality6", "base4_acc", "base4_month", "lean3", "momentum_plus"),
  control_terms = list(
    c("ln_recent_volumn", "recent_sd", "ln_lag_volumn_acc", "lag_avg_rating_acc", "lag_sd_acc", "lag_avg_rating_month", "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"),
    c("ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_acc", "lag_avg_rating_month", "ln_avg_com_RevPAR", "review_freshness", "ln_lag_RevPAR_clean"),
    c("ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_acc", "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"),
    c("ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_month", "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"),
    c("ln_recent_volumn", "ln_lag_volumn_acc", "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"),
    c("ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_acc", "ln_avg_com_RevPAR", "rating_momentum", "volume_momentum", "review_freshness", "ln_lag_RevPAR_clean")
  )
)

extract_term <- function(model, term_pattern) {
  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)
  rownames(ct) <- NULL
  hit <- ct %>% filter(str_detect(term, term_pattern)) %>% slice(1)
  if (nrow(hit) == 0) return(tibble(estimate = NA_real_, p_value = NA_real_))
  tibble(estimate = hit$Estimate[[1]], p_value = hit$`Pr(>|t|)`[[1]])
}

build_fe_formula <- function(control_terms) {
  as.formula(paste("ln_RevPAR_clean ~", paste(c("sim_mean", control_terms), collapse = " + "), "| HotelID + year_month"))
}

build_binary_formula <- function(group_var, control_terms) {
  as.formula(paste("ln_RevPAR_clean ~", paste(c("sim_mean", group_var, paste0("sim_mean:", group_var), control_terms), collapse = " + "), "| HotelID + year_month"))
}

build_cont_formula <- function(center_var, control_terms) {
  as.formula(paste("ln_RevPAR_clean ~", paste(c("sim_mean", center_var, paste0("sim_mean:", center_var), control_terms), collapse = " + "), "| HotelID + year_month"))
}

score_direction <- function(low_beta, high_beta, expectation) {
  if (any(is.na(c(low_beta, high_beta)))) return(0L)
  if (expectation == "low_stronger") return(as.integer(low_beta < high_beta))
  if (expectation == "high_stronger") return(as.integer(high_beta < low_beta))
  0L
}

run_perm <- function(df_rule, group_var, control_terms, group_mode = c("block", "star"), base_reps = perm_reps_base, refine_reps = perm_reps_refine) {
  group_mode <- match.arg(group_mode)
  if (nrow(df_rule) == 0 || n_distinct(df_rule[[group_var]]) < 2) return(tibble(p_diff_perm = NA_real_, reps_used = 0L))

  obs_model <- tryCatch(feols(build_binary_formula(group_var, control_terms), data = df_rule, cluster = ~HotelID), error = function(e) NULL)
  if (is.null(obs_model)) return(tibble(p_diff_perm = NA_real_, reps_used = 0L))
  obs_beta <- abs(extract_term(obs_model, paste0("sim_mean:", group_var, "|", group_var, ":sim_mean"))$estimate)
  if (is.na(obs_beta)) return(tibble(p_diff_perm = NA_real_, reps_used = 0L))

  if (group_mode == "star") {
    hotel_grp <- df_rule %>% distinct(HotelID, CityID, .data[[group_var]])
    block_list <- split(seq_len(nrow(hotel_grp)), hotel_grp$CityID)
    draw_perm <- function() {
      perm_hotel <- hotel_grp[[group_var]]
      for (idx in block_list) {
        if (length(idx) > 1) perm_hotel[idx] <- sample(perm_hotel[idx], length(idx), replace = FALSE)
      }
      perm_hotel[match(df_rule$HotelID, hotel_grp$HotelID)]
    }
  } else {
    block_list <- split(seq_len(nrow(df_rule)), df_rule$perm_block)
    draw_perm <- function() {
      perm_obs <- df_rule[[group_var]]
      for (idx in block_list) {
        if (length(idx) > 1) perm_obs[idx] <- sample(perm_obs[idx], length(idx), replace = FALSE)
      }
      perm_obs
    }
  }

  one_perm <- function(seed_id) {
    set.seed(seed_id + 9000L)
    df_perm <- df_rule %>% mutate(group_perm = draw_perm())
    m <- tryCatch(suppressWarnings(feols(build_binary_formula("group_perm", control_terms), data = df_perm, cluster = ~HotelID)), error = function(e) NULL)
    if (is.null(m)) return(NA_real_)
    abs(extract_term(m, "sim_mean:group_perm|group_perm:sim_mean")$estimate)
  }

  stats <- unlist(lapply(seq_len(base_reps), one_perm), use.names = FALSE)
  p_val <- mean(stats >= obs_beta, na.rm = TRUE)
  reps_used <- base_reps
  if (!is.na(p_val) && p_val >= 0.05 && p_val <= 0.15) {
    extra <- unlist(lapply(seq.int(base_reps + 1L, refine_reps), one_perm), use.names = FALSE)
    stats <- c(stats, extra)
    p_val <- mean(stats >= obs_beta, na.rm = TRUE)
    reps_used <- refine_reps
  }
  tibble(p_diff_perm = p_val, reps_used = reps_used)
}

sample_audit <- read_csv(path_sample_audit, show_col_types = FALSE)
selected_sample_name <- sample_audit$main_sample_rule[[1]]
selected_control_family <- sample_audit$control_family[[1]]
control_terms <- control_family_specs %>% filter(control_family == selected_control_family) %>% pull(control_terms) %>% .[[1]]

df <- read_dta(path_panel) %>%
  filter(main_sample_keep == 1, Year <= 2019) %>%
  mutate(panel_row_id = row_number())

df <- df %>%
  group_by(CityID, Year) %>%
  mutate(
    md_rating_last = median(lag_avg_rating_month, na.rm = TRUE),
    mean_rating_last = mean(lag_avg_rating_month, na.rm = TRUE),
    q30_rating_acc = as.numeric(quantile(lag_avg_rating_acc, 0.30, na.rm = TRUE, names = FALSE)),
    q70_rating_acc = as.numeric(quantile(lag_avg_rating_acc, 0.70, na.rm = TRUE, names = FALSE)),
    mean_rating_acc = mean(lag_avg_rating_acc, na.rm = TRUE),
    high_rating_month_pre = case_when(
      is.na(lag_avg_rating_month) ~ NA_integer_,
      lag_avg_rating_month < md_rating_last ~ 0L,
      lag_avg_rating_month > md_rating_last ~ 1L,
      TRUE ~ NA_integer_
    ),
    center_rating_month_pre = if_else(is.na(lag_avg_rating_month), NA_real_, lag_avg_rating_month - mean_rating_last),
    high_rating_acc_pre = case_when(
      is.na(lag_avg_rating_acc) ~ NA_integer_,
      lag_avg_rating_acc <= q30_rating_acc ~ 0L,
      lag_avg_rating_acc >= q70_rating_acc ~ 1L,
      TRUE ~ NA_integer_
    ),
    center_rating_acc_pre = if_else(is.na(lag_avg_rating_acc), NA_real_, lag_avg_rating_acc - mean_rating_acc),
    perm_block_cityy = interaction(CityID, Year, drop = TRUE, lex.order = TRUE)
  ) %>%
  ungroup() %>%
  group_by(Year, Mon) %>%
  mutate(
    md_volume_last = median(lag_recent_volumn, na.rm = TRUE),
    mean_volume_last = mean(lag_recent_volumn, na.rm = TRUE),
    md_volume_acc = median(lag_volumn_acc, na.rm = TRUE),
    mean_volume_acc = mean(lag_volumn_acc, na.rm = TRUE),
    high_volume_month_pre = case_when(
      is.na(lag_recent_volumn) ~ NA_integer_,
      lag_recent_volumn < md_volume_last ~ 0L,
      lag_recent_volumn >= md_volume_last ~ 1L
    ),
    center_volume_month_pre = if_else(is.na(lag_recent_volumn), NA_real_, lag_recent_volumn - mean_volume_last),
    high_volume_acc_pre = case_when(
      is.na(lag_volumn_acc) ~ NA_integer_,
      lag_volumn_acc < md_volume_acc ~ 0L,
      lag_volumn_acc >= md_volume_acc ~ 1L
    ),
    center_volume_acc_pre = if_else(is.na(lag_volumn_acc), NA_real_, lag_volumn_acc - mean_volume_acc),
    perm_block_ym = interaction(Year, Mon, drop = TRUE, lex.order = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    high_star_pre = case_when(
      is.na(star_class) ~ NA_integer_,
      star_class < 3 ~ 0L,
      star_class > 3 ~ 1L,
      TRUE ~ NA_integer_
    ),
    selected_rule_high_rating_month_pre = "cityy_median_strict",
    selected_rule_high_rating_acc_pre = "cityy_3070",
    selected_rule_high_volume_month_pre = "ym_median",
    selected_rule_high_volume_acc_pre = "ym_median",
    selected_rule_star_pre = "star_lt3_gt3"
  )

specs <- tribble(
  ~moderator, ~group_var, ~center_var, ~perm_block_var, ~group_mode, ~group_rule, ~low_label, ~high_label, ~expected,
  "rating_last", "high_rating_month_pre", "center_rating_month_pre", "perm_block_cityy", "block", "cityy_median_strict", "low", "high", "low_stronger",
  "rating_accumulative", "high_rating_acc_pre", "center_rating_acc_pre", "perm_block_cityy", "block", "cityy_3070", "low", "high", "low_stronger",
  "volume_last", "high_volume_month_pre", "center_volume_month_pre", "perm_block_ym", "block", "ym_median", "low", "high", "high_stronger",
  "volume_accumulative", "high_volume_acc_pre", "center_volume_acc_pre", "perm_block_ym", "block", "ym_median", "low", "high", "high_stronger",
  "star_ge3", "high_star_pre", NA_character_, "CityID", "star", "star_lt3_gt3", "<3", ">3", "high_stronger"
)

run_one <- function(spec_row) {
  gvar <- spec_row$group_var[[1]]
  cvar <- spec_row$center_var[[1]]
  block_var <- spec_row$perm_block_var[[1]]
  df_rule <- df %>% filter(!is.na(.data[[gvar]])) %>% mutate(perm_block = .data[[block_var]])

  low_df <- df_rule %>% filter(.data[[gvar]] == 0)
  high_df <- df_rule %>% filter(.data[[gvar]] == 1)
  low_model <- tryCatch(feols(build_fe_formula(control_terms), data = low_df, cluster = ~HotelID), error = function(e) NULL)
  high_model <- tryCatch(feols(build_fe_formula(control_terms), data = high_df, cluster = ~HotelID), error = function(e) NULL)
  low_term <- if (is.null(low_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(low_model, "^sim_mean$")
  high_term <- if (is.null(high_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(high_model, "^sim_mean$")

  bin_model <- tryCatch(feols(build_binary_formula(gvar, control_terms), data = df_rule, cluster = ~HotelID), error = function(e) NULL)
  bin_term <- if (is.null(bin_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(bin_model, paste0("sim_mean:", gvar, "|", gvar, ":sim_mean"))

  cont_term <- if (is.na(cvar)) {
    tibble(estimate = NA_real_, p_value = NA_real_)
  } else {
    cont_df <- df_rule %>% filter(!is.na(.data[[cvar]]))
    cont_model <- tryCatch(feols(build_cont_formula(cvar, control_terms), data = cont_df, cluster = ~HotelID), error = function(e) NULL)
    if (is.null(cont_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(cont_model, paste0("sim_mean:", cvar, "|", cvar, ":sim_mean"))
  }

  perm_term <- run_perm(df_rule, gvar, control_terms, group_mode = spec_row$group_mode[[1]])

  tibble(
    sample = selected_sample_name,
    sample_scope = "pre2019",
    control_family = selected_control_family,
    moderator = spec_row$moderator[[1]],
    group_rule = spec_row$group_rule[[1]],
    low_label = spec_row$low_label[[1]],
    high_label = spec_row$high_label[[1]],
    expected = spec_row$expected[[1]],
    observations = nrow(df_rule),
    hotels = n_distinct(df_rule$HotelID),
    n_low = nrow(low_df),
    n_high = nrow(high_df),
    min_group_n = min(nrow(low_df), nrow(high_df)),
    hotel_low = n_distinct(low_df$HotelID),
    hotel_high = n_distinct(high_df$HotelID),
    min_group_hotels = min(n_distinct(low_df$HotelID), n_distinct(high_df$HotelID)),
    beta_low = low_term$estimate,
    p_low = low_term$p_value,
    beta_high = high_term$estimate,
    p_high = high_term$p_value,
    beta_diff = bin_term$estimate,
    p_diff_screen = bin_term$p_value,
    p_diff_perm = perm_term$p_diff_perm,
    reps_used = perm_term$reps_used,
    p_interaction_binary = bin_term$p_value,
    p_interaction_continuous = cont_term$p_value,
    beta_interaction_continuous = cont_term$estimate,
    direction_ok = score_direction(low_term$estimate, high_term$estimate, spec_row$expected[[1]]),
    any_group_sig05 = as.integer((low_term$estimate < 0 & low_term$p_value < audit_sig_cutoff) | (high_term$estimate < 0 & high_term$p_value < audit_sig_cutoff))
  ) %>%
    mutate(
      diff_sig05 = as.integer((!is.na(p_diff_perm) && p_diff_perm < audit_sig_cutoff) | (!is.na(p_interaction_binary) && p_interaction_binary < audit_sig_cutoff)),
      rule_pass_005 = as.integer(direction_ok == 1 & any_group_sig05 == 1 & diff_sig05 == 1 & min_group_n >= 1000)
    )
}

core_out <- bind_rows(lapply(seq_len(nrow(specs)), function(i) run_one(specs[i, ])))

star_cov <- tibble(
  sample = selected_sample_name,
  sample_scope = "pre2019",
  star_rule_id = "star_lt3_gt3",
  nonmissing_obs = sum(!is.na(df$star_class)),
  nonmissing_hotels = n_distinct(df$HotelID[!is.na(df$star_class)]),
  n_low = sum(df$high_star_pre == 0, na.rm = TRUE),
  n_high = sum(df$high_star_pre == 1, na.rm = TRUE),
  hotel_low = n_distinct(df$HotelID[df$high_star_pre == 0]),
  hotel_high = n_distinct(df$HotelID[df$high_star_pre == 1]),
  min_group_n = min(sum(df$high_star_pre == 0, na.rm = TRUE), sum(df$high_star_pre == 1, na.rm = TRUE)),
  min_group_hotels = min(n_distinct(df$HotelID[df$high_star_pre == 0]), n_distinct(df$HotelID[df$high_star_pre == 1]))
)

write_csv(core_out, path_out_core)
write_csv(core_out, path_out_diff)
write_csv(star_cov, path_out_star_cov)

print(core_out)
print(star_cov)
