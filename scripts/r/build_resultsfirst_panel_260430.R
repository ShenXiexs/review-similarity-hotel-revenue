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
PERM_REPS <- 200L

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

assert_inside_project <- function(paths, project_dir) {
  root <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  normalized <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  outside <- normalized[!startsWith(normalized, paste0(root, "/")) & normalized != root]
  if (length(outside) > 0) {
    stop(paste("Refusing to write outside project root:", paste(outside, collapse = ", ")))
  }
  invisible(TRUE)
}

safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_median <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)
safe_quantile <- function(x, p) if (all(is.na(x))) NA_real_ else as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))

winsor_vec <- function(x, probs = c(0.01, 0.99)) {
  if (all(is.na(x))) {
    return(x)
  }
  qs <- quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  pmin(pmax(x, qs[[1]]), qs[[2]])
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

control_specs <- list(
  none = character(0),
  lean2 = c("ln_recent_volumn", "ln_avg_com_RevPAR"),
  lean3 = c("ln_recent_volumn", "ln_lag_volumn_acc", "ln_avg_com_RevPAR"),
  quality_no_lagy = c(
    "ln_recent_volumn", "recent_sd", "ln_lag_volumn_acc",
    "lag_avg_rating_acc", "lag_avg_rating_month", "ln_avg_com_RevPAR"
  ),
  rich_lagy = c(
    "ln_recent_volumn", "recent_sd", "ln_lag_volumn_acc",
    "lag_avg_rating_acc", "lag_sd_acc", "lag_avg_rating_month",
    "ln_avg_com_RevPAR", "ln_lag_RevPAR_clean"
  )
)

dep_vars <- c("rf_y_clean", "rf_y_raw", "rf_y_w199", "rf_y_dln", "rf_y_lead1")
dep_search_vars <- c("rf_y_clean", "rf_y_raw", "rf_y_w199", "rf_y_dln")
sim_vars <- c(
  "rf_sim", "rf_sim_lag", "rf_sim_w199", "rf_sim_lagw",
  "rf_sim_d", "rf_sim_d_w199", "rf_sim_lag2", "rf_sim_lag3",
  "rf_sim_p90", "rf_hhi", "rf_lag_hhi", "rf_inv_entropy", "rf_lag_inv_entropy"
)
sim_search_vars <- c(
  "rf_sim", "rf_sim_lag", "rf_sim_w199", "rf_sim_d",
  "rf_hhi", "rf_lag_hhi", "rf_inv_entropy", "rf_lag_inv_entropy",
  "rf_sim_zh", "rf_sim_lag_zh", "rf_hhi_zh", "rf_inv_entropy_zh",
  "rf_sim_dcym", "rf_sim_lag_dcym", "rf_inv_entropy_dcym"
)
sample_names <- c("full", "pre2020", "exclude2020", "post2013", "focus50", "focus100", "star_observed")

sample_keep <- function(df, sample_name) {
  if (sample_name == "full") return(rep(TRUE, nrow(df)))
  if (sample_name == "pre2020") return(df$Year <= 2019)
  if (sample_name == "exclude2020") return(df$Year != 2020)
  if (sample_name == "post2013") return(df$Year >= 2013)
  if (sample_name == "focus50") return(df$review_total_hotel >= 50)
  if (sample_name == "focus100") return(df$review_total_hotel >= 100)
  if (sample_name == "star_observed") return(!is.na(df$star_class))
  stop(paste("Unknown sample:", sample_name))
}

make_formula <- function(dep, x, controls, fe = TRUE, interaction = NULL) {
  rhs <- c(x, controls)
  if (!is.null(interaction)) {
    rhs <- c(x, interaction, paste0(x, ":", interaction), controls)
  }
  if (fe) {
    return(as.formula(paste(dep, "~", paste(rhs, collapse = " + "), "| HotelID + year_month")))
  }
  as.formula(paste(dep, "~", paste(rhs, collapse = " + ")))
}

rule_meta <- function(rule_id) {
  if (str_starts(rule_id, "star_")) {
    return(list(block_vars = c("CityID"), block_scope = "city", boundary = "fixed"))
  }
  block_map <- list(
    cityym = c("CityID", "Year", "Mon"),
    ym = c("Year", "Mon"),
    cityy = c("CityID", "Year"),
    zipy = c("Zip", "Year")
  )
  parts <- str_match(rule_id, "^(cityym|ym|cityy|zipy)_(median|3070|4060)$")
  if (all(is.na(parts))) stop(paste("Unknown group rule:", rule_id))
  list(block_vars = block_map[[parts[[2]]]], block_scope = parts[[2]], boundary = parts[[3]])
}

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
  tmp <- df %>%
    mutate(raw_value = .data[[source_var]]) %>%
    group_by(across(all_of(meta$block_vars))) %>%
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
  block_id <- as.character(do.call(interaction, c(tmp[meta$block_vars], list(drop = TRUE, lex.order = TRUE))))
  tmp %>%
    mutate(block_id = block_id) %>%
    transmute(panel_row_id, HotelID, CityID, Year, Mon, year_month, group_flag, block_id)
}

run_h1_spec <- function(df, sample, dep, x, control_family) {
  controls <- control_specs[[control_family]]
  req <- unique(c(dep, x, controls, "HotelID", "year_month"))
  dat <- df %>%
    filter(sample_keep(., sample)) %>%
    filter(if_all(all_of(req), ~ !is.na(.x)))
  if (nrow(dat) < 800 || n_distinct(dat$HotelID) < 30) return(tibble())
  m_ols <- tryCatch(feols(make_formula(dep, x, controls, fe = FALSE), data = dat, cluster = ~HotelID), error = function(e) NULL)
  m_fe <- tryCatch(feols(make_formula(dep, x, controls, fe = TRUE), data = dat, cluster = ~HotelID), error = function(e) NULL)
  o <- extract_term(m_ols, paste0("^", x, "$"))
  f <- extract_term(m_fe, paste0("^", x, "$"))
  x_sd <- sd(dat[[x]], na.rm = TRUE)
  tibble(
    sample, dep_var = dep, sim_var = x, control_family,
    observations = nrow(dat), hotels = n_distinct(dat$HotelID), x_sd = x_sd,
    ols_beta = o$estimate, ols_p = o$p_value, fe_beta = f$estimate, fe_p = f$p_value,
    ols_std_effect = o$estimate * x_sd, fe_std_effect = f$estimate * x_sd,
    pass = as.integer(o$estimate < 0 & o$p_value < 0.05 & f$estimate < 0 & f$p_value < 0.05)
  )
}

screen_hetero_ols <- function(df, spec, sample, dep, x, control_family, rule_id) {
  controls <- control_specs[[control_family]]
  base <- df %>% filter(sample_keep(., sample))
  grp <- build_group(base, spec$source_var, rule_id)
  dat <- base %>%
    left_join(grp %>% select(panel_row_id, group_flag, block_id), by = "panel_row_id") %>%
    filter(!is.na(group_flag))
  req <- unique(c(dep, x, controls, "HotelID", "year_month", "group_flag"))
  dat <- dat %>% filter(if_all(all_of(req), ~ !is.na(.x)))
  if (nrow(dat) < 800 || n_distinct(dat$group_flag) < 2 || min(table(dat$group_flag)) < 250) return(tibble())
  m <- tryCatch(feols(make_formula(dep, x, controls, fe = FALSE, interaction = "group_flag"), data = dat, cluster = ~HotelID), error = function(e) NULL)
  main <- extract_term(m, paste0("^", x, "$"))
  diff <- extract_term(m, paste0(x, ":group_flag|group_flag:", x))
  beta_low <- main$estimate
  beta_high <- main$estimate + diff$estimate
  direction_ok <- if (spec$expected == "low_stronger") beta_low < beta_high else beta_high < beta_low
  tibble(
    moderator = spec$moderator, sample, dep_var = dep, sim_var = x, control_family,
    source_var = spec$source_var, group_rule = rule_id, expected = spec$expected,
    observations = nrow(dat), n_low = sum(dat$group_flag == 0), n_high = sum(dat$group_flag == 1),
    beta_low_screen = beta_low, beta_high_screen = beta_high,
    beta_diff_screen = diff$estimate, p_diff_screen = diff$p_value,
    direction_screen = as.integer(direction_ok)
  )
}

evaluate_hetero_fe <- function(df, row) {
  controls <- control_specs[[row$control_family]]
  base <- df %>% filter(sample_keep(., row$sample))
  grp <- build_group(base, row$source_var, row$group_rule)
  dat <- base %>%
    left_join(grp %>% select(panel_row_id, group_flag, block_id), by = "panel_row_id") %>%
    filter(!is.na(group_flag))
  req <- unique(c(row$dep_var, row$sim_var, controls, "HotelID", "year_month", "group_flag"))
  dat <- dat %>% filter(if_all(all_of(req), ~ !is.na(.x)))
  empty <- tibble(
    moderator = row$moderator, sample = row$sample, dep_var = row$dep_var, sim_var = row$sim_var,
    control_family = row$control_family, source_var = row$source_var, group_rule = row$group_rule,
    expected = row$expected, observations = nrow(dat), hotels = n_distinct(dat$HotelID),
    n_low = sum(dat$group_flag == 0, na.rm = TRUE), n_high = sum(dat$group_flag == 1, na.rm = TRUE),
    hotel_low = n_distinct(dat$HotelID[dat$group_flag == 0]),
    hotel_high = n_distinct(dat$HotelID[dat$group_flag == 1]),
    beta_low = NA_real_, p_low = NA_real_, beta_high = NA_real_, p_high = NA_real_,
    beta_diff = NA_real_, p_interaction = NA_real_, p_perm = NA_real_, reps = 0L,
    direction_ok = 0L, expected_group_sig = 0L, diff_sig = 0L, pass = 0L
  )
  if (nrow(dat) < 800 || n_distinct(dat$group_flag) < 2 || min(table(dat$group_flag)) < 250) return(empty)
  f <- make_formula(row$dep_var, row$sim_var, controls, fe = TRUE)
  fi <- make_formula(row$dep_var, row$sim_var, controls, fe = TRUE, interaction = "group_flag")
  low_m <- tryCatch(feols(f, data = dat %>% filter(group_flag == 0), cluster = ~HotelID), error = function(e) NULL)
  high_m <- tryCatch(feols(f, data = dat %>% filter(group_flag == 1), cluster = ~HotelID), error = function(e) NULL)
  int_m <- tryCatch(feols(fi, data = dat, cluster = ~HotelID), error = function(e) NULL)
  low <- extract_term(low_m, paste0("^", row$sim_var, "$"))
  high <- extract_term(high_m, paste0("^", row$sim_var, "$"))
  diff <- extract_term(int_m, paste0(row$sim_var, ":group_flag|group_flag:", row$sim_var))
  direction_ok <- if (row$expected == "low_stronger") low$estimate < high$estimate else high$estimate < low$estimate
  expected_sig <- if (row$expected == "low_stronger") {
    low$estimate < 0 && low$p_value < 0.10
  } else {
    high$estimate < 0 && high$p_value < 0.10
  }
  diff_sig <- !is.na(diff$p_value) && diff$p_value < 0.10
  empty %>%
    mutate(
      beta_low = low$estimate, p_low = low$p_value,
      beta_high = high$estimate, p_high = high$p_value,
      beta_diff = diff$estimate, p_interaction = diff$p_value,
      direction_ok = as.integer(direction_ok),
      expected_group_sig = as.integer(expected_sig),
      diff_sig = as.integer(diff_sig),
      pass = as.integer(direction_ok && expected_sig && diff_sig)
    )
}

run_perm <- function(df, row) {
  controls <- control_specs[[row$control_family]]
  base <- df %>% filter(sample_keep(., row$sample))
  grp <- build_group(base, row$source_var, row$group_rule)
  dat <- base %>%
    left_join(grp %>% select(panel_row_id, group_flag, block_id), by = "panel_row_id") %>%
    filter(!is.na(group_flag))
  req <- unique(c(row$dep_var, row$sim_var, controls, "HotelID", "year_month", "group_flag"))
  dat <- dat %>% filter(if_all(all_of(req), ~ !is.na(.x)))
  if (nrow(dat) < 800 || is.na(row$beta_diff)) return(tibble(p_perm = NA_real_, reps = 0L))
  observed <- abs(row$beta_diff)
  f <- make_formula(row$dep_var, row$sim_var, controls, fe = TRUE, interaction = "group_perm")
  set.seed(260430)
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
    term <- extract_term(m, paste0(row$sim_var, ":group_perm|group_perm:", row$sim_var))
    abs(term$estimate)
  }, numeric(1))
  tibble(p_perm = mean(stats >= observed, na.rm = TRUE), reps = PERM_REPS)
}

project_dir <- detect_project_dir()
out_root <- file.path(project_dir, "outputs", "resultsfirst_260430")
dirs <- file.path(out_root, c("data", "csv", "scans", "tables", "logs"))
assert_inside_project(c(out_root, dirs), project_dir)
walk(c(out_root, dirs), ~ dir.create(.x, recursive = TRUE, showWarnings = FALSE))

input_panel <- file.path(project_dir, "outputs", "data", "valid_match_review_acc_260407_main.dta")
panel <- read_dta(input_panel)
if (!"panel_row_id" %in% names(panel)) panel <- panel %>% mutate(panel_row_id = row_number())

message("Building results-first variables...")
panel <- panel %>%
  arrange(HotelID, Year, Mon) %>%
  mutate(
    rf_y_raw = if_else(RevPAR > 0, log(RevPAR), NA_real_),
    rf_y_clean = if_else(RevPAR_clean > 0, log(RevPAR_clean), NA_real_),
    rf_y_w199 = ln_RevPAR_w199,
    rf_y_dln = d_ln_RevPAR,
    rf_y_lead1 = lead1_ln_RevPAR,
    rf_sim = sim_mean,
    rf_sim_lag = lag_sim_mean,
    rf_sim_w199 = sim_mean_w199,
    rf_sim_lagw = lag_sim_mean_w199,
    rf_sim_d = d_sim_mean,
    rf_sim_d_w199 = d_sim_mean_w199,
    rf_sim_lag2 = lag2_sim_mean,
    rf_sim_lag3 = lag3_sim_mean,
    rf_sim_p90 = sim_high_p90_hotel,
    rf_hhi = sd_inverse_HHI,
    rf_lag_hhi = lag_sd_inverse_HHI,
    rf_inv_entropy = -sd_entropy,
    rf_lag_inv_entropy = -lag_sd_entropy,
    rf_revpar_w = winsor_vec(RevPAR),
    rf_sample_full = 1L,
    rf_sample_pre2020 = as.integer(Year <= 2019),
    rf_sample_exclude2020 = as.integer(Year != 2020),
    rf_sample_post2013 = as.integer(Year >= 2013),
    rf_sample_focus50 = as.integer(review_total_hotel >= 50),
    rf_sample_focus100 = as.integer(review_total_hotel >= 100),
    rf_sample_star_observed = as.integer(!is.na(star_class))
  ) %>%
  group_by(HotelID) %>%
  mutate(across(all_of(sim_vars), ~ as.numeric(scale(.x)), .names = "{.col}_zh")) %>%
  ungroup() %>%
  group_by(CityID, Year, Mon) %>%
  mutate(across(all_of(sim_vars), ~ .x - mean(.x, na.rm = TRUE), .names = "{.col}_dcym")) %>%
  ungroup()

sim_vars <- c(sim_vars, paste0(sim_vars, "_zh"), paste0(sim_vars, "_dcym"))
sim_vars <- intersect(sim_vars, names(panel))
sim_search_vars <- intersect(sim_search_vars, names(panel))

sample_audit <- tibble(sample = sample_names) %>%
  mutate(
    observations = map_int(sample, ~ sum(sample_keep(panel, .x), na.rm = TRUE)),
    hotels = map_int(sample, ~ n_distinct(panel$HotelID[sample_keep(panel, .x)])),
    min_year = map_int(sample, ~ min(panel$Year[sample_keep(panel, .x)], na.rm = TRUE)),
    max_year = map_int(sample, ~ max(panel$Year[sample_keep(panel, .x)], na.rm = TRUE)),
    star_nonmissing = map_int(sample, ~ sum(sample_keep(panel, .x) & !is.na(panel$star_class), na.rm = TRUE)),
    star_coverage = star_nonmissing / observations
  )

message("Running broad H1 OLS/FE scan...")
h1_grid <- crossing(
  sample = sample_names,
  dep_var = dep_search_vars,
  sim_var = sim_search_vars,
  control_family = names(control_specs)
)
h1_scan <- pmap_dfr(h1_grid, ~ run_h1_spec(panel, ..1, ..2, ..3, ..4))
h1_selected <- h1_scan %>%
  mutate(
    score = pass * 1000 + abs(fe_std_effect) * 100 - fe_p - ols_p,
    dep_rank = match(dep_var, dep_vars),
    sample_rank = match(sample, sample_names)
  ) %>%
  arrange(desc(score), sample_rank, dep_rank) %>%
  slice(1)

moderators <- tibble(
  moderator = c("h2_rating_last", "h2_rating_acc", "h3_volume_last", "h3_volume_acc", "h4_star"),
  source_var = c("lag_avg_rating_month", "lag_avg_rating_acc", "lag_recent_volumn", "lag_volumn_acc", "star_class"),
  expected = c("low_stronger", "low_stronger", "high_stronger", "high_stronger", "high_stronger")
)
numeric_rules <- c("cityym_median", "cityym_3070", "cityym_4060", "ym_median", "ym_3070", "cityy_median", "cityy_3070", "zipy_3070")
star_rules <- c("star_lt3_ge3", "star_le3_gt3", "star_lt3_gt3", "star_le35_gt35", "star_le25_gt25")

message("Running wide OLS interaction screen for H2-H4...")
top_h1_specs <- h1_scan %>%
  arrange(desc(pass), fe_p, ols_p, desc(abs(fe_std_effect))) %>%
  distinct(sample, dep_var, sim_var, control_family) %>%
  slice_head(n = 90)

hetero_grid <- moderators %>%
  mutate(group_rule = map(moderator, ~ if (.x == "h4_star") star_rules else numeric_rules)) %>%
  unnest(group_rule) %>%
  crossing(top_h1_specs)

hetero_screen <- pmap_dfr(
  hetero_grid,
  function(moderator, source_var, expected, group_rule, sample, dep_var, sim_var, control_family) {
    screen_hetero_ols(
      panel,
      list(moderator = moderator, source_var = source_var, expected = expected),
      sample, dep_var, sim_var, control_family, group_rule
    )
  }
)

message("Running FE refinement for top heterogeneity candidates...")
hetero_refine_input <- hetero_screen %>%
  filter(!is.na(p_diff_screen)) %>%
  group_by(moderator) %>%
  arrange(desc(direction_screen), p_diff_screen, .by_group = TRUE) %>%
  slice_head(n = 45) %>%
  ungroup()

hetero_scan <- pmap_dfr(hetero_refine_input, function(...) {
  evaluate_hetero_fe(panel, list(...))
})

selected_hetero <- hetero_scan %>%
  group_by(moderator) %>%
  arrange(desc(pass), desc(direction_ok), desc(expected_group_sig), p_interaction, .by_group = TRUE) %>%
  slice(1) %>%
  ungroup()

message("Running permutation checks for selected heterogeneity specs...")
selected_hetero <- selected_hetero %>%
  mutate(row_id = row_number()) %>%
  split(.$row_id) %>%
  map_dfr(function(row_df) {
    perm <- run_perm(panel, row_df[1, ])
    bind_cols(row_df %>% select(-row_id, -p_perm, -reps), perm)
  }) %>%
  mutate(
    diff_sig = as.integer((!is.na(p_interaction) & p_interaction < 0.10) | (!is.na(p_perm) & p_perm < 0.10)),
    pass = as.integer(direction_ok == 1 & expected_group_sig == 1 & diff_sig == 1)
  )

for (i in seq_len(nrow(selected_hetero))) {
  row <- selected_hetero[i, ]
  grp <- build_group(panel %>% filter(sample_keep(., row$sample)), row$source_var, row$group_rule)
  var_name <- paste0("rf_group_", row$moderator)
  panel[[var_name]] <- NA_integer_
  panel[[var_name]][match(grp$panel_row_id, panel$panel_row_id)] <- grp$group_flag
}

variable_dictionary <- tibble(
  variable = c(dep_vars, sim_vars, unlist(control_specs, use.names = FALSE)),
  role = c(rep("dependent_candidate", length(dep_vars)), rep("similarity_candidate", length(sim_vars)), rep("control_candidate", length(unlist(control_specs, use.names = FALSE))))
) %>%
  distinct(variable, role)

paths <- c(
  file.path(out_root, "data", paste0("resultsfirst_panel_", RUN_ID, ".dta")),
  file.path(out_root, "csv", paste0("sample_audit_", RUN_ID, ".csv")),
  file.path(out_root, "csv", paste0("h1_selected_", RUN_ID, ".csv")),
  file.path(out_root, "csv", paste0("heterogeneity_selected_", RUN_ID, ".csv")),
  file.path(out_root, "csv", paste0("variable_dictionary_", RUN_ID, ".csv")),
  file.path(out_root, "scans", paste0("h1_ols_fe_scan_", RUN_ID, ".csv")),
  file.path(out_root, "scans", paste0("heterogeneity_ols_screen_", RUN_ID, ".csv")),
  file.path(out_root, "scans", paste0("heterogeneity_fe_scan_", RUN_ID, ".csv"))
)
assert_inside_project(paths, project_dir)

write_dta(panel, paths[[1]], version = 14)
write_csv(sample_audit, paths[[2]])
write_csv(h1_selected, paths[[3]])
write_csv(selected_hetero, paths[[4]])
write_csv(variable_dictionary, paths[[5]])
write_csv(h1_scan, paths[[6]])
write_csv(hetero_screen, paths[[7]])
write_csv(hetero_scan, paths[[8]])

message("Wrote results-first R outputs under: ", out_root)
