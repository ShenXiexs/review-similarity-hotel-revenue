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
if ("setFixest_nthreads" %in% getNamespaceExports("fixest")) {
  setFixest_nthreads(1)
}

RUN_ID <- "260501"
PERM_REPS <- 200L

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

assert_inside_project <- function(paths, project_dir) {
  root <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  normalized <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  outside <- normalized[!startsWith(normalized, paste0(root, "/")) & normalized != root]
  if (length(outside) > 0) {
    stop(paste("Refusing to write outside project root:", paste(outside, collapse = ", ")))
  }
  invisible(TRUE)
}

safe_median <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)
safe_quantile <- function(x, p) if (all(is.na(x))) NA_real_ else as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))

split_high_by_median <- function(x, idx = rep(TRUE, length(x))) {
  out <- rep(NA_integer_, length(x))
  keep <- idx & !is.na(x)
  if (sum(keep) == 0) return(out)
  cutoff <- median(x[keep], na.rm = TRUE)
  out[keep] <- as.integer(x[keep] > cutoff)
  out
}

extract_term <- function(model, pattern) {
  if (is.null(model)) {
    return(tibble(term = NA_character_, estimate = NA_real_, std_error = NA_real_, p_value = NA_real_))
  }
  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)
  rownames(ct) <- NULL
  hit <- ct %>% filter(str_detect(term, pattern)) %>% slice(1)
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

is_neg_sig <- function(term, alpha = 0.10) {
  isTRUE(!is.na(term$estimate) && !is.na(term$p_value) && term$estimate < 0 && term$p_value < alpha)
}

control_specs <- list(
  rich8_current = c(
    "ln_recent_volumn", "recent_sd", "ln_lag_volumn_acc",
    "lag_avg_rating_acc", "lag_sd_acc", "lag_avg_rating_month",
    "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"
  ),
  quality6 = c(
    "ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_acc",
    "lag_avg_rating_month", "ln_avg_com_RevPAR", "review_freshness",
    "ln_lag_RevPAR_clean"
  ),
  base4_acc = c(
    "ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_acc",
    "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"
  ),
  base4_month = c(
    "ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_month",
    "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"
  ),
  lean3 = c(
    "ln_recent_volumn", "ln_lag_volumn_acc",
    "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"
  ),
  momentum_plus = c(
    "ln_recent_volumn", "ln_lag_volumn_acc", "lag_avg_rating_acc",
    "ln_avg_com_RevPAR", "rating_momentum", "volume_momentum",
    "review_freshness", "ln_lag_RevPAR_clean"
  )
)

dep_vars <- c("ln_RevPAR_clean", "ln_RevPAR_w199", "ln_RevPAR", "d_ln_RevPAR")
sample_names <- c("full", "pre2020", "exclude2020", "post2013", "post2013_excl2020", "focus50", "focus100", "star_observed")

sample_keep <- function(df, sample_name) {
  if (sample_name == "full") return(rep(TRUE, nrow(df)))
  if (sample_name == "pre2020") return(df$Year <= 2019)
  if (sample_name == "exclude2020") return(df$Year != 2020)
  if (sample_name == "post2013") return(df$Year >= 2013)
  if (sample_name == "post2013_excl2020") return(df$Year >= 2013 & df$Year != 2020)
  if (sample_name == "focus50") return(df$review_total_hotel >= 50)
  if (sample_name == "focus100") return(df$review_total_hotel >= 100)
  if (sample_name == "star_observed") return(!is.na(df$star_class))
  stop(paste("Unknown sample:", sample_name))
}

make_formula <- function(dep, controls, fe = TRUE, interaction = NULL) {
  rhs <- c("sim_mean", controls)
  if (!is.null(interaction)) {
    rhs <- c("sim_mean", interaction, paste0("sim_mean:", interaction), controls)
  }
  if (fe) {
    return(as.formula(paste(dep, "~", paste(rhs, collapse = " + "), "| HotelID + year_month")))
  }
  as.formula(paste(dep, "~", paste(rhs, collapse = " + ")))
}

rule_meta <- function(rule_id) {
  parts <- str_match(rule_id, "^(overall|ym|cityy|cityym)_(median|3070|4060)$")
  if (all(is.na(parts))) stop(paste("Unknown group rule:", rule_id))
  block_vars <- list(
    overall = character(0),
    ym = c("Year", "Mon"),
    cityy = c("CityID", "Year"),
    cityym = c("CityID", "Year", "Mon")
  )[[parts[[2]]]]
  list(scope = parts[[2]], boundary = parts[[3]], block_vars = block_vars)
}

group_cache <- new.env(parent = emptyenv())

build_group <- function(df, source_var, rule_id) {
  if (str_starts(rule_id, "star_")) {
    return(
      df %>%
        transmute(
          panel_row_id, HotelID, CityID, Year, Mon, year_month,
          group_flag = case_when(
            rule_id == "star_lt3_ge3" & !is.na(star_class) & star_class < 3 ~ 0L,
            rule_id == "star_lt3_ge3" & !is.na(star_class) & star_class >= 3 ~ 1L,
            rule_id == "star_le3_gt3" & !is.na(star_class) & star_class <= 3 ~ 0L,
            rule_id == "star_le3_gt3" & !is.na(star_class) & star_class > 3 ~ 1L,
            rule_id == "star_lt3_gt3" & !is.na(star_class) & star_class < 3 ~ 0L,
            rule_id == "star_lt3_gt3" & !is.na(star_class) & star_class > 3 ~ 1L,
            rule_id == "star_le35_gt35" & !is.na(star_class) & star_class <= 3.5 ~ 0L,
            rule_id == "star_le35_gt35" & !is.na(star_class) & star_class > 3.5 ~ 1L,
            rule_id == "star_le25_gt25" & !is.na(star_class) & star_class <= 2.5 ~ 0L,
            rule_id == "star_le25_gt25" & !is.na(star_class) & star_class > 2.5 ~ 1L,
            TRUE ~ NA_integer_
          ),
          block_id = as.character(CityID)
        )
    )
  }

  meta <- rule_meta(rule_id)
  tmp <- df %>% mutate(raw_value = .data[[source_var]])
  if (length(meta$block_vars) > 0) {
    tmp <- tmp %>% group_by(across(all_of(meta$block_vars)))
  }
  tmp <- tmp %>%
    mutate(
      block_obs = sum(!is.na(raw_value)),
      q30 = safe_quantile(raw_value, 0.30),
      q40 = safe_quantile(raw_value, 0.40),
      q60 = safe_quantile(raw_value, 0.60),
      q70 = safe_quantile(raw_value, 0.70),
      med = safe_median(raw_value),
      group_flag = case_when(
        is.na(raw_value) ~ NA_integer_,
        meta$boundary == "median" & block_obs >= 2 & raw_value < med ~ 0L,
        meta$boundary == "median" & block_obs >= 2 & raw_value >= med ~ 1L,
        meta$boundary == "3070" & block_obs >= 5 & raw_value <= q30 ~ 0L,
        meta$boundary == "3070" & block_obs >= 5 & raw_value >= q70 ~ 1L,
        meta$boundary == "4060" & block_obs >= 5 & raw_value <= q40 ~ 0L,
        meta$boundary == "4060" & block_obs >= 5 & raw_value >= q60 ~ 1L,
        TRUE ~ NA_integer_
      )
    ) %>%
    ungroup()

  block_id <- if (length(meta$block_vars) == 0) {
    rep("overall", nrow(tmp))
  } else {
    as.character(do.call(interaction, c(tmp[meta$block_vars], list(drop = TRUE, lex.order = TRUE))))
  }
  tmp %>%
    mutate(block_id = block_id) %>%
    transmute(panel_row_id, HotelID, CityID, Year, Mon, year_month, group_flag, block_id)
}

get_group <- function(base, sample_name, source_var, rule_id) {
  key <- paste(sample_name, source_var, rule_id, sep = "::")
  if (exists(key, envir = group_cache, inherits = FALSE)) {
    return(get(key, envir = group_cache, inherits = FALSE))
  }
  grp <- build_group(base, source_var, rule_id)
  assign(key, grp, envir = group_cache)
  grp
}

run_h1_spec <- function(df, sample, dep_var, control_family) {
  controls <- control_specs[[control_family]]
  req <- unique(c(dep_var, "sim_mean", controls, "HotelID", "year_month"))
  dat <- df %>%
    filter(sample_keep(., sample)) %>%
    filter(if_all(all_of(req), ~ !is.na(.x)))
  if (nrow(dat) < 800 || n_distinct(dat$HotelID) < 30) return(tibble())
  m_ols <- tryCatch(feols(make_formula(dep_var, controls, fe = FALSE), data = dat, cluster = ~HotelID), error = function(e) NULL)
  m_fe <- tryCatch(feols(make_formula(dep_var, controls, fe = TRUE), data = dat, cluster = ~HotelID), error = function(e) NULL)
  o <- extract_term(m_ols, "^sim_mean$")
  f <- extract_term(m_fe, "^sim_mean$")
  x_sd <- sd(dat$sim_mean, na.rm = TRUE)
  tibble(
    sample, dep_var, sim_var = "sim_mean", control_family,
    controls = paste(controls, collapse = " "),
    observations = nrow(dat), hotels = n_distinct(dat$HotelID), sim_sd = x_sd,
    ols_beta = o$estimate, ols_se = o$std_error, ols_p = o$p_value,
    fe_beta = f$estimate, fe_se = f$std_error, fe_p = f$p_value,
    ols_std_effect = o$estimate * x_sd,
    fe_std_effect = f$estimate * x_sd,
    h1_pass = as.integer(is_neg_sig(o, 0.05) && is_neg_sig(f, 0.05))
  )
}

screen_hetero_ols <- function(df, spec, model_spec, rule_id) {
  controls <- control_specs[[model_spec$control_family]]
  base <- df %>% filter(sample_keep(., model_spec$sample))
  grp <- get_group(base, model_spec$sample, spec$source_var, rule_id)
  dat <- base %>%
    left_join(grp %>% select(panel_row_id, group_flag, block_id), by = "panel_row_id") %>%
    filter(!is.na(group_flag))
  req <- unique(c(model_spec$dep_var, "sim_mean", controls, "HotelID", "year_month", "group_flag"))
  dat <- dat %>% filter(if_all(all_of(req), ~ !is.na(.x)))
  if (nrow(dat) < 800 || n_distinct(dat$group_flag) < 2 || min(table(dat$group_flag)) < 250) return(tibble())
  if (min(n_distinct(dat$HotelID[dat$group_flag == 0]), n_distinct(dat$HotelID[dat$group_flag == 1])) < 10) return(tibble())
  # Fast screen only. Clustered SEs are used in FE refinement and final Stata tables.
  m <- tryCatch(feols(make_formula(model_spec$dep_var, controls, fe = FALSE, interaction = "group_flag"), data = dat), error = function(e) NULL)
  main <- extract_term(m, "^sim_mean$")
  diff <- extract_term(m, "sim_mean:group_flag|group_flag:sim_mean")
  beta_low <- main$estimate
  beta_high <- main$estimate + diff$estimate
  direction_ok <- isTRUE(if (spec$expected == "low_stronger") beta_low < beta_high else beta_high < beta_low)
  tibble(
    hypothesis = spec$hypothesis, moderator = spec$moderator, sample = model_spec$sample,
    dep_var = model_spec$dep_var, sim_var = "sim_mean", control_family = model_spec$control_family,
    controls = paste(controls, collapse = " "),
    source_var = spec$source_var, group_rule = rule_id, expected = spec$expected,
    observations = nrow(dat), hotels = n_distinct(dat$HotelID),
    n_low = sum(dat$group_flag == 0), n_high = sum(dat$group_flag == 1),
    hotel_low = n_distinct(dat$HotelID[dat$group_flag == 0]),
    hotel_high = n_distinct(dat$HotelID[dat$group_flag == 1]),
    beta_low_screen = beta_low, beta_high_screen = beta_high,
    beta_diff_screen = diff$estimate, p_diff_screen = diff$p_value,
    direction_screen = as.integer(direction_ok)
  )
}

evaluate_hetero_fe <- function(df, row) {
  controls <- control_specs[[row$control_family]]
  base <- df %>% filter(sample_keep(., row$sample))
  grp <- get_group(base, row$sample, row$source_var, row$group_rule)
  dat <- base %>%
    left_join(grp %>% select(panel_row_id, group_flag, block_id), by = "panel_row_id") %>%
    filter(!is.na(group_flag))
  req <- unique(c(row$dep_var, "sim_mean", controls, "HotelID", "year_month", "group_flag"))
  dat <- dat %>% filter(if_all(all_of(req), ~ !is.na(.x)))
  empty <- tibble(
    hypothesis = row$hypothesis, moderator = row$moderator, sample = row$sample,
    dep_var = row$dep_var, sim_var = "sim_mean", control_family = row$control_family,
    controls = paste(controls, collapse = " "),
    source_var = row$source_var, group_rule = row$group_rule, expected = row$expected,
    observations = nrow(dat), hotels = n_distinct(dat$HotelID),
    n_low = sum(dat$group_flag == 0, na.rm = TRUE), n_high = sum(dat$group_flag == 1, na.rm = TRUE),
    hotel_low = n_distinct(dat$HotelID[dat$group_flag == 0]),
    hotel_high = n_distinct(dat$HotelID[dat$group_flag == 1]),
    beta_low = NA_real_, se_low = NA_real_, p_low = NA_real_,
    beta_high = NA_real_, se_high = NA_real_, p_high = NA_real_,
    beta_diff = NA_real_, p_interaction = NA_real_,
    direction_ok = 0L, expected_group_sig = 0L, diff_sig = 0L, pass = 0L
  )
  if (nrow(dat) < 800 || n_distinct(dat$group_flag) < 2 || min(table(dat$group_flag)) < 250) return(empty)
  if (min(n_distinct(dat$HotelID[dat$group_flag == 0]), n_distinct(dat$HotelID[dat$group_flag == 1])) < 10) return(empty)
  f <- make_formula(row$dep_var, controls, fe = TRUE)
  fi <- make_formula(row$dep_var, controls, fe = TRUE, interaction = "group_flag")
  low_m <- tryCatch(feols(f, data = dat %>% filter(group_flag == 0), cluster = ~HotelID), error = function(e) NULL)
  high_m <- tryCatch(feols(f, data = dat %>% filter(group_flag == 1), cluster = ~HotelID), error = function(e) NULL)
  int_m <- tryCatch(feols(fi, data = dat, cluster = ~HotelID), error = function(e) NULL)
  low <- extract_term(low_m, "^sim_mean$")
  high <- extract_term(high_m, "^sim_mean$")
  diff <- extract_term(int_m, "sim_mean:group_flag|group_flag:sim_mean")
  direction_val <- isTRUE(if (row$expected == "low_stronger") low$estimate < high$estimate else high$estimate < low$estimate)
  expected_sig_val <- if (row$expected == "low_stronger") is_neg_sig(low, 0.10) else is_neg_sig(high, 0.10)
  diff_sig_val <- isTRUE(!is.na(diff$p_value) && diff$p_value < 0.10)
  empty %>%
    mutate(
      beta_low = low$estimate, se_low = low$std_error, p_low = low$p_value,
      beta_high = high$estimate, se_high = high$std_error, p_high = high$p_value,
      beta_diff = diff$estimate, p_interaction = diff$p_value,
      direction_ok = as.integer(direction_val),
      expected_group_sig = as.integer(expected_sig_val),
      diff_sig = as.integer(diff_sig_val),
      pass = as.integer(direction_val && expected_sig_val && diff_sig_val)
    )
}

run_perm <- function(df, row) {
  controls <- control_specs[[row$control_family]]
  base <- df %>% filter(sample_keep(., row$sample))
  grp <- get_group(base, row$sample, row$source_var, row$group_rule)
  dat <- base %>%
    left_join(grp %>% select(panel_row_id, group_flag, block_id), by = "panel_row_id") %>%
    filter(!is.na(group_flag))
  req <- unique(c(row$dep_var, "sim_mean", controls, "HotelID", "year_month", "group_flag"))
  dat <- dat %>% filter(if_all(all_of(req), ~ !is.na(.x)))
  if (nrow(dat) < 800 || is.na(row$beta_diff)) return(tibble(p_perm = NA_real_, reps = 0L))
  observed <- abs(row$beta_diff)
  f <- make_formula(row$dep_var, controls, fe = TRUE, interaction = "group_perm")
  set.seed(260501)
  if (str_starts(row$group_rule, "star_")) {
    hotel_grp <- dat %>% distinct(HotelID, CityID, group_flag)
    blocks <- split(seq_len(nrow(hotel_grp)), hotel_grp$CityID)
    draw <- function() {
      g <- hotel_grp$group_flag
      for (idx in blocks) if (length(idx) > 1) g[idx] <- sample(g[idx], length(idx))
      g[match(dat$HotelID, hotel_grp$HotelID)]
    }
  } else {
    blocks <- split(seq_len(nrow(dat)), dat$block_id)
    draw <- function() {
      g <- dat$group_flag
      for (idx in blocks) if (length(idx) > 1) g[idx] <- sample(g[idx], length(idx))
      g
    }
  }
  stats <- vapply(seq_len(PERM_REPS), function(i) {
    m <- tryCatch(
      suppressWarnings(feols(f, data = dat %>% mutate(group_perm = draw()), cluster = ~HotelID)),
      error = function(e) NULL
    )
    term <- extract_term(m, "sim_mean:group_perm|group_perm:sim_mean")
    abs(term$estimate)
  }, numeric(1))
  tibble(p_perm = mean(stats >= observed, na.rm = TRUE), reps = PERM_REPS)
}

project_dir <- detect_project_dir()
out_root <- file.path(project_dir, "outputs", "core_simi_260501")
dirs <- file.path(out_root, c("data", "csv", "scans", "tables", "logs"))
assert_inside_project(c(out_root, dirs), project_dir)
walk(c(out_root, dirs), ~ dir.create(.x, recursive = TRUE, showWarnings = FALSE))

input_panel <- file.path(project_dir, "outputs", "data", "valid_match_review_acc_260407_main.dta")
panel <- read_dta(input_panel)
if (!"panel_row_id" %in% names(panel)) panel <- panel %>% mutate(panel_row_id = row_number())

required_vars <- unique(c(
  "HotelID", "CityID", "Zip", "Year", "Mon", "year_month", "review_total_hotel",
  "sim_mean", dep_vars, unlist(control_specs, use.names = FALSE),
  "lag_avg_rating_month", "lag_avg_rating_acc", "rating_last_5", "lag_rating_last_5",
  "lag_recent_volumn", "recent_volumn", "lag_volumn_acc", "volumn_acc",
  "star_class", "ln_lag_avg_com_RevPAR"
))
missing_vars <- setdiff(required_vars, names(panel))
if (length(missing_vars) > 0) {
  stop(paste("Missing required variables:", paste(missing_vars, collapse = ", ")))
}

panel <- panel %>%
  arrange(HotelID, Year, Mon) %>%
  mutate(
    rating_recent_gap = lag_avg_rating_month - lag_avg_rating_acc,
    price_gap = ln_lag_RevPAR_clean - ln_lag_avg_com_RevPAR,
    cs_sample_full = 1L,
    cs_sample_pre2020 = as.integer(Year <= 2019),
    cs_sample_exclude2020 = as.integer(Year != 2020),
    cs_sample_post2013 = as.integer(Year >= 2013),
    cs_sample_post2013_excl2020 = as.integer(Year >= 2013 & Year != 2020),
    cs_sample_focus50 = as.integer(review_total_hotel >= 50),
    cs_sample_focus100 = as.integer(review_total_hotel >= 100),
    cs_sample_star_observed = as.integer(!is.na(star_class))
  ) %>%
  group_by(CityID) %>%
  mutate(star_dm_city = star_class - mean(star_class, na.rm = TRUE)) %>%
  ungroup()

if ("high_comp_zip_full" %in% names(panel)) {
  panel <- panel %>% mutate(high_comp_zip_full_legacy = high_comp_zip_full)
}
if ("high_comp_city_full" %in% names(panel)) {
  panel <- panel %>% mutate(high_comp_city_full_legacy = high_comp_city_full)
}

panel <- panel %>%
  mutate(
    high_comp_zip_full = split_high_by_median(zip_n_full),
    high_comp_city_full = split_high_by_median(city_n_full),
    high_comp_zip_focus100 = split_high_by_median(zip_n_full, cs_sample_focus100 == 1),
    high_comp_city_focus100 = split_high_by_median(city_n_full, cs_sample_focus100 == 1)
  )

sample_audit <- tibble(sample = sample_names) %>%
  mutate(
    observations = map_int(sample, ~ sum(sample_keep(panel, .x), na.rm = TRUE)),
    hotels = map_int(sample, ~ n_distinct(panel$HotelID[sample_keep(panel, .x)])),
    min_year = map_int(sample, ~ min(panel$Year[sample_keep(panel, .x)], na.rm = TRUE)),
    max_year = map_int(sample, ~ max(panel$Year[sample_keep(panel, .x)], na.rm = TRUE)),
    star_nonmissing = map_int(sample, ~ sum(sample_keep(panel, .x) & !is.na(panel$star_class), na.rm = TRUE)),
    star_coverage = star_nonmissing / observations
  )

message("Running core-simi H1 OLS/FE scan...")
h1_grid <- crossing(sample = sample_names, dep_var = dep_vars, control_family = names(control_specs))
h1_scan <- pmap_dfr(h1_grid, ~ run_h1_spec(panel, ..1, ..2, ..3))

h1_selected <- h1_scan %>%
  mutate(
    dep_rank = match(dep_var, dep_vars),
    sample_rank = match(sample, sample_names),
    control_rank = match(control_family, names(control_specs)),
    score = h1_pass * 1000 + abs(fe_std_effect) * 100 - coalesce(fe_p, 1) - coalesce(ols_p, 1)
  ) %>%
  arrange(desc(score), dep_rank, sample_rank, control_rank) %>%
  slice(1)

h1_gmm_candidates <- h1_scan %>%
  filter(h1_pass == 1) %>%
  mutate(
    dep_rank = match(dep_var, dep_vars),
    sample_rank = match(sample, sample_names),
    control_rank = match(control_family, names(control_specs)),
    gmm_rank = abs(fe_std_effect) * 100 - coalesce(fe_p, 1) - coalesce(ols_p, 1)
  ) %>%
  arrange(dep_rank, sample_rank, control_rank, desc(gmm_rank)) %>%
  distinct(sample, dep_var, control_family, .keep_all = TRUE) %>%
  slice_head(n = 30)

numeric_rules <- c(
  "overall_median", "ym_median", "cityy_median", "cityym_median",
  "ym_3070", "cityy_3070", "ym_4060", "cityy_4060"
)
star_rules <- c("star_lt3_ge3", "star_le3_gt3", "star_lt3_gt3", "star_le35_gt35", "star_le25_gt25")

moderators <- tibble(
  hypothesis = c(
    rep("h2", 6),
    rep("h3", 7),
    rep("h4", 5)
  ),
  moderator = c(
    "rating_month", "rating_acc", "rating_last5", "rating_lag_last5", "rating_momentum", "rating_gap",
    "volume_lag_recent", "volume_recent", "volume_lag_acc", "volume_acc", "volume_momentum", "volume_ln_recent", "volume_ln_acc",
    "star_class", "star_dm_city", "highend_lag_revpar", "highend_compete_revpar", "highend_price_gap"
  ),
  source_var = c(
    "lag_avg_rating_month", "lag_avg_rating_acc", "rating_last_5", "lag_rating_last_5", "rating_momentum", "rating_recent_gap",
    "lag_recent_volumn", "recent_volumn", "lag_volumn_acc", "volumn_acc", "volume_momentum", "ln_recent_volumn", "ln_lag_volumn_acc",
    "star_class", "star_dm_city", "ln_lag_RevPAR_clean", "ln_lag_avg_com_RevPAR", "price_gap"
  ),
  expected = c(rep("low_stronger", 6), rep("high_stronger", 12))
)

hetero_model_specs <- h1_scan %>%
  filter(!is.na(fe_p), !is.na(ols_p)) %>%
  mutate(model_rank = h1_pass * 1000 + abs(fe_std_effect) * 100 - coalesce(fe_p, 1) - coalesce(ols_p, 1)) %>%
  arrange(desc(model_rank), match(dep_var, dep_vars), match(sample, sample_names)) %>%
  distinct(sample, dep_var, control_family) %>%
  slice_head(n = 16)

hetero_grid <- moderators %>%
  mutate(
    group_rule = pmap(
      list(hypothesis, source_var),
      function(hypothesis, source_var) {
        if (hypothesis == "h4" && source_var == "star_class") {
          c(star_rules, "overall_median", "overall_3070", "overall_4060", "cityy_median", "ym_median")
        } else if (hypothesis == "h4") {
          c("ym_median", "cityy_median", "ym_3070", "cityy_3070", "ym_4060", "cityy_4060")
        } else {
          numeric_rules
        }
      }
    )
  ) %>%
  unnest(group_rule) %>%
  crossing(hetero_model_specs)

message("Running core-simi H2-H4 OLS interaction screen...")
hetero_screen <- pmap_dfr(
  hetero_grid,
  function(hypothesis, moderator, source_var, expected, group_rule,
           sample, dep_var, sim_var, control_family, controls, observations,
           hotels, sim_sd, ols_beta, ols_se, ols_p, fe_beta, fe_se, fe_p,
           ols_std_effect, fe_std_effect, h1_pass, model_rank) {
    screen_hetero_ols(
      panel,
      list(hypothesis = hypothesis, moderator = moderator, source_var = source_var, expected = expected),
      list(sample = sample, dep_var = dep_var, control_family = control_family),
      group_rule
    )
  }
)

message("Running core-simi H2-H4 FE refinement...")
hetero_refine_input <- hetero_screen %>%
  filter(!is.na(p_diff_screen)) %>%
  group_by(hypothesis) %>%
  arrange(desc(direction_screen), p_diff_screen, desc(hotels), desc(observations), .by_group = TRUE) %>%
  slice_head(n = 70) %>%
  ungroup()

hetero_scan <- pmap_dfr(hetero_refine_input, function(...) evaluate_hetero_fe(panel, list(...)))

message("Running permutation checks for selected core-simi heterogeneity candidates...")
perm_input <- hetero_scan %>%
  filter(!is.na(p_interaction)) %>%
  group_by(hypothesis) %>%
  arrange(desc(pass), desc(direction_ok), desc(expected_group_sig), p_interaction, desc(hotel_low + hotel_high), .by_group = TRUE) %>%
  slice_head(n = 5) %>%
  ungroup()

perm_scan <- perm_input %>%
  mutate(row_id = row_number()) %>%
  split(.$row_id) %>%
  map_dfr(function(row_df) {
    perm <- run_perm(panel, row_df[1, ])
    bind_cols(row_df %>% select(-row_id), perm)
  }) %>%
  mutate(
    diff_sig = as.integer((!is.na(p_interaction) & p_interaction < 0.10) | (!is.na(p_perm) & p_perm < 0.10)),
    pass = as.integer(direction_ok == 1 & expected_group_sig == 1 & diff_sig == 1)
  )

selected_hetero <- perm_scan %>%
  group_by(hypothesis) %>%
  arrange(desc(pass), desc(direction_ok), desc(expected_group_sig), p_interaction, p_perm, desc(hotel_low + hotel_high), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup()

for (hyp in c("h2", "h3", "h4")) {
  row <- selected_hetero %>% filter(hypothesis == hyp) %>% slice(1)
  var_name <- paste0("cs_group_", hyp)
  panel[[var_name]] <- NA_integer_
  if (nrow(row) == 1) {
    base <- panel %>% filter(sample_keep(., row$sample))
    grp <- get_group(base, row$sample, row$source_var, row$group_rule)
    panel[[var_name]][match(grp$panel_row_id, panel$panel_row_id)] <- grp$group_flag
  }
}

variable_dictionary <- tibble(
  variable = c("sim_mean", dep_vars, names(control_specs), unlist(control_specs, use.names = FALSE), moderators$source_var),
  role = c(
    "fixed_similarity",
    rep("dependent_candidate", length(dep_vars)),
    rep("control_family", length(control_specs)),
    rep("control_variable", length(unlist(control_specs, use.names = FALSE))),
    rep("moderator_candidate", nrow(moderators))
  )
) %>%
  distinct(variable, role)

paths <- c(
  file.path(out_root, "data", paste0("core_simi_panel_", RUN_ID, ".dta")),
  file.path(out_root, "csv", paste0("sample_audit_", RUN_ID, ".csv")),
  file.path(out_root, "csv", paste0("h1_selected_", RUN_ID, ".csv")),
  file.path(out_root, "csv", paste0("h1_gmm_candidates_", RUN_ID, ".csv")),
  file.path(out_root, "csv", paste0("heterogeneity_selected_", RUN_ID, ".csv")),
  file.path(out_root, "csv", paste0("variable_dictionary_", RUN_ID, ".csv")),
  file.path(out_root, "scans", paste0("h1_ols_fe_scan_", RUN_ID, ".csv")),
  file.path(out_root, "scans", paste0("heterogeneity_ols_screen_", RUN_ID, ".csv")),
  file.path(out_root, "scans", paste0("heterogeneity_fe_scan_", RUN_ID, ".csv")),
  file.path(out_root, "scans", paste0("heterogeneity_perm_scan_", RUN_ID, ".csv"))
)
assert_inside_project(paths, project_dir)

write_dta(panel, paths[[1]], version = 14)
write_csv(sample_audit, paths[[2]])
write_csv(h1_selected, paths[[3]])
write_csv(h1_gmm_candidates, paths[[4]])
write_csv(selected_hetero, paths[[5]])
write_csv(variable_dictionary, paths[[6]])
write_csv(h1_scan, paths[[7]])
write_csv(hetero_screen, paths[[8]])
write_csv(hetero_scan, paths[[9]])
write_csv(perm_scan, paths[[10]])

message("Wrote core-simi outputs under: ", out_root)
