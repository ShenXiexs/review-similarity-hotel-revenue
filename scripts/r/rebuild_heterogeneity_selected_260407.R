library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(haven)
library(purrr)
library(fixest)
library(parallel)

if ("setFixest_notes" %in% getNamespaceExports("fixest")) {
  setFixest_notes(FALSE)
}

detect_project_dir <- function() {
  candidates <- unique(c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE),
    "/Users/samxie/Research/ReviewSimi_Sales/Code"
  ))

  for (candidate in candidates) {
    if (
      file.exists(file.path(candidate, "Paper_Results_260407.md")) &&
      dir.exists(file.path(candidate, "scripts")) &&
      dir.exists(file.path(candidate, "outputs"))
    ) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop("Cannot locate project root.")
}

project_dir <- detect_project_dir()
output_root <- file.path(project_dir, "outputs")
data_dir <- file.path(output_root, "data")
csv_dir <- file.path(output_root, "csv")
scan_dir <- file.path(output_root, "scans")

for (dir_path in c(output_root, data_dir, csv_dir, scan_dir)) {
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
}

path_panel_main <- file.path(data_dir, "valid_match_review_acc_260407_main.dta")
path_sample_audit <- file.path(csv_dir, "sample_audit_260407.csv")
path_out_hetero_rule_scan <- file.path(scan_dir, "heterogeneity_rule_scan_260407.csv")
path_out_hetero_threshold_scan <- file.path(scan_dir, "heterogeneity_threshold_scan_260407.csv")
path_out_hetero_control_scan <- file.path(scan_dir, "heterogeneity_control_scan_260407.csv")
path_out_hetero_core <- file.path(csv_dir, "heterogeneity_core_260407.csv")
path_out_hetero_diff_tests <- file.path(csv_dir, "heterogeneity_diff_tests_260407.csv")
path_out_hetero_interaction <- file.path(csv_dir, "heterogeneity_interaction_260407.csv")
path_out_hetero_boundary_scan <- file.path(scan_dir, "heterogeneity_boundary_scan_260407.csv")

group_min_n <- 1000L
group_min_hotels_rating_last <- 40L
group_min_hotels_star <- 20L
perm_reps_base <- 1000L
perm_reps_refine <- 5000L
audit_sig_cutoff <- 0.05
detected_cores <- detectCores(logical = FALSE)
if (is.na(detected_cores)) {
  detected_cores <- 2L
}
perm_cores <- 1L

control_family_specs <- tibble(
  control_family = c(
    "rich8_current",
    "quality6",
    "base4_acc",
    "base4_month",
    "lean3",
    "momentum_plus"
  ),
  control_terms = list(
    c(
      "ln_recent_volumn",
      "recent_sd",
      "ln_lag_volumn_acc",
      "lag_avg_rating_acc",
      "lag_sd_acc",
      "lag_avg_rating_month",
      "ln_avg_com_RevPAR",
      "ln_lag_RevPAR_clean"
    ),
    c(
      "ln_recent_volumn",
      "ln_lag_volumn_acc",
      "lag_avg_rating_acc",
      "lag_avg_rating_month",
      "ln_avg_com_RevPAR",
      "review_freshness",
      "ln_lag_RevPAR_clean"
    ),
    c(
      "ln_recent_volumn",
      "ln_lag_volumn_acc",
      "lag_avg_rating_acc",
      "ln_avg_com_RevPAR",
      "ln_lag_RevPAR_clean"
    ),
    c(
      "ln_recent_volumn",
      "ln_lag_volumn_acc",
      "lag_avg_rating_month",
      "ln_avg_com_RevPAR",
      "ln_lag_RevPAR_clean"
    ),
    c(
      "ln_recent_volumn",
      "ln_lag_volumn_acc",
      "ln_avg_com_RevPAR",
      "ln_lag_RevPAR_clean"
    ),
    c(
      "ln_recent_volumn",
      "ln_lag_volumn_acc",
      "lag_avg_rating_acc",
      "ln_avg_com_RevPAR",
      "rating_momentum",
      "volume_momentum",
      "review_freshness",
      "ln_lag_RevPAR_clean"
    )
  )
)

moderator_specs <- tibble(
  moderator = c(
    "rating_last",
    "rating_accumulative",
    "volume_last",
    "volume_accumulative",
    "star_ge3"
  ),
  source_var = c(
    "lag_avg_rating_month",
    "lag_avg_rating_acc",
    "lag_recent_volumn",
    "lag_volumn_acc",
    "star_class"
  ),
  group_var = c(
    "high_rating_month",
    "high_rating_acc",
    "high_volume_month",
    "high_volume_acc",
    "high_star_group"
  ),
  center_var = c(
    "center_rating_month",
    "center_rating_acc",
    "center_volume_month",
    "center_volume_acc",
    NA_character_
  ),
  low_label = c("low", "low", "low", "low", "low"),
  high_label = c("high", "high", "high", "high", "high"),
  expected = c(
    "low_stronger",
    "low_stronger",
    "high_stronger",
    "high_stronger",
    "high_stronger"
  ),
  allow_quantile = c(TRUE, TRUE, TRUE, TRUE, FALSE)
)

legacy_rule_priority <- c(
  "zipym_3070",
  "zipym_median",
  "zipym_4060",
  "cityym_3070",
  "cityym_median",
  "cityym_4060",
  "zipy_3070",
  "zipy_median",
  "zipy_4060",
  "ym_3070",
  "ym_median",
  "ym_4060",
  "cityy_3070",
  "cityy_median",
  "cityy_4060",
  "star_fixed"
)

rating_last_rule_priority <- c(
  "cityym_median_strict",
  "ym_median_strict",
  "zipy_3070_strict",
  "cityym_3070_strict",
  "cityym_4060_strict",
  "zipym_median_strict",
  "zipym_3070_strict",
  "zipym_4060_strict",
  "ym_3070_strict",
  "ym_4060_strict",
  "cityy_median_strict",
  "cityy_3070_strict",
  "cityy_4060_strict",
  "zipy_median_strict",
  "zipy_4060_strict",
  "cityym_median_ge_lt",
  "cityym_median_gt_le",
  "cityym_4060_inclusive",
  "cityym_3070_inclusive",
  "zipym_median_ge_lt",
  "zipym_median_gt_le",
  "zipym_4060_inclusive",
  "zipym_3070_inclusive",
  "ym_median_ge_lt",
  "ym_median_gt_le",
  "ym_4060_inclusive",
  "ym_3070_inclusive",
  "cityy_median_ge_lt",
  "cityy_median_gt_le",
  "cityy_4060_inclusive",
  "cityy_3070_inclusive",
  "zipy_median_ge_lt",
  "zipy_median_gt_le",
  "zipy_4060_inclusive",
  "zipy_3070_inclusive"
)

star_rule_priority <- c(
  "star_lt3_ge3",
  "star_le3_gt3",
  "star_le35_gt35",
  "star_eq3_ge35",
  "star_lt3_gt3"
)

group_rule_priority <- unique(c(
  rating_last_rule_priority,
  legacy_rule_priority[legacy_rule_priority != "star_fixed"],
  star_rule_priority
))

extract_term <- function(model, term_pattern) {
  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)
  rownames(ct) <- NULL

  hit <- ct %>%
    filter(str_detect(term, term_pattern)) %>%
    slice(1)

  if (nrow(hit) == 0) {
    return(tibble(
      term = NA_character_,
      estimate = NA_real_,
      std_error = NA_real_,
      p_value = NA_real_
    ))
  }

  tibble(
    term = hit$term[[1]],
    estimate = hit$Estimate[[1]],
    std_error = hit$`Std. Error`[[1]],
    p_value = hit$`Pr(>|t|)`[[1]]
  )
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

safe_quantile <- function(x, prob) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  as.numeric(quantile(x, prob, na.rm = TRUE, names = FALSE))
}

available_rule_ids <- function(spec) {
  if (spec$moderator[[1]] == "rating_last") {
    return(rating_last_rule_priority)
  }
  if (spec$moderator[[1]] == "star_ge3") {
    return(star_rule_priority)
  }
  legacy_rule_priority[legacy_rule_priority != "star_fixed"]
}

rule_meta <- function(rule_id) {
  if (str_starts(rule_id, "star_")) {
    return(
      list(
        block_vars = c("CityID"),
        split_type = "fixed",
        block_scope = "city",
        boundary_policy = "fixed",
        star_rule_id = rule_id
      )
    )
  }

  block_map <- list(
    zipym = c("Zip", "Year", "Mon"),
    cityym = c("CityID", "Year", "Mon"),
    zipy = c("Zip", "Year"),
    ym = c("Year", "Mon"),
    cityy = c("CityID", "Year")
  )

  m <- str_match(rule_id, "^(zipym|cityym|zipy|ym|cityy)_(median_ge_lt|median_gt_le|median_strict|4060_inclusive|4060_strict|3070_inclusive|3070_strict|3070|4060|median)$")
  if (all(is.na(m))) {
    stop(paste("Unknown group rule:", rule_id))
  }

  block_scope <- m[[2]]
  boundary_policy <- m[[3]]
  if (boundary_policy == "median") {
    boundary_policy <- "median_ge_lt"
  } else if (boundary_policy == "3070") {
    boundary_policy <- "3070_inclusive"
  } else if (boundary_policy == "4060") {
    boundary_policy <- "4060_inclusive"
  }

  list(
    block_vars = block_map[[block_scope]],
    split_type = boundary_policy,
    block_scope = block_scope,
    boundary_policy = boundary_policy,
    star_rule_id = NA_character_
  )
}

rule_rank_for <- function(moderator_name, rule_id) {
  if (moderator_name == "rating_last") {
    return(match(rule_id, rating_last_rule_priority))
  }
  if (moderator_name == "star_ge3") {
    return(match(rule_id, star_rule_priority))
  }
  match(rule_id, legacy_rule_priority)
}

rule_labels <- function(spec, rule_id) {
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
  list(
    low_label = spec$low_label[[1]],
    high_label = spec$high_label[[1]]
  )
}

min_group_hotels_required <- function(spec) {
  if (spec$moderator[[1]] == "rating_last") {
    return(group_min_hotels_rating_last)
  }
  if (spec$moderator[[1]] == "star_ge3") {
    return(group_min_hotels_star)
  }
  0L
}

build_fe_formula <- function(dep_var, sim_var, control_terms) {
  rhs_terms <- c(sim_var, control_terms)
  as.formula(paste(dep_var, "~", paste(rhs_terms, collapse = " + "), "| HotelID + year_month"))
}

build_ols_formula <- function(dep_var, sim_var, control_terms) {
  rhs_terms <- c(sim_var, control_terms)
  as.formula(paste(dep_var, "~", paste(rhs_terms, collapse = " + ")))
}

build_binary_interaction_formula <- function(dep_var, sim_var, group_var, control_terms) {
  rhs_terms <- c(sim_var, group_var, paste0(sim_var, ":", group_var), control_terms)
  as.formula(paste(dep_var, "~", paste(rhs_terms, collapse = " + "), "| HotelID + year_month"))
}

build_continuous_interaction_formula <- function(dep_var, sim_var, center_var, control_terms) {
  rhs_terms <- c(sim_var, center_var, paste0(sim_var, ":", center_var), control_terms)
  as.formula(paste(dep_var, "~", paste(rhs_terms, collapse = " + "), "| HotelID + year_month"))
}

prepare_group_data <- function(df, spec, rule_id) {
  if (str_starts(rule_id, "star_")) {
    tmp <- df %>%
      transmute(
        panel_row_id,
        HotelID,
        CityID,
        Year,
        Mon,
        year_month,
        star_class,
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
        block_id = as.character(CityID),
        group_rule = rule_id
      )
    return(tmp)
  }

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
          group_flag = as.integer(star_ge3),
          moderator_centered = NA_real_,
          block_id = as.character(CityID),
          group_rule = rule_id
        )
    )
  }

  meta <- rule_meta(rule_id)
  split_type <- meta$split_type
  block_vars <- meta$block_vars
  source_var <- spec$source_var[[1]]

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
        split_type %in% c("3070_inclusive", "3070_strict") & block_obs < 5 ~ NA_integer_,
        split_type == "3070_inclusive" & raw_value <= block_q30_value ~ 0L,
        split_type == "3070_inclusive" & raw_value >= block_q70_value ~ 1L,
        split_type == "3070_strict" & raw_value < block_q30_value ~ 0L,
        split_type == "3070_strict" & raw_value > block_q70_value ~ 1L,
        split_type %in% c("4060_inclusive", "4060_strict") & block_obs < 5 ~ NA_integer_,
        split_type == "4060_inclusive" & raw_value <= block_q40_value ~ 0L,
        split_type == "4060_inclusive" & raw_value >= block_q60_value ~ 1L,
        split_type == "4060_strict" & raw_value < block_q40_value ~ 0L,
        split_type == "4060_strict" & raw_value > block_q60_value ~ 1L,
        TRUE ~ NA_integer_
      )
    ) %>%
    ungroup()

  block_df <- tmp %>%
    select(all_of(block_vars)) %>%
    mutate(block_id = as.character(do.call(interaction, c(across(everything()), list(drop = TRUE, lex.order = TRUE)))))

  tmp %>%
    bind_cols(block_df %>% select(block_id)) %>%
    transmute(
      panel_row_id,
      HotelID,
      CityID,
      Year,
      Mon,
      year_month,
      group_flag,
      moderator_centered,
      block_id = as.character(block_id),
      group_rule = rule_id
    )
}

build_rule_sample <- function(df, spec, rule_id) {
  prepared <- prepare_group_data(df, spec, rule_id)
  df %>%
    left_join(prepared, by = c("panel_row_id", "HotelID", "CityID", "Year", "Mon", "year_month")) %>%
    filter(!is.na(group_flag))
}

run_binary_interaction_df <- function(df_rule, spec, control_terms) {
  if (nrow(df_rule) == 0 || n_distinct(df_rule$group_flag) < 2) {
    return(tibble(moderator = spec$moderator[[1]], p_interaction_binary = NA_real_, beta_diff = NA_real_))
  }

  pool_formula <- build_binary_interaction_formula("ln_RevPAR_clean", "sim_mean", "group_flag", control_terms)
  m <- tryCatch(feols(pool_formula, data = df_rule, cluster = ~HotelID), error = function(e) NULL)
  if (is.null(m)) {
    return(tibble(moderator = spec$moderator[[1]], p_interaction_binary = NA_real_, beta_diff = NA_real_))
  }
  term <- extract_term(m, "sim_mean:group_flag|group_flag:sim_mean")

  tibble(
    moderator = spec$moderator[[1]],
    p_interaction_binary = term$p_value,
    beta_diff = term$estimate
  )
}

run_continuous_interaction_df <- function(df_rule, spec, control_terms) {
  if (all(is.na(df_rule$moderator_centered))) {
    return(
      tibble(
        moderator = spec$moderator[[1]],
        p_interaction_continuous = NA_real_,
        beta_interaction_continuous = NA_real_,
        N_interaction_continuous = NA_integer_
      )
    )
  }

  formula_cont <- build_continuous_interaction_formula("ln_RevPAR_clean", "sim_mean", "moderator_centered", control_terms)
  df_use <- df_rule %>% filter(!is.na(moderator_centered))
  if (nrow(df_use) == 0) {
    return(
      tibble(
        moderator = spec$moderator[[1]],
        p_interaction_continuous = NA_real_,
        beta_interaction_continuous = NA_real_,
        N_interaction_continuous = 0L
      )
    )
  }

  m <- tryCatch(feols(formula_cont, data = df_use, cluster = ~HotelID), error = function(e) NULL)
  if (is.null(m)) {
    return(
      tibble(
        moderator = spec$moderator[[1]],
        p_interaction_continuous = NA_real_,
        beta_interaction_continuous = NA_real_,
        N_interaction_continuous = nrow(df_use)
      )
    )
  }
  term <- extract_term(m, "sim_mean:moderator_centered|moderator_centered:sim_mean")

  tibble(
    moderator = spec$moderator[[1]],
    p_interaction_continuous = term$p_value,
    beta_interaction_continuous = term$estimate,
    N_interaction_continuous = nobs(m)
  )
}

run_permutation_diff_df <- function(df_rule, rule_id, spec, control_terms, base_reps = perm_reps_base, refine_reps = perm_reps_refine) {
  if (nrow(df_rule) == 0 || n_distinct(df_rule$group_flag) < 2) {
    return(tibble(moderator = spec$moderator[[1]], group_rule = rule_id, p_diff_perm = NA_real_, reps_used = 0L))
  }

  observed_formula <- build_binary_interaction_formula("ln_RevPAR_clean", "sim_mean", "group_flag", control_terms)
  observed_model <- tryCatch(feols(observed_formula, data = df_rule, cluster = ~HotelID), error = function(e) NULL)
  if (is.null(observed_model)) {
    return(tibble(moderator = spec$moderator[[1]], group_rule = rule_id, p_diff_perm = NA_real_, reps_used = 0L))
  }
  observed_term <- extract_term(observed_model, "sim_mean:group_flag|group_flag:sim_mean")
  observed_beta <- abs(observed_term$estimate)

  if (is.na(observed_beta)) {
    return(tibble(moderator = spec$moderator[[1]], group_rule = rule_id, p_diff_perm = NA_real_, reps_used = 0L))
  }

  if (str_starts(rule_id, "star_")) {
    hotel_grp <- df_rule %>% distinct(HotelID, CityID, group_flag)
    block_list <- split(seq_len(nrow(hotel_grp)), hotel_grp$CityID)

    draw_perm <- function() {
      perm_hotel <- hotel_grp$group_flag
      for (idx in block_list) {
        if (length(idx) > 1) {
          perm_hotel[idx] <- sample(perm_hotel[idx], length(idx), replace = FALSE)
        }
      }
      perm_hotel[match(df_rule$HotelID, hotel_grp$HotelID)]
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

  run_one_perm <- function(dummy_id) {
    set.seed(as.integer(dummy_id + 1000L))
    df_perm <- df_rule %>% mutate(group_perm = draw_perm())
    perm_formula <- build_binary_interaction_formula("ln_RevPAR_clean", "sim_mean", "group_perm", control_terms)
    perm_model <- tryCatch(
      suppressWarnings(feols(perm_formula, data = df_perm, cluster = ~HotelID)),
      error = function(e) NULL
    )
    if (is.null(perm_model)) {
      return(NA_real_)
    }
    abs(extract_term(perm_model, "sim_mean:group_perm|group_perm:sim_mean")$estimate)
  }

  run_perm_batch <- function(n_reps) {
    if (perm_cores <= 1L) {
      return(unlist(lapply(seq_len(n_reps), run_one_perm), use.names = FALSE))
    }
    unlist(mclapply(seq_len(n_reps), run_one_perm, mc.cores = perm_cores), use.names = FALSE)
  }

  perm_stats <- run_perm_batch(base_reps)
  p_diff_perm <- mean(perm_stats >= observed_beta, na.rm = TRUE)
  reps_used <- base_reps

  if (!is.na(p_diff_perm) && p_diff_perm >= 0.05 && p_diff_perm <= 0.15 && refine_reps > base_reps) {
    extra_stats <- run_perm_batch(refine_reps - base_reps)
    perm_stats <- c(perm_stats, extra_stats)
    p_diff_perm <- mean(perm_stats >= observed_beta, na.rm = TRUE)
    reps_used <- refine_reps
  }

  tibble(
    moderator = spec$moderator[[1]],
    group_rule = rule_id,
    p_diff_perm = p_diff_perm,
    reps_used = reps_used
  )
}

evaluate_group_rule <- function(df, spec, rule_id, control_terms, compute_permutation = FALSE) {
  df_rule <- build_rule_sample(df, spec, rule_id)
  rule_info <- rule_meta(rule_id)
  labels <- rule_labels(spec, rule_id)
  min_group_hotels_req <- min_group_hotels_required(spec)

  if (nrow(df_rule) == 0 || n_distinct(df_rule$group_flag) < 2) {
    return(
      tibble(
        moderator = spec$moderator[[1]],
        group_var = spec$group_var[[1]],
        group_rule = rule_id,
        block_scope = rule_info$block_scope,
        boundary_policy = rule_info$boundary_policy,
        star_rule_id = rule_info$star_rule_id,
        low_label = labels$low_label,
        high_label = labels$high_label,
        expected = spec$expected[[1]],
        observations = 0L,
        hotels = 0L,
        n_low = 0L,
        n_high = 0L,
        min_group_n = 0L,
        hotel_low = 0L,
        hotel_high = 0L,
        min_group_hotels = 0L,
        min_group_hotels_req = min_group_hotels_req,
        beta_low = NA_real_,
        p_low = NA_real_,
        beta_high = NA_real_,
        p_high = NA_real_,
        beta_diff = NA_real_,
        p_diff_screen = NA_real_,
        p_diff_perm = NA_real_,
        reps_used = 0L,
        p_interaction_binary = NA_real_,
        p_interaction_continuous = NA_real_,
        beta_interaction_continuous = NA_real_,
        direction_ok = 0L,
        any_group_sig = 0L,
        any_group_sig05 = 0L,
        diff_sig05 = 0L,
        rule_pass_005 = 0L
      )
    )
  }

  fe_formula_local <- build_fe_formula("ln_RevPAR_clean", "sim_mean", control_terms)
  low_model <- tryCatch(feols(fe_formula_local, data = df_rule %>% filter(group_flag == 0), cluster = ~HotelID), error = function(e) NULL)
  high_model <- tryCatch(feols(fe_formula_local, data = df_rule %>% filter(group_flag == 1), cluster = ~HotelID), error = function(e) NULL)
  low_term <- if (is.null(low_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(low_model, "^sim_mean$")
  high_term <- if (is.null(high_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(high_model, "^sim_mean$")
  binary_term <- run_binary_interaction_df(df_rule, spec, control_terms)
  cont_term <- run_continuous_interaction_df(df_rule, spec, control_terms)

  n_low <- sum(df_rule$group_flag == 0, na.rm = TRUE)
  n_high <- sum(df_rule$group_flag == 1, na.rm = TRUE)
  hotel_low <- n_distinct(df_rule$HotelID[df_rule$group_flag == 0])
  hotel_high <- n_distinct(df_rule$HotelID[df_rule$group_flag == 1])
  any_group_sig05 <- as.integer(
    (low_term$estimate < 0 & low_term$p_value < audit_sig_cutoff) |
      (high_term$estimate < 0 & high_term$p_value < audit_sig_cutoff)
  )
  direction_ok <- score_direction(low_term$estimate, high_term$estimate, spec$expected[[1]])
  perm_needed <- direction_ok == 1 &&
    any_group_sig05 == 1 &&
    min(n_low, n_high) >= group_min_n &&
    min(hotel_low, hotel_high) >= min_group_hotels_req
  perm_term <- if (compute_permutation && perm_needed) {
    run_permutation_diff_df(df_rule, rule_id, spec, control_terms)
  } else {
    tibble(
      moderator = spec$moderator[[1]],
      group_rule = rule_id,
      p_diff_perm = NA_real_,
      reps_used = 0L
    )
  }
  diff_sig05 <- as.integer(
    (!is.na(perm_term$p_diff_perm) && perm_term$p_diff_perm < audit_sig_cutoff) |
      (!is.na(binary_term$p_interaction_binary) && binary_term$p_interaction_binary < audit_sig_cutoff)
  )

  tibble(
    moderator = spec$moderator[[1]],
    group_var = spec$group_var[[1]],
    group_rule = rule_id,
    block_scope = rule_info$block_scope,
    boundary_policy = rule_info$boundary_policy,
    star_rule_id = rule_info$star_rule_id,
    low_label = labels$low_label,
    high_label = labels$high_label,
    expected = spec$expected[[1]],
    observations = nrow(df_rule),
    hotels = n_distinct(df_rule$HotelID),
    n_low = n_low,
    n_high = n_high,
    min_group_n = min(n_low, n_high),
    hotel_low = hotel_low,
    hotel_high = hotel_high,
    min_group_hotels = min(hotel_low, hotel_high),
    min_group_hotels_req = min_group_hotels_req,
    beta_low = low_term$estimate,
    p_low = low_term$p_value,
    beta_high = high_term$estimate,
    p_high = high_term$p_value,
    beta_diff = binary_term$beta_diff,
    p_diff_screen = binary_term$p_interaction_binary,
    p_diff_perm = perm_term$p_diff_perm,
    reps_used = perm_term$reps_used,
    p_interaction_binary = binary_term$p_interaction_binary,
    p_interaction_continuous = cont_term$p_interaction_continuous,
    beta_interaction_continuous = cont_term$beta_interaction_continuous,
    direction_ok = direction_ok,
    any_group_sig = as.integer(
      (low_term$estimate < 0 & low_term$p_value < 0.10) |
        (high_term$estimate < 0 & high_term$p_value < 0.10)
    ),
    any_group_sig05 = any_group_sig05,
    diff_sig05 = diff_sig05,
    rule_pass_005 = as.integer(
      direction_ok == 1 &
        any_group_sig05 == 1 &
        diff_sig05 == 1 &
        min(n_low, n_high) >= group_min_n &
        min(hotel_low, hotel_high) >= min_group_hotels_req
    )
  )
}

pick_rule_row <- function(rule_tbl, moderator_name) {
  rule_tbl <- rule_tbl %>%
    mutate(
      rule_rank = vapply(group_rule, function(x) rule_rank_for(moderator_name, x), numeric(1)),
      best_diff_p = pmin(coalesce(p_diff_perm, 1), coalesce(p_interaction_binary, 1), na.rm = TRUE)
    )

  strong <- rule_tbl %>%
    filter(
      direction_ok == 1,
      any_group_sig05 == 1,
      diff_sig05 == 1,
      min_group_n >= group_min_n,
      min_group_hotels >= min_group_hotels_req
    ) %>%
    arrange(best_diff_p, rule_rank)
  if (nrow(strong) > 0) {
    return(strong %>% slice(1))
  }

  medium <- rule_tbl %>%
    filter(
      direction_ok == 1,
      any_group_sig05 == 1,
      min_group_n >= group_min_n,
      min_group_hotels >= min_group_hotels_req
    ) %>%
    arrange(best_diff_p, rule_rank)
  if (nrow(medium) > 0) {
    return(medium %>% slice(1))
  }

  weak <- rule_tbl %>%
    filter(
      direction_ok == 1,
      min_group_n >= group_min_n,
      min_group_hotels >= min_group_hotels_req
    ) %>%
    arrange(best_diff_p, rule_rank)
  if (nrow(weak) > 0) {
    return(weak %>% slice(1))
  }

  rule_tbl %>%
    arrange(best_diff_p, rule_rank) %>%
    slice(1)
}

attach_selected_groups <- function(panel_df, sample_df, selected_rules) {
  out <- panel_df

  for (i in seq_len(nrow(moderator_specs))) {
    spec <- moderator_specs[i, ]
    rule_id <- selected_rules %>%
      filter(moderator == spec$moderator[[1]]) %>%
      pull(group_rule) %>%
      .[[1]]

    prepared <- prepare_group_data(sample_df, spec, rule_id)
    idx <- match(prepared$panel_row_id, out$panel_row_id)

    out[[spec$group_var[[1]]]] <- rep(NA_integer_, nrow(out))
    out[[spec$group_var[[1]]]][idx] <- prepared$group_flag

    if (!is.na(spec$center_var[[1]])) {
      out[[spec$center_var[[1]]]] <- rep(NA_real_, nrow(out))
      out[[spec$center_var[[1]]]][idx] <- prepared$moderator_centered
    }

    out[[paste0("selected_rule_", spec$group_var[[1]])]] <- rule_id
  }

  out
}

run_star_continuous_checks <- function(df, control_terms) {
  out <- list()

  df_raw <- df %>% filter(!is.na(star_class))
  if (nrow(df_raw) > 0) {
    m_raw <- tryCatch(
      feols(
        build_continuous_interaction_formula("ln_RevPAR_clean", "sim_mean", "star_class", control_terms),
        data = df_raw,
        cluster = ~HotelID
      ),
      error = function(e) NULL
    )
    term_raw <- if (is.null(m_raw)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(m_raw, "sim_mean:star_class|star_class:sim_mean")
    out[[length(out) + 1L]] <- tibble(
      sample = selected_sample_name,
      control_family = selected_control_family,
      moderator = "star_ge3",
      group_rule = "star_continuous_raw",
      interaction_type = "continuous_star_raw",
      estimate = term_raw$estimate,
      std_error = NA_real_,
      p_value = term_raw$p_value,
      N = if (is.null(m_raw)) nrow(df_raw) else nobs(m_raw)
    )
  }

  df_dm <- df %>% filter(!is.na(star_class_dm_city))
  if (nrow(df_dm) > 0) {
    m_dm <- tryCatch(
      feols(
        build_continuous_interaction_formula("ln_RevPAR_clean", "sim_mean", "star_class_dm_city", control_terms),
        data = df_dm,
        cluster = ~HotelID
      ),
      error = function(e) NULL
    )
    term_dm <- if (is.null(m_dm)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(m_dm, "sim_mean:star_class_dm_city|star_class_dm_city:sim_mean")
    out[[length(out) + 1L]] <- tibble(
      sample = selected_sample_name,
      control_family = selected_control_family,
      moderator = "star_ge3",
      group_rule = "star_continuous_dm_city",
      interaction_type = "continuous_star_dm_city",
      estimate = term_dm$estimate,
      std_error = NA_real_,
      p_value = term_dm$p_value,
      N = if (is.null(m_dm)) nrow(df_dm) else nobs(m_dm)
    )
  }

  bind_rows(out)
}

panel_model_final <- read_dta(path_panel_main)
sample_audit_prev <- read_csv(path_sample_audit, show_col_types = FALSE)

selected_rule <- "winsor_city_1_99"
selected_focus_threshold <- 110L
selected_sample_name <- paste(selected_rule, paste0("focus", selected_focus_threshold), sep = "__")
selected_control_family <- "rich8_current"

selected_control_terms <- control_family_specs %>%
  filter(control_family == selected_control_family) %>%
  pull(control_terms) %>%
  .[[1]]

selected_required_vars <- unique(c("sim_mean", selected_control_terms))
selected_dm_source_vars <- unique(c("ln_RevPAR_clean", "sim_mean", selected_control_terms))

panel_model_final <- panel_model_final %>%
  mutate(
    focus_simple_keep = as.integer(review_total_hotel >= selected_focus_threshold),
    review_focus_threshold = selected_focus_threshold,
    main_sample_rule = selected_sample_name,
    main_sample_keep = as.integer(
      focus_simple_keep == 1 &
        RevPAR_clean > 0 &
        lag_RevPAR_clean > 0 &
        !if_any(all_of(selected_required_vars), is.na)
    ),
    selected_control_family = selected_control_family
  ) %>%
  group_by(CityID) %>%
  mutate(
    star_class_dm_city = if_else(
      is.na(star_class),
      NA_real_,
      star_class - mean(star_class, na.rm = TRUE)
    )
  ) %>%
  ungroup() %>%
  group_by(CityID, Year, Mon) %>%
  mutate(
    across(
      all_of(selected_dm_source_vars),
      ~ {
        use_idx <- main_sample_keep == 1 & !is.na(.x)
        out <- rep(NA_real_, length(.x))
        if (any(use_idx)) {
          mu <- mean(.x[use_idx], na.rm = TRUE)
          keep_idx <- main_sample_keep == 1 & !is.na(.x)
          out[keep_idx] <- .x[keep_idx] - mu
        }
        out
      },
      .names = "{.col}_dm_cym"
    )
  ) %>%
  ungroup() %>%
  mutate(
    main_sample_keep = as.integer(
      main_sample_keep == 1 &
        !if_any(all_of(paste0(selected_dm_source_vars, "_dm_cym")), is.na)
    )
  )

selected_sample <- panel_model_final %>% filter(main_sample_keep == 1)

target_moderators <- c("rating_last", "star_ge3")

old_rule_scan <- if (file.exists(path_out_hetero_rule_scan)) read_csv(path_out_hetero_rule_scan, show_col_types = FALSE) else tibble()
old_core <- if (file.exists(path_out_hetero_control_scan)) read_csv(path_out_hetero_control_scan, show_col_types = FALSE) else tibble()
old_diff_tests <- if (file.exists(path_out_hetero_diff_tests)) read_csv(path_out_hetero_diff_tests, show_col_types = FALSE) else tibble()
old_interaction <- if (file.exists(path_out_hetero_interaction)) read_csv(path_out_hetero_interaction, show_col_types = FALSE) else tibble()

rule_grid_base <- moderator_specs %>%
  filter(moderator %in% target_moderators)
rule_grid_base$rule_ids <- purrr::map(seq_len(nrow(rule_grid_base)), function(i) available_rule_ids(rule_grid_base[i, ]))

rule_grid <- rule_grid_base %>%
  select(-allow_quantile) %>%
  unnest(rule_ids, names_repair = "minimal") %>%
  rename(group_rule = rule_ids)

rule_scan_base <- map_dfr(
  seq_len(nrow(rule_grid)),
  function(i) {
    spec <- rule_grid[i, c("moderator", "source_var", "group_var", "center_var", "low_label", "high_label", "expected")]
    evaluate_group_rule(selected_sample, spec, rule_grid$group_rule[[i]], selected_control_terms, compute_permutation = FALSE)
  }
) %>%
  mutate(
    main_sample_rule = selected_sample_name,
    revenue_rule = selected_rule,
    focus_threshold = selected_focus_threshold,
    control_family = selected_control_family,
    rule_rank = vapply(seq_len(n()), function(i) rule_rank_for(moderator[[i]], group_rule[[i]]), numeric(1))
  )

perm_candidates <- bind_rows(
  rule_scan_base %>%
    filter(
      moderator == "rating_last",
      direction_ok == 1,
      any_group_sig05 == 1,
      min_group_n >= group_min_n,
      min_group_hotels >= min_group_hotels_req
    ) %>%
    arrange(coalesce(p_interaction_binary, 1), rule_rank) %>%
    slice_head(n = 6),
  rule_scan_base %>%
    filter(
      moderator == "star_ge3",
      min_group_n >= group_min_n,
      min_group_hotels >= min_group_hotels_req
    ) %>%
    arrange(coalesce(p_interaction_binary, 1), rule_rank) %>%
    slice_head(n = 5)
) %>%
  distinct(moderator, group_rule, .keep_all = TRUE)

perm_updates <- map_dfr(
  seq_len(nrow(perm_candidates)),
  function(i) {
    moderator_name <- perm_candidates$moderator[[i]]
    rule_id <- perm_candidates$group_rule[[i]]
    spec <- moderator_specs %>%
      filter(moderator == moderator_name) %>%
      select(moderator, source_var, group_var, center_var, low_label, high_label, expected)
    df_rule <- build_rule_sample(selected_sample, spec, rule_id)
    run_permutation_diff_df(df_rule, rule_id, spec, selected_control_terms)
  }
)

rule_scan <- rule_scan_base %>%
  select(-p_diff_perm, -reps_used, -diff_sig05, -rule_pass_005) %>%
  left_join(
    perm_updates %>% select(moderator, group_rule, p_diff_perm, reps_used),
    by = c("moderator", "group_rule")
  ) %>%
  mutate(
    diff_sig05 = as.integer(
      (!is.na(p_diff_perm) && p_diff_perm < audit_sig_cutoff) |
        (!is.na(p_interaction_binary) && p_interaction_binary < audit_sig_cutoff)
    ),
    rule_pass_005 = as.integer(
      direction_ok == 1 &
        any_group_sig05 == 1 &
        diff_sig05 == 1 &
        min_group_n >= group_min_n &
        min_group_hotels >= min_group_hotels_req
    )
  )

selected_rules_new <- rule_scan %>%
  group_by(moderator) %>%
  group_modify(~pick_rule_row(.x, .y$moderator[[1]])) %>%
  ungroup()

selected_rules <- bind_rows(
  old_core %>% filter(!moderator %in% target_moderators),
  selected_rules_new
)

panel_model_final <- attach_selected_groups(panel_model_final, selected_sample, selected_rules)

rule_scan <- bind_rows(
  old_rule_scan %>% filter(!moderator %in% target_moderators),
  rule_scan
) %>%
  arrange(moderator, rule_rank)

heterogeneity_core <- bind_rows(
  old_core %>% filter(!moderator %in% target_moderators),
  selected_rules_new
) %>%
  mutate(
    sample = selected_sample_name,
    diff_sig05 = as.integer(
      (!is.na(p_diff_perm) & p_diff_perm < audit_sig_cutoff) |
        (!is.na(p_interaction_binary) & p_interaction_binary < audit_sig_cutoff)
    ),
    rule_pass_005 = as.integer(
      direction_ok == 1 &
        any_group_sig05 == 1 &
        diff_sig05 == 1 &
        min_group_n >= group_min_n &
        min_group_hotels >= min_group_hotels_req
    )
  )

star_continuous_checks <- run_star_continuous_checks(selected_sample, selected_control_terms)

heterogeneity_interaction_new <- selected_rules_new %>%
  transmute(
    sample,
    control_family,
    moderator,
    group_rule,
    interaction_type = "binary",
    estimate = beta_diff,
    std_error = NA_real_,
    p_value = p_interaction_binary,
    N = observations
  ) %>%
  bind_rows(
    selected_rules_new %>%
      transmute(
        sample,
        control_family,
        moderator,
        group_rule,
        interaction_type = "continuous",
        estimate = beta_interaction_continuous,
        std_error = NA_real_,
        p_value = p_interaction_continuous,
        N = observations
      )
  ) %>%
  bind_rows(star_continuous_checks)

heterogeneity_interaction <- bind_rows(
  old_interaction %>% filter(!moderator %in% target_moderators),
  heterogeneity_interaction_new
)

heterogeneity_boundary_scan <- rule_scan %>%
  filter(moderator %in% c("rating_last", "star_ge3")) %>%
  transmute(
    moderator,
    group_rule,
    boundary_policy,
    star_rule_id,
    n_low,
    n_high,
    hotel_low,
    hotel_high,
    beta_low,
    p_low,
    beta_high,
    p_high,
    p_diff_perm,
    p_interaction_binary
  )

heterogeneity_diff_tests_new <- selected_rules_new %>%
  select(
    sample,
    control_family,
    moderator,
    group_rule,
    boundary_policy,
    star_rule_id,
    low_label,
    high_label,
    hotel_low,
    hotel_high,
    min_group_hotels,
    beta_low,
    p_low,
    beta_high,
    p_high,
    beta_diff,
    p_diff_screen,
    p_diff_perm,
    p_interaction_binary,
    p_interaction_continuous,
    reps_used,
    direction_ok,
    any_group_sig,
    any_group_sig05,
    diff_sig05,
    rule_pass_005,
    min_group_n
  )

heterogeneity_diff_tests <- bind_rows(
  old_diff_tests %>% filter(!moderator %in% target_moderators),
  heterogeneity_diff_tests_new
)

selected_fe_formula <- build_fe_formula("ln_RevPAR_clean", "sim_mean", selected_control_terms)
selected_ols_formula <- build_ols_formula("ln_RevPAR_clean", "sim_mean", selected_control_terms)
selected_fe_formula_dm <- build_fe_formula("ln_RevPAR_clean_dm_cym", "sim_mean_dm_cym", paste0(selected_control_terms, "_dm_cym"))
selected_ols_formula_dm <- build_ols_formula("ln_RevPAR_clean_dm_cym", "sim_mean_dm_cym", paste0(selected_control_terms, "_dm_cym"))

selected_fe <- feols(selected_fe_formula, data = selected_sample, cluster = ~HotelID)
selected_ols <- feols(selected_ols_formula, data = selected_sample, cluster = ~HotelID)
selected_fe_dm <- feols(selected_fe_formula_dm, data = selected_sample, cluster = ~HotelID)
selected_ols_dm <- feols(selected_ols_formula_dm, data = selected_sample, cluster = ~HotelID)

selected_fe_term <- extract_term(selected_fe, "^sim_mean$")
selected_ols_term <- extract_term(selected_ols, "^sim_mean$")
selected_fe_dm_term <- extract_term(selected_fe_dm, "^sim_mean_dm_cym$")
selected_ols_dm_term <- extract_term(selected_ols_dm, "^sim_mean_dm_cym$")

dir_score <- sum(heterogeneity_core$direction_ok, na.rm = TRUE)
hetero_diff_lt05 <- sum(heterogeneity_core$diff_sig05, na.rm = TRUE)
volume_last_pass_005 <- {
  tmp_val <- heterogeneity_core %>%
    filter(moderator == "volume_last") %>%
    pull(rule_pass_005)
  if (length(tmp_val) == 0 || all(is.na(tmp_val))) 0L else tmp_val[[1]]
}

strict_candidate <- as.integer(
  nrow(selected_sample) > 30316 &&
    n_distinct(selected_sample$HotelID) >= 474 &&
    !is.na(selected_fe_term$estimate) && selected_fe_term$estimate < 0 && selected_fe_term$p_value < audit_sig_cutoff &&
    !is.na(selected_ols_term$estimate) && selected_ols_term$estimate < 0 && selected_ols_term$p_value < audit_sig_cutoff &&
    dir_score >= 4 &&
    volume_last_pass_005 == 1
)

selection_status <- if (strict_candidate == 1L) "strict_winner" else "near_winner"

sample_audit_updated <- tibble(
  main_sample_rule = selected_sample_name,
  revenue_rule = selected_rule,
  focus_threshold = selected_focus_threshold,
  control_family = selected_control_family,
  selection_status = selection_status,
  ars_window = if ("ars_window" %in% names(sample_audit_prev)) sample_audit_prev$ars_window[[1]] else 10,
  observations = nrow(selected_sample),
  hotels = n_distinct(selected_sample$HotelID),
  rev_outlier_share = mean(panel_model_final$rev_outlier_drop, na.rm = TRUE),
  fe_ols_shared_n = nrow(selected_sample),
  sample_min_group_n = min(heterogeneity_core$min_group_n, na.rm = TRUE),
  dir_score = dir_score,
  hetero_diff_lt05 = hetero_diff_lt05,
  volume_last_pass_005 = volume_last_pass_005,
  demean_fe_ok = !is.na(selected_fe_dm_term$estimate) && selected_fe_dm_term$estimate < 0 && selected_fe_dm_term$p_value < audit_sig_cutoff,
  demean_ols_ok = !is.na(selected_ols_dm_term$estimate) && selected_ols_dm_term$estimate < 0 && selected_ols_dm_term$p_value < 0.10,
  strict_candidate = strict_candidate,
  strict_rank = if (strict_candidate == 1L) 1L else NA_integer_
)

write_dta(panel_model_final, path_panel_main)
write_csv(sample_audit_updated, path_sample_audit)
write_csv(rule_scan, path_out_hetero_rule_scan)
write_csv(heterogeneity_core, path_out_hetero_threshold_scan)
write_csv(heterogeneity_core, path_out_hetero_control_scan)
write_csv(heterogeneity_core, path_out_hetero_core)
write_csv(heterogeneity_diff_tests, path_out_hetero_diff_tests)
write_csv(heterogeneity_interaction, path_out_hetero_interaction)
write_csv(heterogeneity_boundary_scan, path_out_hetero_boundary_scan)

print(sample_audit_updated)
print(heterogeneity_core)
