library(dplyr)
library(readr)
library(haven)
library(stringr)
library(fixest)

if ("setFixest_notes" %in% getNamespaceExports("fixest")) {
  setFixest_notes(FALSE)
}

project_dir <- "/Users/samxie/Research/ReviewSimi_Sales/Code"
output_root <- file.path(project_dir, "outputs")
data_dir <- file.path(output_root, "data")
scan_dir <- file.path(output_root, "scans")

for (dir_path in c(output_root, data_dir, scan_dir)) {
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
}

path_panel <- file.path(data_dir, "valid_match_review_acc_260407_main.dta")
path_boundary <- file.path(scan_dir, "heterogeneity_boundary_scan_260407.csv")

control_terms <- c(
  "ln_recent_volumn",
  "recent_sd",
  "ln_lag_volumn_acc",
  "lag_avg_rating_acc",
  "lag_sd_acc",
  "lag_avg_rating_month",
  "ln_avg_com_RevPAR",
  "ln_lag_RevPAR_clean"
)

median_rules <- c(
  "cityy_median_strict",
  "cityym_median_strict",
  "zipy_median_ge_lt",
  "cityy_median_ge_lt"
)

safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_median <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)

extract_term <- function(model, term_pattern) {
  ct <- as.data.frame(coeftable(model))
  ct$term <- rownames(ct)
  rownames(ct) <- NULL
  hit <- ct %>% filter(str_detect(term, term_pattern)) %>% slice(1)
  if (nrow(hit) == 0) return(tibble(estimate = NA_real_, p_value = NA_real_))
  tibble(estimate = hit$Estimate[[1]], p_value = hit$`Pr(>|t|)`[[1]])
}

build_binary_formula <- function(dep_var, sim_var, group_var, control_terms) {
  as.formula(paste(dep_var, "~", paste(c(sim_var, group_var, paste0(sim_var, ":", group_var), control_terms), collapse = " + "), "| HotelID + year_month"))
}

rule_meta <- function(rule_id) {
  block_map <- list(
    cityym = c("CityID", "Year", "Mon"),
    ym = c("Year", "Mon"),
    cityy = c("CityID", "Year"),
    zipy = c("Zip", "Year"),
    zipym = c("Zip", "Year", "Mon")
  )
  m <- str_match(rule_id, "^(cityym|ym|cityy|zipy|zipym)_(median_strict|median_ge_lt)$")
  if (all(is.na(m))) stop(paste("Unknown rule", rule_id))
  list(block_vars = block_map[[m[[2]]]], split_type = m[[3]])
}

prepare_rule <- function(df, rule_id) {
  meta <- rule_meta(rule_id)
  tmp <- df %>%
    mutate(raw_value = lag_avg_rating_month) %>%
    group_by(across(all_of(meta$block_vars))) %>%
    mutate(
      block_obs = sum(!is.na(raw_value)),
      block_median_value = safe_median(raw_value),
      group_flag = case_when(
        is.na(raw_value) ~ NA_integer_,
        block_obs < 2 ~ NA_integer_,
        meta$split_type == "median_ge_lt" & raw_value < block_median_value ~ 0L,
        meta$split_type == "median_ge_lt" & raw_value >= block_median_value ~ 1L,
        meta$split_type == "median_strict" & raw_value < block_median_value ~ 0L,
        meta$split_type == "median_strict" & raw_value > block_median_value ~ 1L,
        TRUE ~ NA_integer_
      )
    ) %>%
    ungroup()

  block_df <- tmp %>%
    select(all_of(meta$block_vars)) %>%
    mutate(block_id = as.character(do.call(interaction, c(across(everything()), list(drop = TRUE, lex.order = TRUE)))))

  tmp %>%
    bind_cols(block_df %>% select(block_id)) %>%
    transmute(panel_row_id, HotelID, CityID, Year, Mon, year_month, group_flag, block_id)
}

run_perm <- function(df_rule, reps = 1000L, refine = 5000L) {
  obs_formula <- build_binary_formula("ln_RevPAR_clean", "sim_mean", "group_flag", control_terms)
  obs_model <- tryCatch(feols(obs_formula, data = df_rule, cluster = ~HotelID), error = function(e) NULL)
  if (is.null(obs_model)) return(tibble(p_diff_perm = NA_real_, reps_used = 0L))
  obs_beta <- abs(extract_term(obs_model, "sim_mean:group_flag|group_flag:sim_mean")$estimate)
  if (is.na(obs_beta)) return(tibble(p_diff_perm = NA_real_, reps_used = 0L))

  block_list <- split(seq_len(nrow(df_rule)), df_rule$block_id)
  draw_perm <- function() {
    perm_obs <- df_rule$group_flag
    for (idx in block_list) if (length(idx) > 1) perm_obs[idx] <- sample(perm_obs[idx], length(idx), replace = FALSE)
    perm_obs
  }
  run_one <- function(seed_id) {
    set.seed(seed_id + 1000L)
    df_perm <- df_rule %>% mutate(group_perm = draw_perm())
    m <- tryCatch(
      suppressWarnings(feols(build_binary_formula("ln_RevPAR_clean", "sim_mean", "group_perm", control_terms), data = df_perm, cluster = ~HotelID)),
      error = function(e) NULL
    )
    if (is.null(m)) return(NA_real_)
    abs(extract_term(m, "sim_mean:group_perm|group_perm:sim_mean")$estimate)
  }
  perm_stats <- vapply(seq_len(reps), run_one, numeric(1))
  p <- mean(perm_stats >= obs_beta, na.rm = TRUE)
  used <- reps
  if (!is.na(p) && p >= 0.05 && p <= 0.15) {
    extra <- vapply(seq_len(refine - reps), run_one, numeric(1))
    perm_stats <- c(perm_stats, extra)
    p <- mean(perm_stats >= obs_beta, na.rm = TRUE)
    used <- refine
  }
  tibble(p_diff_perm = p, reps_used = used)
}

panel <- read_dta(path_panel) %>% filter(main_sample_keep == 1)

results <- lapply(median_rules, function(rule_id) {
  prepared <- prepare_rule(panel, rule_id)
  df_rule <- panel %>%
    left_join(prepared, by = c("panel_row_id", "HotelID", "CityID", "Year", "Mon", "year_month")) %>%
    filter(!is.na(group_flag))
  perm <- run_perm(df_rule)
  tibble(group_rule = rule_id, p_diff_perm = perm$p_diff_perm, reps_used = perm$reps_used)
})

res <- bind_rows(results)
print(res)

boundary <- read_csv(path_boundary, show_col_types = FALSE)
boundary <- boundary %>%
  mutate(
    p_diff_perm = if_else(moderator == "rating_last" & group_rule %in% res$group_rule,
                          res$p_diff_perm[match(group_rule, res$group_rule)],
                          p_diff_perm)
  )
write_csv(boundary, path_boundary)
