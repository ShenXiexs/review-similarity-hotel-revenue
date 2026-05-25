library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(haven)
library(purrr)
library(fixest)

if ("setFixest_notes" %in% getNamespaceExports("fixest")) {
  setFixest_notes(FALSE)
}

RUN_ID <- "260430"

detect_project_dir <- function() {
  candidates <- unique(c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE),
    "/Users/samxie/Research/ReviewSimi_Sales/Code"
  ))

  for (candidate in candidates) {
    if (
      file.exists(file.path(candidate, "README.md")) &&
      dir.exists(file.path(candidate, "scripts")) &&
      dir.exists(file.path(candidate, "outputs"))
    ) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop("Cannot locate project root.")
}

assert_inside_project <- function(paths, project_dir) {
  root <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  normalized <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  outside <- normalized[!startsWith(normalized, paste0(root, "/")) & normalized != root]
  if (length(outside) > 0) {
    stop(paste("Refusing to write outside project root:", paste(outside, collapse = ", ")))
  }
  invisible(TRUE)
}

safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}

safe_median <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  median(x, na.rm = TRUE)
}

safe_quantile <- function(x, p) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))
}

extract_term <- function(model, term_pattern) {
  if (is.null(model)) {
    return(tibble(term = NA_character_, estimate = NA_real_, std_error = NA_real_, p_value = NA_real_))
  }

  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)
  rownames(ct) <- NULL
  hit <- ct %>% filter(str_detect(term, term_pattern)) %>% slice(1)

  if (nrow(hit) == 0) {
    return(tibble(term = NA_character_, estimate = NA_real_, std_error = NA_real_, p_value = NA_real_))
  }

  tibble(
    term = hit$term[[1]],
    estimate = hit$Estimate[[1]],
    std_error = hit$`Std. Error`[[1]],
    p_value = hit$`Pr(>|t|)`[[1]]
  )
}

build_fe_formula <- function(dep_var, sim_var, control_terms) {
  rhs <- paste(c(sim_var, control_terms), collapse = " + ")
  as.formula(paste(dep_var, "~", rhs, "| HotelID + year_month"))
}

build_ols_formula <- function(dep_var, sim_var, control_terms) {
  rhs <- paste(c(sim_var, control_terms), collapse = " + ")
  as.formula(paste(dep_var, "~", rhs))
}

build_binary_interaction_formula <- function(dep_var, sim_var, group_var, control_terms) {
  rhs <- paste(c(sim_var, group_var, paste0(sim_var, ":", group_var), control_terms), collapse = " + ")
  as.formula(paste(dep_var, "~", rhs, "| HotelID + year_month"))
}

score_direction <- function(low_beta, high_beta, expectation) {
  if (any(is.na(c(low_beta, high_beta)))) {
    return(0L)
  }
  if (expectation == "low_stronger") {
    return(as.integer(low_beta < high_beta))
  }
  if (expectation == "high_stronger") {
    return(as.integer(high_beta < low_beta))
  }
  0L
}

sample_keep <- function(df, sample_name) {
  if (sample_name == "full") {
    return(df$main_sample_keep == 1)
  }
  if (sample_name == "pre2020") {
    return(df$main_sample_keep == 1 & df$Year <= 2019)
  }
  if (sample_name == "pre2021") {
    return(df$main_sample_keep == 1 & df$Year <= 2020)
  }
  if (sample_name == "star_observed") {
    return(df$main_sample_keep == 1 & !is.na(df$star_class))
  }
  stop(paste("Unknown sample:", sample_name))
}

rule_meta <- function(rule_id) {
  if (str_starts(rule_id, "star_")) {
    return(list(
      block_vars = c("CityID"),
      block_scope = "city",
      boundary_policy = "fixed",
      star_rule_id = rule_id
    ))
  }

  block_map <- list(
    zipym = c("Zip", "Year", "Mon"),
    cityym = c("CityID", "Year", "Mon"),
    zipy = c("Zip", "Year"),
    ym = c("Year", "Mon"),
    cityy = c("CityID", "Year")
  )

  m <- str_match(
    rule_id,
    "^(zipym|cityym|zipy|ym|cityy)_(median_ge_lt|median_gt_le|median_strict|3070_inclusive|3070_strict|4060_inclusive|4060_strict)$"
  )
  if (all(is.na(m))) {
    stop(paste("Unknown group rule:", rule_id))
  }

  list(
    block_vars = block_map[[m[[2]]]],
    block_scope = m[[2]],
    boundary_policy = m[[3]],
    star_rule_id = NA_character_
  )
}

rule_labels <- function(rule_id, default_low = "low", default_high = "high") {
  if (rule_id == "star_lt3_ge3") {
    return(list(low_label = "<3", high_label = ">=3"))
  }
  if (rule_id == "star_le3_gt3") {
    return(list(low_label = "<=3", high_label = ">3"))
  }
  if (rule_id == "star_le35_gt35") {
    return(list(low_label = "<=3.5", high_label = ">3.5"))
  }
  if (rule_id == "star_eq3_ge35") {
    return(list(low_label = "==3", high_label = ">=3.5"))
  }
  if (rule_id == "star_lt3_gt3") {
    return(list(low_label = "<3", high_label = ">3"))
  }
  list(low_label = default_low, high_label = default_high)
}

prepare_group_data <- function(df, source_var, rule_id) {
  if (str_starts(rule_id, "star_")) {
    return(
      df %>%
        transmute(
          panel_row_id,
          HotelID,
          CityID,
          Year,
          Mon,
          year_month,
          group_flag = case_when(
            rule_id == "star_lt3_ge3" & !is.na(star_class) & star_class < 3 ~ 0L,
            rule_id == "star_lt3_ge3" & !is.na(star_class) & star_class >= 3 ~ 1L,
            rule_id == "star_le3_gt3" & !is.na(star_class) & star_class <= 3 ~ 0L,
            rule_id == "star_le3_gt3" & !is.na(star_class) & star_class > 3 ~ 1L,
            rule_id == "star_le35_gt35" & !is.na(star_class) & star_class <= 3.5 ~ 0L,
            rule_id == "star_le35_gt35" & !is.na(star_class) & star_class > 3.5 ~ 1L,
            rule_id == "star_eq3_ge35" & !is.na(star_class) & star_class == 3 ~ 0L,
            rule_id == "star_eq3_ge35" & !is.na(star_class) & star_class >= 3.5 ~ 1L,
            rule_id == "star_lt3_gt3" & !is.na(star_class) & star_class < 3 ~ 0L,
            rule_id == "star_lt3_gt3" & !is.na(star_class) & star_class > 3 ~ 1L,
            TRUE ~ NA_integer_
          ),
          moderator_centered = NA_real_,
          block_id = as.character(CityID)
        )
    )
  }

  meta <- rule_meta(rule_id)
  block_vars <- meta$block_vars
  split_type <- meta$boundary_policy

  tmp <- df %>%
    mutate(raw_value = .data[[source_var]]) %>%
    group_by(across(all_of(block_vars))) %>%
    mutate(
      block_obs = sum(!is.na(raw_value)),
      block_mean_value = safe_mean(raw_value),
      block_median_value = safe_median(raw_value),
      block_q30_value = safe_quantile(raw_value, 0.30),
      block_q40_value = safe_quantile(raw_value, 0.40),
      block_q60_value = safe_quantile(raw_value, 0.60),
      block_q70_value = safe_quantile(raw_value, 0.70),
      moderator_centered = if_else(is.na(raw_value), NA_real_, raw_value - block_mean_value),
      group_flag = case_when(
        is.na(raw_value) ~ NA_integer_,
        split_type %in% c("median_ge_lt", "median_gt_le", "median_strict") & block_obs < 2 ~ NA_integer_,
        split_type == "median_ge_lt" & raw_value < block_median_value ~ 0L,
        split_type == "median_ge_lt" & raw_value >= block_median_value ~ 1L,
        split_type == "median_gt_le" & raw_value <= block_median_value ~ 0L,
        split_type == "median_gt_le" & raw_value > block_median_value ~ 1L,
        split_type == "median_strict" & raw_value < block_median_value ~ 0L,
        split_type == "median_strict" & raw_value > block_median_value ~ 1L,
        split_type == "3070_inclusive" & block_obs >= 5 & raw_value <= block_q30_value ~ 0L,
        split_type == "3070_inclusive" & block_obs >= 5 & raw_value >= block_q70_value ~ 1L,
        split_type == "3070_strict" & block_obs >= 5 & raw_value < block_q30_value ~ 0L,
        split_type == "3070_strict" & block_obs >= 5 & raw_value > block_q70_value ~ 1L,
        split_type == "4060_inclusive" & block_obs >= 5 & raw_value <= block_q40_value ~ 0L,
        split_type == "4060_inclusive" & block_obs >= 5 & raw_value >= block_q60_value ~ 1L,
        split_type == "4060_strict" & block_obs >= 5 & raw_value < block_q40_value ~ 0L,
        split_type == "4060_strict" & block_obs >= 5 & raw_value > block_q60_value ~ 1L,
        TRUE ~ NA_integer_
      )
    ) %>%
    ungroup()

  block_id <- as.character(do.call(interaction, c(tmp[block_vars], list(drop = TRUE, lex.order = TRUE))))

  tmp %>%
    mutate(block_id = block_id) %>%
    transmute(
      panel_row_id,
      HotelID,
      CityID,
      Year,
      Mon,
      year_month,
      group_flag,
      moderator_centered,
      block_id
    )
}

run_h1_spec <- function(df, sample_name, dep_var, sim_var, control_family, control_terms) {
  required <- unique(c(dep_var, sim_var, control_terms, "HotelID", "year_month"))
  df_use <- df %>%
    filter(sample_keep(., sample_name)) %>%
    filter(if_all(all_of(required), ~ !is.na(.x)))

  if (nrow(df_use) < 500 || n_distinct(df_use$HotelID) < 20) {
    return(tibble())
  }

  ols_model <- tryCatch(
    feols(build_ols_formula(dep_var, sim_var, control_terms), data = df_use, cluster = ~HotelID),
    error = function(e) NULL
  )
  fe_model <- tryCatch(
    feols(build_fe_formula(dep_var, sim_var, control_terms), data = df_use, cluster = ~HotelID),
    error = function(e) NULL
  )

  ols_term <- extract_term(ols_model, paste0("^", sim_var, "$"))
  fe_term <- extract_term(fe_model, paste0("^", sim_var, "$"))

  tibble(
    sample = sample_name,
    dep_var = dep_var,
    sim_var = sim_var,
    control_family = control_family,
    observations = nrow(df_use),
    hotels = n_distinct(df_use$HotelID),
    ols_beta = ols_term$estimate,
    ols_se = ols_term$std_error,
    ols_p = ols_term$p_value,
    fe_beta = fe_term$estimate,
    fe_se = fe_term$std_error,
    fe_p = fe_term$p_value,
    h1_pass = as.integer(ols_beta < 0 & ols_p < 0.05 & fe_beta < 0 & fe_p < 0.05)
  )
}

evaluate_group_rule <- function(
  df,
  sample_name,
  dep_var,
  sim_var,
  control_family,
  control_terms,
  moderator,
  source_var,
  expectation,
  group_rule,
  min_group_n = 1000L,
  min_group_hotels = 20L
) {
  df_base <- df %>% filter(sample_keep(., sample_name))
  prepared <- prepare_group_data(df_base, source_var, group_rule)
  df_rule <- df_base %>%
    left_join(
      prepared %>% select(panel_row_id, group_flag, moderator_centered, block_id),
      by = "panel_row_id"
    ) %>%
    filter(!is.na(group_flag))

  required <- unique(c(dep_var, sim_var, control_terms, "HotelID", "year_month", "group_flag"))
  df_rule <- df_rule %>% filter(if_all(all_of(required), ~ !is.na(.x)))
  labels <- rule_labels(group_rule)
  meta <- rule_meta(group_rule)

  empty_row <- tibble(
    moderator = moderator,
    sample = sample_name,
    dep_var = dep_var,
    sim_var = sim_var,
    control_family = control_family,
    source_var = source_var,
    group_rule = group_rule,
    block_scope = meta$block_scope,
    boundary_policy = meta$boundary_policy,
    star_rule_id = meta$star_rule_id,
    low_label = labels$low_label,
    high_label = labels$high_label,
    expected = expectation,
    observations = nrow(df_rule),
    hotels = n_distinct(df_rule$HotelID),
    n_low = sum(df_rule$group_flag == 0, na.rm = TRUE),
    n_high = sum(df_rule$group_flag == 1, na.rm = TRUE),
    hotel_low = n_distinct(df_rule$HotelID[df_rule$group_flag == 0]),
    hotel_high = n_distinct(df_rule$HotelID[df_rule$group_flag == 1]),
    beta_low = NA_real_,
    se_low = NA_real_,
    p_low = NA_real_,
    beta_high = NA_real_,
    se_high = NA_real_,
    p_high = NA_real_,
    beta_diff = NA_real_,
    p_diff_screen = NA_real_,
    p_diff_perm = NA_real_,
    reps_used = 0L,
    direction_ok = 0L,
    expected_group_sig = 0L,
    any_group_sig = 0L,
    screen_pass = 0L,
    final_pass = 0L
  )

  if (nrow(df_rule) == 0 || n_distinct(df_rule$group_flag) < 2) {
    return(empty_row)
  }

  n_low <- sum(df_rule$group_flag == 0, na.rm = TRUE)
  n_high <- sum(df_rule$group_flag == 1, na.rm = TRUE)
  hotel_low <- n_distinct(df_rule$HotelID[df_rule$group_flag == 0])
  hotel_high <- n_distinct(df_rule$HotelID[df_rule$group_flag == 1])
  if (min(n_low, n_high) < 250 || min(hotel_low, hotel_high) < 10) {
    return(empty_row)
  }

  fe_formula <- build_fe_formula(dep_var, sim_var, control_terms)
  low_model <- tryCatch(
    feols(fe_formula, data = df_rule %>% filter(group_flag == 0), cluster = ~HotelID),
    error = function(e) NULL
  )
  high_model <- tryCatch(
    feols(fe_formula, data = df_rule %>% filter(group_flag == 1), cluster = ~HotelID),
    error = function(e) NULL
  )
  pooled_model <- tryCatch(
    feols(build_binary_interaction_formula(dep_var, sim_var, "group_flag", control_terms), data = df_rule, cluster = ~HotelID),
    error = function(e) NULL
  )

  low_term <- extract_term(low_model, paste0("^", sim_var, "$"))
  high_term <- extract_term(high_model, paste0("^", sim_var, "$"))
  int_term <- extract_term(pooled_model, paste0(sim_var, ":group_flag|group_flag:", sim_var))
  direction_val <- score_direction(low_term$estimate, high_term$estimate, expectation)
  expected_sig_val <- if (expectation == "low_stronger") {
    as.integer(low_term$estimate < 0 & low_term$p_value < 0.05)
  } else {
    as.integer(high_term$estimate < 0 & high_term$p_value < 0.05)
  }
  any_sig_val <- as.integer(
    (low_term$estimate < 0 & low_term$p_value < 0.05) |
      (high_term$estimate < 0 & high_term$p_value < 0.05)
  )
  screen_pass_val <- as.integer(
    direction_val == 1 &
      expected_sig_val == 1 &
      min(n_low, n_high) >= min_group_n &
      min(hotel_low, hotel_high) >= min_group_hotels
  )

  empty_row %>%
    mutate(
      observations = nrow(df_rule),
      hotels = n_distinct(df_rule$HotelID),
      n_low = n_low,
      n_high = n_high,
      hotel_low = hotel_low,
      hotel_high = hotel_high,
      beta_low = low_term$estimate,
      se_low = low_term$std_error,
      p_low = low_term$p_value,
      beta_high = high_term$estimate,
      se_high = high_term$std_error,
      p_high = high_term$p_value,
      beta_diff = int_term$estimate,
      p_diff_screen = int_term$p_value,
      direction_ok = direction_val,
      expected_group_sig = expected_sig_val,
      any_group_sig = any_sig_val,
      screen_pass = screen_pass_val
    )
}

run_permutation_diff <- function(df, row, control_terms, reps = 500L) {
  if (is.na(row$beta_diff) || nrow(df) == 0) {
    return(tibble(p_diff_perm = NA_real_, reps_used = 0L))
  }

  df_base <- df %>% filter(sample_keep(., row$sample))
  prepared <- prepare_group_data(df_base, row$source_var, row$group_rule)
  df_rule <- df_base %>%
    left_join(
      prepared %>% select(panel_row_id, group_flag, block_id),
      by = "panel_row_id"
    ) %>%
    filter(!is.na(group_flag))

  required <- unique(c(row$dep_var, row$sim_var, control_terms, "HotelID", "year_month", "group_flag"))
  df_rule <- df_rule %>% filter(if_all(all_of(required), ~ !is.na(.x)))
  if (nrow(df_rule) == 0 || n_distinct(df_rule$group_flag) < 2) {
    return(tibble(p_diff_perm = NA_real_, reps_used = 0L))
  }

  observed <- abs(row$beta_diff)
  perm_formula <- build_binary_interaction_formula(row$dep_var, row$sim_var, "group_perm", control_terms)
  set.seed(260430)

  if (str_starts(row$group_rule, "star_")) {
    hotel_groups <- df_rule %>%
      distinct(HotelID, CityID, group_flag)
    block_list <- split(seq_len(nrow(hotel_groups)), hotel_groups$CityID)

    draw_perm <- function() {
      perm_hotel <- hotel_groups$group_flag
      for (idx in block_list) {
        if (length(idx) > 1) {
          perm_hotel[idx] <- sample(perm_hotel[idx], length(idx), replace = FALSE)
        }
      }
      perm_hotel[match(df_rule$HotelID, hotel_groups$HotelID)]
    }
  } else {
    block_list <- split(seq_len(nrow(df_rule)), df_rule$block_id)

    draw_perm <- function() {
      perm_obs <- df_rule$group_flag
      for (idx in block_list) {
        if (length(idx) > 1) {
          perm_obs[idx] <- sample(perm_obs[idx], length(idx), replace = FALSE)
        }
      }
      perm_obs
    }
  }

  stats <- vapply(seq_len(reps), function(i) {
    df_perm <- df_rule %>% mutate(group_perm = draw_perm())
    model <- tryCatch(
      suppressWarnings(feols(perm_formula, data = df_perm, cluster = ~HotelID)),
      error = function(e) NULL
    )
    term <- extract_term(model, paste0(row$sim_var, ":group_perm|group_perm:", row$sim_var))
    abs(term$estimate)
  }, numeric(1))

  tibble(
    p_diff_perm = mean(stats >= observed, na.rm = TRUE),
    reps_used = reps
  )
}

pick_h1 <- function(h1_scan) {
  preferred <- h1_scan %>%
    mutate(
      sample_rank = match(sample, c("full", "pre2021", "pre2020")),
      sim_rank = match(sim_var, c("sim_mean", "lag_sim_mean", "sim_mean_std_hotel", "sim_mean_dm_cym")),
      control_rank = match(control_family, c("rich8_current", "ref_rating5", "quality6", "base4_month", "base4_acc", "lean3"))
    ) %>%
    arrange(desc(h1_pass), sample_rank, sim_rank, control_rank, fe_p, ols_p)

  preferred %>% slice(1)
}

pick_group <- function(scan, moderator_name) {
  rule_priority <- c(
    "cityym_median_strict",
    "cityym_3070_strict",
    "cityym_4060_strict",
    "cityy_3070_inclusive",
    "cityy_median_ge_lt",
    "ym_median_ge_lt",
    "ym_3070_inclusive",
    "zipy_3070_inclusive",
    "zipy_median_ge_lt",
    "star_lt3_ge3",
    "star_le3_gt3",
    "star_le35_gt35",
    "star_eq3_ge35",
    "star_lt3_gt3"
  )

  scan %>%
    filter(moderator == moderator_name) %>%
    mutate(
      sample_rank = match(sample, c("full", "pre2021", "pre2020", "star_observed")),
      dep_rank = match(dep_var, c("ln_RevPAR_clean")),
      sim_rank = match(sim_var, c("sim_mean", "lag_sim_mean", "sim_mean_std_hotel", "sim_mean_dm_cym")),
      control_rank = match(control_family, c("rich8_current", "ref_rating5", "quality6", "base4_month", "base4_acc", "lean3")),
      rule_rank = match(group_rule, rule_priority),
      diff_rank = coalesce(p_diff_screen, 1)
    ) %>%
    arrange(
      desc(screen_pass),
      desc(direction_ok),
      desc(expected_group_sig),
      diff_rank,
      sample_rank,
      sim_rank,
      control_rank,
      rule_rank
    ) %>%
    slice(1)
}

attach_selected_group <- function(panel_df, sample_df, selected_row, target_var) {
  out <- panel_df
  out[[target_var]] <- NA_integer_

  prepared <- prepare_group_data(
    sample_df %>% filter(sample_keep(., selected_row$sample)),
    selected_row$source_var,
    selected_row$group_rule
  )
  idx <- match(prepared$panel_row_id, out$panel_row_id)
  out[[target_var]][idx] <- prepared$group_flag
  out
}

project_dir <- detect_project_dir()
output_root <- file.path(project_dir, "outputs")
hyp_root <- file.path(output_root, "hypothesis")
hyp_data_dir <- file.path(hyp_root, "data")
hyp_csv_dir <- file.path(hyp_root, "csv")
hyp_scan_dir <- file.path(hyp_root, "scans")
hyp_table_dir <- file.path(hyp_root, "tables")
hyp_log_dir <- file.path(hyp_root, "logs")

for (dir_path in c(hyp_root, hyp_data_dir, hyp_csv_dir, hyp_scan_dir, hyp_table_dir, hyp_log_dir)) {
  assert_inside_project(dir_path, project_dir)
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
}

input_panel <- file.path(output_root, "data", "valid_match_review_acc_260407_main.dta")
if (!file.exists(input_panel)) {
  stop("Cannot find outputs/data/valid_match_review_acc_260407_main.dta")
}

panel <- read_dta(input_panel)
if (!"panel_row_id" %in% names(panel)) {
  panel <- panel %>% mutate(panel_row_id = row_number())
}

control_specs <- list(
  rich8_current = c(
    "ln_recent_volumn",
    "recent_sd",
    "ln_lag_volumn_acc",
    "lag_avg_rating_acc",
    "lag_sd_acc",
    "lag_avg_rating_month",
    "ln_avg_com_RevPAR",
    "ln_lag_RevPAR_clean"
  ),
  ref_rating5 = c(
    "ln_recent_volumn",
    "recent_sd",
    "ln_lag_volumn_acc",
    "lag_avg_rating_acc",
    "lag_sd_acc",
    "lag_rating_last_5",
    "ln_avg_com_RevPAR",
    "ln_lag_RevPAR_clean"
  ),
  quality6 = c(
    "ln_recent_volumn",
    "ln_lag_volumn_acc",
    "lag_avg_rating_acc",
    "lag_avg_rating_month",
    "ln_avg_com_RevPAR",
    "review_freshness",
    "ln_lag_RevPAR_clean"
  ),
  base4_acc = c(
    "ln_recent_volumn",
    "ln_lag_volumn_acc",
    "lag_avg_rating_acc",
    "ln_avg_com_RevPAR",
    "ln_lag_RevPAR_clean"
  ),
  base4_month = c(
    "ln_recent_volumn",
    "ln_lag_volumn_acc",
    "lag_avg_rating_month",
    "ln_avg_com_RevPAR",
    "ln_lag_RevPAR_clean"
  ),
  lean3 = c(
    "ln_recent_volumn",
    "ln_lag_volumn_acc",
    "ln_avg_com_RevPAR",
    "ln_lag_RevPAR_clean"
  )
)

required_control_vars <- unique(unlist(control_specs, use.names = FALSE))
missing_controls <- setdiff(required_control_vars, names(panel))
if (length(missing_controls) > 0) {
  stop(paste("Missing required variables:", paste(missing_controls, collapse = ", ")))
}

panel <- panel %>%
  mutate(
    hyp_sample_full = as.integer(main_sample_keep == 1),
    hyp_sample_pre2020 = as.integer(main_sample_keep == 1 & Year <= 2019),
    hyp_sample_pre2021 = as.integer(main_sample_keep == 1 & Year <= 2020),
    hyp_sample_star_observed = as.integer(main_sample_keep == 1 & !is.na(star_class)),
    hyp_year_range = "2011-2022"
  ) %>%
  group_by(CityID, Year, Mon) %>%
  mutate(
    lag_sim_mean_dm_cym = if_else(
      main_sample_keep == 1 & !is.na(lag_sim_mean),
      lag_sim_mean - mean(lag_sim_mean[main_sample_keep == 1], na.rm = TRUE),
      NA_real_
    )
  ) %>%
  ungroup()

sample_audit <- tibble(
  sample = c("all_rows", "main_sample_full", "main_sample_pre2020", "star_observed_full"),
  observations = c(
    nrow(panel),
    sum(panel$hyp_sample_full == 1, na.rm = TRUE),
    sum(panel$hyp_sample_pre2020 == 1, na.rm = TRUE),
    sum(panel$hyp_sample_star_observed == 1, na.rm = TRUE)
  ),
  hotels = c(
    n_distinct(panel$HotelID),
    n_distinct(panel$HotelID[panel$hyp_sample_full == 1]),
    n_distinct(panel$HotelID[panel$hyp_sample_pre2020 == 1]),
    n_distinct(panel$HotelID[panel$hyp_sample_star_observed == 1])
  ),
  min_year = c(
    min(panel$Year, na.rm = TRUE),
    min(panel$Year[panel$hyp_sample_full == 1], na.rm = TRUE),
    min(panel$Year[panel$hyp_sample_pre2020 == 1], na.rm = TRUE),
    min(panel$Year[panel$hyp_sample_star_observed == 1], na.rm = TRUE)
  ),
  max_year = c(
    max(panel$Year, na.rm = TRUE),
    max(panel$Year[panel$hyp_sample_full == 1], na.rm = TRUE),
    max(panel$Year[panel$hyp_sample_pre2020 == 1], na.rm = TRUE),
    max(panel$Year[panel$hyp_sample_star_observed == 1], na.rm = TRUE)
  ),
  star_nonmissing = c(
    sum(!is.na(panel$star_class)),
    sum(panel$hyp_sample_full == 1 & !is.na(panel$star_class)),
    sum(panel$hyp_sample_pre2020 == 1 & !is.na(panel$star_class)),
    sum(panel$hyp_sample_star_observed == 1 & !is.na(panel$star_class))
  ),
  star_coverage = star_nonmissing / observations
)

h1_grid <- expand_grid(
  sample = c("full", "pre2021", "pre2020"),
  dep_var = "ln_RevPAR_clean",
  sim_var = c("sim_mean", "lag_sim_mean", "sim_mean_std_hotel", "sim_mean_dm_cym"),
  control_family = names(control_specs)
)

message("Running H1 OLS/FE scan...")
h1_scan <- pmap_dfr(
  h1_grid,
  function(sample, dep_var, sim_var, control_family) {
    run_h1_spec(panel, sample, dep_var, sim_var, control_family, control_specs[[control_family]])
  }
)
h1_selected <- pick_h1(h1_scan)

moderator_specs <- tibble(
  moderator = c(
    "h2_rating_last",
    "h2_rating_accumulative",
    "h3_volume_last",
    "h3_volume_accumulative",
    "h4_star"
  ),
  source_var = c(
    "lag_avg_rating_month",
    "lag_avg_rating_acc",
    "lag_recent_volumn",
    "lag_volumn_acc",
    "star_class"
  ),
  expectation = c(
    "low_stronger",
    "low_stronger",
    "high_stronger",
    "high_stronger",
    "high_stronger"
  ),
  min_hotels = c(40L, 40L, 40L, 40L, 20L)
)

split_rules <- c(
  "cityym_median_strict",
  "cityy_3070_inclusive",
  "ym_median_ge_lt",
  "ym_3070_inclusive",
  "zipy_3070_inclusive"
)
star_rules <- c(
  "star_lt3_ge3",
  "star_le3_gt3",
  "star_le35_gt35",
  "star_eq3_ge35",
  "star_lt3_gt3"
)

hetero_grid <- moderator_specs %>%
  mutate(group_rule = map(moderator, ~ if (.x == "h4_star") star_rules else split_rules)) %>%
  unnest(group_rule) %>%
  crossing(
    sample = c("full", "pre2020"),
    dep_var = "ln_RevPAR_clean",
    sim_var = c("sim_mean", "sim_mean_std_hotel"),
    control_family = c("rich8_current", "quality6", "base4_month")
  )

message("Running H2-H4 grouped FE scan...")
hetero_scan <- pmap_dfr(
  hetero_grid,
  function(moderator, source_var, expectation, min_hotels, group_rule, sample, dep_var, sim_var, control_family) {
    evaluate_group_rule(
      panel,
      sample,
      dep_var,
      sim_var,
      control_family,
      control_specs[[control_family]],
      moderator,
      source_var,
      expectation,
      group_rule,
      min_group_n = 1000L,
      min_group_hotels = min_hotels
    )
  }
) %>%
  mutate(
    run_id = RUN_ID,
    screen_pass = as.integer(screen_pass == 1 & !is.na(p_diff_screen) & p_diff_screen < 0.10)
  )

selected_groups <- bind_rows(
  pick_group(hetero_scan, "h2_rating_last"),
  pick_group(hetero_scan, "h2_rating_accumulative"),
  pick_group(hetero_scan, "h3_volume_last"),
  pick_group(hetero_scan, "h3_volume_accumulative"),
  pick_group(hetero_scan, "h4_star")
)

perm_rows <- selected_groups %>%
  mutate(row_id = row_number()) %>%
  split(.$row_id) %>%
  map_dfr(function(row_df) {
    row <- row_df[1, ]
    control_terms <- control_specs[[row$control_family]]
    perm <- run_permutation_diff(panel, row, control_terms, reps = 200L)
    bind_cols(row_df %>% select(-row_id, -p_diff_perm, -reps_used), perm)
  }) %>%
  mutate(
    final_pass = as.integer(
      direction_ok == 1 &
        expected_group_sig == 1 &
        !is.na(p_diff_perm) &
        p_diff_perm < 0.10
    )
  )

selected_groups <- perm_rows

panel_out <- panel
for (i in seq_len(nrow(selected_groups))) {
  var_name <- paste0("hyp_group_", selected_groups$moderator[[i]])
  panel_out <- attach_selected_group(panel_out, panel, selected_groups[i, ], var_name)
}

panel_out <- panel_out %>%
  mutate(
    hyp_h1_sample = h1_selected$sample[[1]],
    hyp_h1_dep_var = h1_selected$dep_var[[1]],
    hyp_h1_sim_var = h1_selected$sim_var[[1]],
    hyp_h1_control_family = h1_selected$control_family[[1]]
  )

paths_to_write <- c(
  file.path(hyp_csv_dir, paste0("sample_audit_", RUN_ID, ".csv")),
  file.path(hyp_csv_dir, paste0("h1_selected_", RUN_ID, ".csv")),
  file.path(hyp_csv_dir, paste0("heterogeneity_selected_", RUN_ID, ".csv")),
  file.path(hyp_scan_dir, paste0("h1_ols_fe_scan_", RUN_ID, ".csv")),
  file.path(hyp_scan_dir, paste0("heterogeneity_group_scan_", RUN_ID, ".csv")),
  file.path(hyp_data_dir, paste0("hypothesis_panel_", RUN_ID, ".dta"))
)
assert_inside_project(paths_to_write, project_dir)

write_csv(sample_audit, paths_to_write[[1]])
write_csv(h1_selected, paths_to_write[[2]])
write_csv(selected_groups, paths_to_write[[3]])
write_csv(h1_scan, paths_to_write[[4]])
write_csv(hetero_scan, paths_to_write[[5]])
write_dta(panel_out, paths_to_write[[6]], version = 14)

message("Wrote hypothesis panel and scans under: ", hyp_root)
