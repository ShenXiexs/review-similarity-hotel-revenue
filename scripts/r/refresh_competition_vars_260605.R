library(data.table)
library(haven)

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

project_dir <- detect_project_dir()
data_dir <- file.path(project_dir, "outputs/core_simi_260501/data")
log_dir <- file.path(project_dir, "outputs/core_simi_260501/logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

path_core <- file.path(data_dir, "core_simi_panel_260501.dta")
path_log <- file.path(log_dir, "refresh_competition_vars_260605.log")

panel_targets <- c(
  "core_simi_panel_260501_with_mr_260524.dta",
  "core_simi_panel_260501_with_mr_text_260524.dta",
  "core_simi_panel_260501_with_mr_text_sentiment_260526.dta",
  "core_simi_panel_260501_with_mr_sample1000_260524.dta",
  "core_simi_panel_260501_with_mr_text_sample1000_260524.dta"
)

assert_inside_project(c(path_core, path_log, file.path(data_dir, panel_targets)), project_dir)

sink(path_log, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Refresh competition variables:", as.character(Sys.time()), "\n")
cat("Project:", project_dir, "\n")
cat("Core panel:", path_core, "\n")

if (!file.exists(path_core)) {
  stop("Missing core panel: ", path_core)
}

core <- as.data.table(read_dta(path_core))
core[, HotelID := as.character(HotelID)]
core[, Year := as.integer(Year)]
core[, Mon := as.integer(Mon)]

merge_vars <- c(
  "HotelID", "Year", "Mon",
  "high_comp_zip_full", "high_comp_city_full",
  "high_comp_zip_focus100", "high_comp_city_focus100",
  "high_comp_zip_full_legacy", "high_comp_city_full_legacy"
)

missing_merge <- setdiff(merge_vars, names(core))
if (length(missing_merge) > 0) {
  stop("Core panel is missing: ", paste(missing_merge, collapse = ", "))
}

comp_dt <- unique(core[, ..merge_vars], by = c("HotelID", "Year", "Mon"))
if (anyDuplicated(comp_dt, by = c("HotelID", "Year", "Mon")) > 0) {
  stop("Competition panel is not unique by HotelID-Year-Mon.")
}

for (fname in panel_targets) {
  path_target <- file.path(data_dir, fname)
  if (!file.exists(path_target)) {
    cat("Skip missing target:", path_target, "\n")
    next
  }

  cat("Updating:", path_target, "\n")
  dt <- as.data.table(read_dta(path_target))
  dt[, HotelID := as.character(HotelID)]
  dt[, Year := as.integer(Year)]
  dt[, Mon := as.integer(Mon)]

  drop_vars <- intersect(setdiff(merge_vars, c("HotelID", "Year", "Mon")), names(dt))
  if (length(drop_vars) > 0) {
    dt[, (drop_vars) := NULL]
  }

  dt <- merge(
    dt,
    comp_dt,
    by = c("HotelID", "Year", "Mon"),
    all.x = TRUE,
    sort = FALSE
  )

  write_dta(dt, path_target, version = 14)
  cat("Wrote:", path_target, "\n")
}

cat("Done:", as.character(Sys.time()), "\n")
