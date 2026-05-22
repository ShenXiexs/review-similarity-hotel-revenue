#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(readr)
})

`%||%` <- function(x, y) if (is.null(x)) y else x
first_nonmissing <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) return(NA_character_)
  x[[1]]
}

args_file <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])
script_path <- if (!is.na(args_file)) args_file else "scripts/r/add_chain_to_core_panel_260514.R"
project_dir <- normalizePath(file.path(dirname(script_path), "../.."), mustWork = TRUE)

panel_path <- file.path(project_dir, "outputs/core_simi_260501/data/core_simi_panel_260501.dta")
backup_path <- file.path(project_dir, "outputs/core_simi_260501/data/core_simi_panel_260501_prechain_260514.dta")
chain_path <- file.path(project_dir, "chain/chainwjw.csv")
audit_path <- file.path(project_dir, "outputs/core_simi_260501/csv/chain_merge_audit_260514.csv")

stopifnot(file.exists(panel_path), file.exists(chain_path))

if (!file.exists(backup_path)) {
  file.copy(panel_path, backup_path, overwrite = FALSE)
}

panel <- read_dta(panel_path)

chain_ref <- read_csv(chain_path, show_col_types = FALSE) %>%
  mutate(HotelID_chr = as.character(as.integer(HotelID))) %>%
  group_by(HotelID_chr) %>%
  summarise(
    chain_raw = max(chain, na.rm = TRUE),
    chain1_raw = max(chain1, na.rm = TRUE),
    chain2_raw = max(chain2, na.rm = TRUE),
    chain3_raw = max(chain3, na.rm = TRUE),
    chain4_raw = max(chain4, na.rm = TRUE),
    chain_location_name = first_nonmissing(LocationName),
    chain_location_address = first_nonmissing(LocationAddress),
    .groups = "drop"
  ) %>%
  mutate(across(ends_with("_raw"), ~ ifelse(is.infinite(.x), NA_integer_, as.integer(.x))))

panel_aug <- panel %>%
  mutate(HotelID_chr = as.character(HotelID)) %>%
  left_join(chain_ref, by = "HotelID_chr") %>%
  mutate(
    chain_matched = as.integer(!is.na(chain_raw)),
    chain = if_else(is.na(chain_raw), 0L, as.integer(chain_raw)),
    independent = 1L - chain,
    chain_small = if_else(is.na(chain_raw), 0L, as.integer(chain_raw)),
    chain3_small = if_else(is.na(chain3_raw), 0L, as.integer(chain3_raw))
  ) %>%
  select(-HotelID_chr)

attr(panel_aug$chain_raw, "label") <- "Raw chain indicator from chain/chainwjw.csv; missing if unmatched"
attr(panel_aug$chain_matched, "label") <- "1 if HotelID matched chain/chainwjw.csv"
attr(panel_aug$chain, "label") <- "Chain hotel indicator; unmatched hotels coded as 0 independent"
attr(panel_aug$independent, "label") <- "Independent hotel indicator; equals 1 - chain"
attr(panel_aug$chain_small, "label") <- "Alternative chain treatment; unmatched hotels coded as 0 control"
attr(panel_aug$chain3_small, "label") <- "Alternative chain3 treatment; unmatched hotels coded as 0 control"

audit <- bind_rows(
  panel_aug %>%
    summarise(
      sample = "full_panel",
      rows = n(),
      hotels = n_distinct(HotelID),
      matched_hotels = n_distinct(HotelID[chain_matched == 1]),
      chain_hotels = n_distinct(HotelID[chain == 1]),
      independent_hotels = n_distinct(HotelID[independent == 1]),
      unmatched_hotels = n_distinct(HotelID[chain_matched == 0]),
      matched_rows = sum(chain_matched == 1),
      chain_rows = sum(chain == 1),
      independent_rows = sum(independent == 1),
      unmatched_rows = sum(chain_matched == 0)
    ),
  panel_aug %>%
    filter(cs_sample_focus100 == 1) %>%
    summarise(
      sample = "focus100",
      rows = n(),
      hotels = n_distinct(HotelID),
      matched_hotels = n_distinct(HotelID[chain_matched == 1]),
      chain_hotels = n_distinct(HotelID[chain == 1]),
      independent_hotels = n_distinct(HotelID[independent == 1]),
      unmatched_hotels = n_distinct(HotelID[chain_matched == 0]),
      matched_rows = sum(chain_matched == 1),
      chain_rows = sum(chain == 1),
      independent_rows = sum(independent == 1),
      unmatched_rows = sum(chain_matched == 0)
    ),
  panel_aug %>%
    filter(
      cs_sample_focus100 == 1,
      !is.na(ln_RevPAR_clean),
      !is.na(sim_mean),
      !is.na(rating_last_5),
      !is.na(ln_recent_volumn),
      !is.na(recent_sd),
      !is.na(ln_lag_volumn_acc),
      !is.na(lag_avg_rating_acc),
      !is.na(lag_sd_acc),
      !is.na(lag_avg_rating_month),
      !is.na(ln_avg_com_RevPAR),
      !is.na(ln_lag_RevPAR_clean)
    ) %>%
    summarise(
      sample = "h1_main_complete_case",
      rows = n(),
      hotels = n_distinct(HotelID),
      matched_hotels = n_distinct(HotelID[chain_matched == 1]),
      chain_hotels = n_distinct(HotelID[chain == 1]),
      independent_hotels = n_distinct(HotelID[independent == 1]),
      unmatched_hotels = n_distinct(HotelID[chain_matched == 0]),
      matched_rows = sum(chain_matched == 1),
      chain_rows = sum(chain == 1),
      independent_rows = sum(independent == 1),
      unmatched_rows = sum(chain_matched == 0)
    )
)

dir.create(dirname(audit_path), recursive = TRUE, showWarnings = FALSE)
write_csv(audit, audit_path)
write_dta(panel_aug, panel_path)

cat("Updated panel written:", panel_path, "\n")
cat("Backup:", backup_path, "\n")
cat("Audit:", audit_path, "\n")
print(audit)
