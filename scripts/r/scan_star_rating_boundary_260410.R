library(dplyr)
library(readr)
library(haven)
library(stringr)
library(tidyr)
library(purrr)
library(fixest)

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

path_panel <- file.path(data_dir, "valid_match_review_acc_260407_main.dta")
path_rule_scan <- file.path(scan_dir, "heterogeneity_rule_scan_260407.csv")
path_core <- file.path(scan_dir, "heterogeneity_control_scan_260407.csv")
path_diff <- file.path(csv_dir, "heterogeneity_diff_tests_260407.csv")
path_inter <- file.path(csv_dir, "heterogeneity_interaction_260407.csv")
path_boundary <- file.path(scan_dir, "heterogeneity_boundary_scan_260407.csv")

group_min_n <- 1000L
group_min_hotels_rating_last <- 40L
group_min_hotels_star <- 20L
audit_sig_cutoff <- 0.05

selected_sample_name <- "winsor_city_1_99__focus110"
selected_control_family <- "rich8_current"
selected_control_terms <- c(
  "ln_recent_volumn",
  "recent_sd",
  "ln_lag_volumn_acc",
  "lag_avg_rating_acc",
  "lag_sd_acc",
  "lag_avg_rating_month",
  "ln_avg_com_RevPAR",
  "ln_lag_RevPAR_clean"
)

rating_rule_priority <- c(
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

safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_median <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)
safe_quantile <- function(x, p) if (all(is.na(x))) NA_real_ else as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))

extract_term <- function(model, term_pattern) {
  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)
  rownames(ct) <- NULL
  hit <- ct %>% filter(str_detect(term, term_pattern)) %>% slice(1)
  if (nrow(hit) == 0) {
    return(tibble(term = NA_character_, estimate = NA_real_, p_value = NA_real_))
  }
  tibble(term = hit$term[[1]], estimate = hit$Estimate[[1]], p_value = hit$`Pr(>|t|)`[[1]])
}

score_direction <- function(low_beta, high_beta, expectation) {
  if (any(is.na(c(low_beta, high_beta)))) return(0L)
  if (expectation == "low_stronger") return(as.integer(low_beta < high_beta))
  if (expectation == "high_stronger") return(as.integer(high_beta < low_beta))
  0L
}

rule_meta <- function(rule_id) {
  if (str_starts(rule_id, "star_")) {
    return(list(block_vars = c("CityID"), block_scope = "city", boundary_policy = "fixed", star_rule_id = rule_id))
  }
  block_map <- list(
    zipym = c("Zip", "Year", "Mon"),
    cityym = c("CityID", "Year", "Mon"),
    zipy = c("Zip", "Year"),
    ym = c("Year", "Mon"),
    cityy = c("CityID", "Year")
  )
  m <- str_match(rule_id, "^(zipym|cityym|zipy|ym|cityy)_(median_ge_lt|median_gt_le|median_strict|4060_inclusive|4060_strict|3070_inclusive|3070_strict)$")
  if (all(is.na(m))) stop(paste("Unknown rule", rule_id))
  list(block_vars = block_map[[m[[2]]]], block_scope = m[[2]], boundary_policy = m[[3]], star_rule_id = NA_character_)
}

build_fe_formula <- function(dep_var, sim_var, control_terms) {
  as.formula(paste(dep_var, "~", paste(c(sim_var, control_terms), collapse = " + "), "| HotelID + year_month"))
}

build_binary_formula <- function(dep_var, sim_var, group_var, control_terms) {
  as.formula(paste(dep_var, "~", paste(c(sim_var, group_var, paste0(sim_var, ":", group_var), control_terms), collapse = " + "), "| HotelID + year_month"))
}

build_cont_formula <- function(dep_var, sim_var, center_var, control_terms) {
  as.formula(paste(dep_var, "~", paste(c(sim_var, center_var, paste0(sim_var, ":", center_var), control_terms), collapse = " + "), "| HotelID + year_month"))
}

prepare_rating_rule <- function(df, rule_id) {
  meta <- rule_meta(rule_id)
  block_vars <- meta$block_vars
  split_type <- meta$boundary_policy
  tmp <- df %>%
    mutate(raw_value = lag_avg_rating_month) %>%
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
  block_df <- tmp %>%
    select(all_of(block_vars)) %>%
    mutate(block_id = as.character(do.call(interaction, c(across(everything()), list(drop = TRUE, lex.order = TRUE)))))
  tmp %>%
    bind_cols(block_df %>% select(block_id)) %>%
    transmute(panel_row_id, HotelID, CityID, Year, Mon, year_month, group_flag, moderator_centered, block_id)
}

prepare_star_rule <- function(df, rule_id) {
  df %>%
    transmute(
      panel_row_id, HotelID, CityID, Year, Mon, year_month, star_class,
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
}

evaluate_rule <- function(df, moderator_name, rule_id) {
  expected <- if (moderator_name == "star_ge3") "high_stronger" else "low_stronger"
  min_hotels_req <- if (moderator_name == "star_ge3") group_min_hotels_star else group_min_hotels_rating_last
  labels <- if (moderator_name == "star_ge3") {
    switch(
      rule_id,
      star_lt3_ge3 = list(low = "<3", high = ">=3"),
      star_le3_gt3 = list(low = "<=3", high = ">3"),
      star_le35_gt35 = list(low = "<=3.5", high = ">3.5"),
      star_eq3_ge35 = list(low = "==3", high = ">=3.5"),
      star_lt3_gt3 = list(low = "<3", high = ">3")
    )
  } else {
    list(low = "low", high = "high")
  }

  prepared <- if (moderator_name == "star_ge3") prepare_star_rule(df, rule_id) else prepare_rating_rule(df, rule_id)
  df_rule <- df %>%
    left_join(prepared, by = c("panel_row_id", "HotelID", "CityID", "Year", "Mon", "year_month")) %>%
    filter(!is.na(group_flag))

  meta <- if (moderator_name == "star_ge3") list(block_scope = "city", boundary_policy = "fixed", star_rule_id = rule_id) else rule_meta(rule_id)

  if (nrow(df_rule) == 0 || n_distinct(df_rule$group_flag) < 2) {
    return(tibble(
      moderator = moderator_name, group_var = if (moderator_name == "star_ge3") "high_star_group" else "high_rating_month",
      group_rule = rule_id, block_scope = meta$block_scope, boundary_policy = meta$boundary_policy, star_rule_id = meta$star_rule_id,
      low_label = labels$low, high_label = labels$high, expected = expected, observations = 0L, hotels = 0L,
      n_low = 0L, n_high = 0L, min_group_n = 0L, hotel_low = 0L, hotel_high = 0L, min_group_hotels = 0L,
      min_group_hotels_req = min_hotels_req, beta_low = NA_real_, p_low = NA_real_, beta_high = NA_real_, p_high = NA_real_,
      beta_diff = NA_real_, p_diff_screen = NA_real_, p_diff_perm = NA_real_, reps_used = 0L,
      p_interaction_binary = NA_real_, p_interaction_continuous = NA_real_, beta_interaction_continuous = NA_real_,
      direction_ok = 0L, any_group_sig = 0L, any_group_sig05 = 0L, diff_sig05 = 0L, rule_pass_005 = 0L
    ))
  }

  fe_formula <- build_fe_formula("ln_RevPAR_clean", "sim_mean", selected_control_terms)
  low_model <- tryCatch(feols(fe_formula, data = df_rule %>% filter(group_flag == 0), cluster = ~HotelID), error = function(e) NULL)
  high_model <- tryCatch(feols(fe_formula, data = df_rule %>% filter(group_flag == 1), cluster = ~HotelID), error = function(e) NULL)
  low_term <- if (is.null(low_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(low_model, "^sim_mean$")
  high_term <- if (is.null(high_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(high_model, "^sim_mean$")
  bin_model <- tryCatch(feols(build_binary_formula("ln_RevPAR_clean", "sim_mean", "group_flag", selected_control_terms), data = df_rule, cluster = ~HotelID), error = function(e) NULL)
  bin_term <- if (is.null(bin_model)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(bin_model, "sim_mean:group_flag|group_flag:sim_mean")

  cont_term <- tibble(estimate = NA_real_, p_value = NA_real_)

  n_low <- sum(df_rule$group_flag == 0, na.rm = TRUE)
  n_high <- sum(df_rule$group_flag == 1, na.rm = TRUE)
  hotel_low <- n_distinct(df_rule$HotelID[df_rule$group_flag == 0])
  hotel_high <- n_distinct(df_rule$HotelID[df_rule$group_flag == 1])
  direction_ok <- score_direction(low_term$estimate, high_term$estimate, expected)
  any_group_sig05 <- as.integer((low_term$estimate < 0 & low_term$p_value < audit_sig_cutoff) | (high_term$estimate < 0 & high_term$p_value < audit_sig_cutoff))

  tibble(
    moderator = moderator_name,
    group_var = if (moderator_name == "star_ge3") "high_star_group" else "high_rating_month",
    group_rule = rule_id,
    block_scope = meta$block_scope,
    boundary_policy = meta$boundary_policy,
    star_rule_id = meta$star_rule_id,
    low_label = labels$low,
    high_label = labels$high,
    expected = expected,
    observations = nrow(df_rule),
    hotels = n_distinct(df_rule$HotelID),
    n_low = n_low,
    n_high = n_high,
    min_group_n = min(n_low, n_high),
    hotel_low = hotel_low,
    hotel_high = hotel_high,
    min_group_hotels = min(hotel_low, hotel_high),
    min_group_hotels_req = min_hotels_req,
    beta_low = low_term$estimate,
    p_low = low_term$p_value,
    beta_high = high_term$estimate,
    p_high = high_term$p_value,
    beta_diff = bin_term$estimate,
    p_diff_screen = bin_term$p_value,
    p_diff_perm = NA_real_,
    reps_used = 0L,
    p_interaction_binary = bin_term$p_value,
    p_interaction_continuous = cont_term$p_value,
    beta_interaction_continuous = cont_term$estimate,
    direction_ok = direction_ok,
    any_group_sig = as.integer((low_term$estimate < 0 & low_term$p_value < 0.10) | (high_term$estimate < 0 & high_term$p_value < 0.10)),
    any_group_sig05 = any_group_sig05,
    diff_sig05 = as.integer(!is.na(bin_term$p_value) & bin_term$p_value < audit_sig_cutoff),
    rule_pass_005 = 0L
  )
}

pick_rule <- function(rule_tbl, moderator_name) {
  priority <- if (moderator_name == "rating_last") rating_rule_priority else star_rule_priority
  rule_tbl <- rule_tbl %>%
    mutate(rule_rank = match(group_rule, priority), best_diff_p = pmin(coalesce(p_diff_perm, 1), coalesce(p_interaction_binary, 1), na.rm = TRUE))
  strong <- rule_tbl %>% filter(direction_ok == 1, any_group_sig05 == 1, diff_sig05 == 1, min_group_n >= group_min_n, min_group_hotels >= min_group_hotels_req) %>% arrange(best_diff_p, rule_rank)
  if (nrow(strong) > 0) return(strong %>% slice(1))
  medium <- rule_tbl %>% filter(direction_ok == 1, any_group_sig05 == 1, min_group_n >= group_min_n, min_group_hotels >= min_group_hotels_req) %>% arrange(best_diff_p, rule_rank)
  if (nrow(medium) > 0) return(medium %>% slice(1))
  weak <- rule_tbl %>% filter(direction_ok == 1, min_group_n >= group_min_n, min_group_hotels >= min_group_hotels_req) %>% arrange(best_diff_p, rule_rank)
  if (nrow(weak) > 0) return(weak %>% slice(1))
  rule_tbl %>% arrange(best_diff_p, rule_rank) %>% slice(1)
}

panel <- read_dta(path_panel) %>%
  mutate(
    star_class_dm_city = star_class - ave(star_class, CityID, FUN = function(x) mean(x, na.rm = TRUE))
  )
sample_df <- panel %>% filter(main_sample_keep == 1)

rating_scan <- map_dfr(rating_rule_priority, ~evaluate_rule(sample_df, "rating_last", .x))
star_scan <- map_dfr(star_rule_priority, ~evaluate_rule(sample_df, "star_ge3", .x))
scan_new <- bind_rows(rating_scan, star_scan) %>%
  mutate(
    main_sample_rule = selected_sample_name,
    revenue_rule = "winsor_city_1_99",
    focus_threshold = 110L,
    control_family = selected_control_family,
    rule_rank = match(group_rule, c(rating_rule_priority, star_rule_priority))
  )

old_diff <- read_csv(path_diff, show_col_types = FALSE)

perm_alias <- tibble(
  moderator = c("rating_last", "star_ge3"),
  group_rule = c("zipy_3070_inclusive", "star_lt3_ge3"),
  alias_rule = c("zipy_3070", "star_fixed")
)

old_perm_lookup <- old_diff %>%
  select(moderator, group_rule, p_diff_perm, reps_used) %>%
  bind_rows(
    old_diff %>%
      inner_join(perm_alias, by = c("moderator", "group_rule" = "alias_rule")) %>%
      transmute(moderator, group_rule, p_diff_perm, reps_used)
  ) %>%
  distinct(moderator, group_rule, .keep_all = TRUE)

scan_new <- scan_new %>%
  select(-p_diff_perm, -reps_used, -diff_sig05, -rule_pass_005) %>%
  left_join(old_perm_lookup, by = c("moderator", "group_rule")) %>%
  mutate(
    diff_sig05 = as.integer((!is.na(p_diff_perm) & p_diff_perm < audit_sig_cutoff) | (!is.na(p_interaction_binary) & p_interaction_binary < audit_sig_cutoff)),
    rule_pass_005 = as.integer(direction_ok == 1 & any_group_sig05 == 1 & diff_sig05 == 1 & min_group_n >= group_min_n & min_group_hotels >= min_group_hotels_req)
  )

selected_new <- bind_rows(
  pick_rule(scan_new %>% filter(moderator == "rating_last"), "rating_last"),
  pick_rule(scan_new %>% filter(moderator == "star_ge3"), "star_ge3")
) %>%
  mutate(sample = selected_sample_name, best_diff_p = pmin(coalesce(p_diff_perm, 1), coalesce(p_interaction_binary, 1), na.rm = TRUE))

rating_selected_rule <- selected_new %>% filter(moderator == "rating_last") %>% pull(group_rule) %>% .[[1]]
rating_selected_prepared <- prepare_rating_rule(sample_df, rating_selected_rule)
rating_selected_df <- sample_df %>%
  left_join(rating_selected_prepared, by = c("panel_row_id", "HotelID", "CityID", "Year", "Mon", "year_month")) %>%
  filter(!is.na(group_flag), !is.na(moderator_centered))
rating_cont_term <- if (nrow(rating_selected_df) == 0) {
  tibble(estimate = NA_real_, p_value = NA_real_)
} else {
  m <- tryCatch(feols(build_cont_formula("ln_RevPAR_clean", "sim_mean", "moderator_centered", selected_control_terms), data = rating_selected_df, cluster = ~HotelID), error = function(e) NULL)
  if (is.null(m)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(m, "sim_mean:moderator_centered|moderator_centered:sim_mean")
}

selected_new <- selected_new %>%
  mutate(
    p_interaction_continuous = if_else(moderator == "rating_last", rating_cont_term$p_value[[1]], p_interaction_continuous),
    beta_interaction_continuous = if_else(moderator == "rating_last", rating_cont_term$estimate[[1]], beta_interaction_continuous)
  )

star_interactions <- bind_rows(
  {
    df_raw <- sample_df %>% filter(!is.na(star_class))
    m <- tryCatch(feols(build_cont_formula("ln_RevPAR_clean", "sim_mean", "star_class", selected_control_terms), data = df_raw, cluster = ~HotelID), error = function(e) NULL)
    term <- if (is.null(m)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(m, "sim_mean:star_class|star_class:sim_mean")
    tibble(sample = selected_sample_name, control_family = selected_control_family, moderator = "star_ge3", group_rule = "star_continuous_raw", interaction_type = "continuous_star_raw", estimate = term$estimate, std_error = NA_real_, p_value = term$p_value, N = if (is.null(m)) nrow(df_raw) else nobs(m))
  },
  {
    df_dm <- sample_df %>% filter(!is.na(star_class_dm_city))
    m <- tryCatch(feols(build_cont_formula("ln_RevPAR_clean", "sim_mean", "star_class_dm_city", selected_control_terms), data = df_dm, cluster = ~HotelID), error = function(e) NULL)
    term <- if (is.null(m)) tibble(estimate = NA_real_, p_value = NA_real_) else extract_term(m, "sim_mean:star_class_dm_city|star_class_dm_city:sim_mean")
    tibble(sample = selected_sample_name, control_family = selected_control_family, moderator = "star_ge3", group_rule = "star_continuous_dm_city", interaction_type = "continuous_star_dm_city", estimate = term$estimate, std_error = NA_real_, p_value = term$p_value, N = if (is.null(m)) nrow(df_dm) else nobs(m))
  }
)

selected_interactions <- selected_new %>%
  transmute(sample, control_family = selected_control_family, moderator, group_rule, interaction_type = "binary", estimate = beta_diff, std_error = NA_real_, p_value = p_interaction_binary, N = observations) %>%
  bind_rows(
    selected_new %>%
      transmute(sample, control_family = selected_control_family, moderator, group_rule, interaction_type = "continuous", estimate = beta_interaction_continuous, std_error = NA_real_, p_value = p_interaction_continuous, N = observations)
  ) %>%
  bind_rows(star_interactions)

boundary_scan <- scan_new %>%
  transmute(moderator, group_rule, boundary_policy, star_rule_id, n_low, n_high, hotel_low, hotel_high, beta_low, p_low, beta_high, p_high, p_diff_perm, p_interaction_binary)

old_rule <- read_csv(path_rule_scan, show_col_types = FALSE)
old_core <- read_csv(path_core, show_col_types = FALSE)
old_inter <- read_csv(path_inter, show_col_types = FALSE)

rule_out <- bind_rows(old_rule %>% filter(!moderator %in% c("rating_last", "star_ge3")), scan_new) %>% arrange(moderator, rule_rank)
core_out <- bind_rows(old_core %>% filter(!moderator %in% c("rating_last", "star_ge3")), selected_new)
diff_out <- bind_rows(
  old_diff %>% filter(!moderator %in% c("rating_last", "star_ge3")),
  selected_new %>% select(sample, control_family, moderator, group_rule, low_label, high_label, beta_low, p_low, beta_high, p_high, beta_diff, p_diff_screen, p_diff_perm, p_interaction_binary, p_interaction_continuous, reps_used, direction_ok, any_group_sig, any_group_sig05, diff_sig05, rule_pass_005, min_group_n)
)
inter_out <- bind_rows(old_inter %>% filter(!moderator %in% c("rating_last", "star_ge3")), selected_interactions)

write_csv(rule_out, path_rule_scan)
write_csv(core_out, path_core)
write_csv(diff_out, path_diff)
write_csv(inter_out, path_inter)
write_csv(boundary_scan, path_boundary)

print(selected_new %>% select(moderator, group_rule, beta_low, p_low, beta_high, p_high, p_interaction_binary, p_diff_perm, direction_ok, rule_pass_005))
