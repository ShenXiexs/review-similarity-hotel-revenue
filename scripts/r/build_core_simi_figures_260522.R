suppressPackageStartupMessages({
  suppressWarnings({
    library(dplyr)
    library(forcats)
    library(ggplot2)
    library(haven)
    library(readr)
    library(scales)
    library(stringr)
    library(tidyr)
  })
})

RUN_ID <- "260522"

detect_project_dir <- function() {
  candidates <- unique(c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE),
    "/Users/samxie/Research/ReviewSimi_Sales/Code"
  ))

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "CoreSimi_Variable_Profile_260501.md")) &&
        dir.exists(file.path(candidate, "outputs", "core_simi_260501"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop("Cannot locate project root.")
}

project_dir <- detect_project_dir()
out_root <- file.path(project_dir, "outputs", "core_simi_260501")
data_path <- file.path(out_root, "data", "core_simi_panel_260501.dta")
fig_dir <- file.path(out_root, "figures")
summary_dir <- file.path(out_root, "summary")
md_path <- file.path(fig_dir, paste0("CoreSimi_Figures_", RUN_ID, ".md"))
monthly_csv <- file.path(summary_dir, paste0("figure_monthly_summary_", RUN_ID, ".csv"))

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(data_path)) {
  stop("Cannot find input data: ", data_path)
}

mean_na <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  mean(x, na.rm = TRUE)
}

median_na <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  median(x, na.rm = TRUE)
}

sd_na <- function(x) {
  if (sum(!is.na(x)) < 2) return(NA_real_)
  sd(x, na.rm = TRUE)
}

safe_min <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  min(x, na.rm = TRUE)
}

safe_max <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  max(x, na.rm = TRUE)
}

plot_path <- function(file_name) file.path(fig_dir, file_name)

rel_fig <- function(file_name) file.path(".", file_name)

pipe_table <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  names(df) <- as.character(names(df))
  rows <- apply(df, 1, function(x) paste0("|", paste(as.character(x), collapse = "|"), "|"))
  c(
    paste0("|", paste(names(df), collapse = "|"), "|"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    rows
  )
}

save_plot <- function(plot, file_name, width = 9.2, height = 5.2) {
  ggsave(
    filename = plot_path(file_name),
    plot = plot,
    width = width,
    height = height,
    dpi = 300,
    bg = "white"
  )
  invisible(file_name)
}

covid_rect <- function(alpha = 0.10, fill = "#D95F02") {
  annotate(
    "rect",
    xmin = as.Date("2020-03-01"),
    xmax = as.Date("2022-09-01"),
    ymin = -Inf,
    ymax = Inf,
    fill = fill,
    alpha = alpha
  )
}

base_theme <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(color = "grey30", size = 10),
      plot.caption = element_text(color = "grey40", size = 8),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank()
    )
}

date_scale <- scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = expansion(mult = c(0.01, 0.02)))

d_raw <- read_dta(data_path)

d <- d_raw %>%
  mutate(
    date = if ("ym_date" %in% names(.)) {
      as.Date(ym_date)
    } else {
      as.Date(paste0(year_month, "-01"))
    },
    covid_period = case_when(
      Year <= 2019 ~ "Pre-COVID 2011-2019",
      Year == 2020 ~ "2020 shock",
      Year >= 2021 ~ "2021-2022 pandemic tail",
      TRUE ~ NA_character_
    ),
    covid_period = factor(
      covid_period,
      levels = c("Pre-COVID 2011-2019", "2020 shock", "2021-2022 pandemic tail")
    ),
    star_group = case_when(
      !is.na(star_class) & star_class <= 3 ~ "Low star (<=3)",
      !is.na(star_class) & star_class > 3 ~ "High star (>3)",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(cs_sample_focus100 == 1, !is.na(date))

monthly <- d %>%
  group_by(date, year_month, Year, Mon) %>%
  summarise(
    obs = n(),
    hotels = n_distinct(HotelID),
    revpar_mean = mean_na(RevPAR_clean),
    revpar_median = median_na(RevPAR_clean),
    ln_revpar_mean = mean_na(ln_RevPAR_clean),
    comp_revpar_mean = mean_na(avg_com_RevPAR),
    cum_reviews_mean = mean_na(volumn_acc),
    cum_reviews_median = median_na(volumn_acc),
    recent_reviews_mean = mean_na(recent_volumn),
    month_reviews_mean = mean_na(volumn_month),
    sim_mean_avg = mean_na(sim_mean),
    rating_month_mean = mean_na(avg_rating_month),
    rating_last5_mean = mean_na(rating_last_5),
    lag_rating_month_mean = mean_na(lag_avg_rating_month),
    lag_rating_acc_mean = mean_na(lag_avg_rating_acc),
    recent_rating_mean = mean_na(recent_rating),
    .groups = "drop"
  ) %>%
  arrange(date)

write_csv(monthly, monthly_csv)

sample_summary <- tibble(
  item = c(
    "Hotel-month observations",
    "Hotels",
    "Cities",
    "Calendar months",
    "Month range",
    "Mean RevPAR_clean",
    "Median RevPAR_clean",
    "Mean cumulative reviews",
    "Mean recent reviews",
    "Mean review similarity"
  ),
  value = c(
    comma(nrow(d)),
    comma(n_distinct(d$HotelID)),
    comma(n_distinct(d$CityID)),
    comma(n_distinct(d$date)),
    paste0(format(min(d$date), "%Y-%m"), " to ", format(max(d$date), "%Y-%m")),
    number(mean_na(d$RevPAR_clean), accuracy = 0.1),
    number(median_na(d$RevPAR_clean), accuracy = 0.1),
    number(mean_na(d$volumn_acc), accuracy = 0.1),
    number(mean_na(d$recent_volumn), accuracy = 0.1),
    number(mean_na(d$sim_mean), accuracy = 0.001)
  )
)

period_summary <- d %>%
  group_by(covid_period) %>%
  summarise(
    obs = n(),
    hotels = n_distinct(HotelID),
    mean_revpar = mean_na(RevPAR_clean),
    median_revpar = median_na(RevPAR_clean),
    mean_recent_reviews = mean_na(recent_volumn),
    mean_sim = mean_na(sim_mean),
    .groups = "drop"
  ) %>%
  mutate(
    obs = comma(obs),
    hotels = comma(hotels),
    mean_revpar = number(mean_revpar, accuracy = 0.1),
    median_revpar = number(median_revpar, accuracy = 0.1),
    mean_recent_reviews = number(mean_recent_reviews, accuracy = 0.1),
    mean_sim = number(mean_sim, accuracy = 0.001)
  )

figures <- list()

figures$coverage <- save_plot(
  ggplot(monthly, aes(x = date)) +
    covid_rect() +
    geom_col(aes(y = obs), fill = "#4C78A8", alpha = 0.75, width = 25) +
    geom_line(aes(y = hotels * max(obs, na.rm = TRUE) / max(hotels, na.rm = TRUE)), color = "#F58518", linewidth = 0.8) +
    scale_y_continuous(
      labels = comma,
      sec.axis = sec_axis(
        ~ . * max(monthly$hotels, na.rm = TRUE) / max(monthly$obs, na.rm = TRUE),
        name = "Hotels",
        labels = comma
      )
    ) +
    date_scale +
    labs(
      title = "Monthly sample coverage",
      subtitle = "Bars show hotel-month observations; orange line shows active hotels. Shaded area marks Mar 2020 onward.",
      x = NULL,
      y = "Hotel-month observations",
      caption = "Sample: cs_sample_focus100 == 1."
    ) +
    base_theme(),
  "fig01_monthly_coverage.png"
)

figures$revpar_trend <- save_plot(
  ggplot(monthly, aes(x = date)) +
    covid_rect() +
    geom_line(aes(y = revpar_mean, color = "Mean RevPAR"), linewidth = 0.9, na.rm = TRUE) +
    geom_line(aes(y = revpar_median, color = "Median RevPAR"), linewidth = 0.9, na.rm = TRUE) +
    geom_vline(xintercept = as.Date("2020-03-01"), linetype = "dashed", color = "grey35") +
    scale_color_manual(values = c("Mean RevPAR" = "#1B9E77", "Median RevPAR" = "#7570B3")) +
    scale_y_continuous(labels = dollar_format(accuracy = 1)) +
    date_scale +
    labs(
      title = "RevPAR over time",
      subtitle = "Monthly mean and median RevPAR_clean in the baseline focus100 sample.",
      x = NULL,
      y = "RevPAR_clean",
      caption = "COVID shading starts in March 2020."
    ) +
    base_theme(),
  "fig02_revpar_monthly_trend.png"
)

figures$cum_reviews <- save_plot(
  ggplot(monthly, aes(x = date)) +
    covid_rect(alpha = 0.08, fill = "#7570B3") +
    geom_line(aes(y = cum_reviews_mean, color = "Mean cumulative reviews"), linewidth = 0.9, na.rm = TRUE) +
    geom_line(aes(y = cum_reviews_median, color = "Median cumulative reviews"), linewidth = 0.9, na.rm = TRUE) +
    scale_color_manual(values = c("Mean cumulative reviews" = "#E45756", "Median cumulative reviews" = "#54A24B")) +
    scale_y_continuous(labels = comma) +
    date_scale +
    labs(
      title = "Cumulative review volume over time",
      subtitle = "Average and median hotel-level cumulative reviews by month.",
      x = NULL,
      y = "volumn_acc",
      caption = "The early upward trend also reflects increasing hotel coverage in the constructed panel."
    ) +
    base_theme(),
  "fig03_cumulative_reviews_monthly.png"
)

figures$recent_reviews <- save_plot(
  ggplot(monthly, aes(x = date)) +
    covid_rect(alpha = 0.08, fill = "#E45756") +
    geom_line(aes(y = recent_reviews_mean, color = "Recent-review window"), linewidth = 0.9, na.rm = TRUE) +
    geom_line(aes(y = month_reviews_mean, color = "Current month reviews"), linewidth = 0.9, na.rm = TRUE) +
    scale_color_manual(values = c("Recent-review window" = "#4C78A8", "Current month reviews" = "#F58518")) +
    scale_y_continuous(labels = comma) +
    date_scale +
    labs(
      title = "Review flow over time",
      subtitle = "Monthly averages for recent-review volume and observed current-month review volume.",
      x = NULL,
      y = "Review count",
      caption = "These series diagnose whether consumer-review activity drops around COVID."
    ) +
    base_theme(),
  "fig04_review_flow_monthly.png"
)

figures$similarity <- save_plot(
  ggplot(monthly, aes(x = date, y = sim_mean_avg)) +
    covid_rect(alpha = 0.08, fill = "#72B7B2") +
    geom_line(color = "#B279A2", linewidth = 0.9, na.rm = TRUE) +
    geom_point(color = "#B279A2", size = 0.7, alpha = 0.7, na.rm = TRUE) +
    date_scale +
    labs(
      title = "Review similarity over time",
      subtitle = "Monthly mean of the core review-similarity variable sim_mean.",
      x = NULL,
      y = "Mean sim_mean",
      caption = "This is descriptive; formal models still control for hotel and year-month fixed effects."
    ) +
    base_theme(),
  "fig05_similarity_monthly_trend.png"
)

ratings_long <- monthly %>%
  select(date, rating_last5_mean, lag_rating_month_mean, lag_rating_acc_mean) %>%
  pivot_longer(cols = -date, names_to = "series", values_to = "rating") %>%
  mutate(
    series = recode(
      series,
      rating_last5_mean = "Last 5 reviews rating",
      lag_rating_month_mean = "Lagged monthly rating",
      lag_rating_acc_mean = "Lagged cumulative rating"
    )
  )

figures$ratings <- save_plot(
  ggplot(ratings_long, aes(x = date, y = rating, color = series)) +
    covid_rect(alpha = 0.08, fill = "#54A24B") +
    geom_line(linewidth = 0.9, na.rm = TRUE) +
    scale_color_manual(values = c(
      "Last 5 reviews rating" = "#ECA82C",
      "Lagged monthly rating" = "#4C78A8",
      "Lagged cumulative rating" = "#B279A2"
    )) +
    scale_y_continuous(limits = c(1, 5), breaks = 1:5) +
    date_scale +
    labs(
      title = "Rating control trends over time",
      subtitle = "Monthly means of rating variables used as controls or reputation moderators.",
      x = NULL,
      y = "Average rating",
      caption = "Y-axis uses the full 1-5 rating scale; COVID shading starts in March 2020."
    ) +
    base_theme(),
  "fig06_rating_monthly_trend.png"
)

covid_index <- monthly %>%
  select(date, Year, RevPAR = revpar_mean, Competitor_RevPAR = comp_revpar_mean, Recent_reviews = recent_reviews_mean, Similarity = sim_mean_avg) %>%
  pivot_longer(cols = c(RevPAR, Competitor_RevPAR, Recent_reviews, Similarity), names_to = "metric", values_to = "value") %>%
  group_by(metric) %>%
  mutate(
    base_2019 = mean_na(value[Year == 2019]),
    index_2019 = 100 * value / base_2019
  ) %>%
  ungroup() %>%
  mutate(metric = recode(metric, Competitor_RevPAR = "Competitor RevPAR", Recent_reviews = "Recent reviews"))

figures$covid_index <- save_plot(
  ggplot(covid_index, aes(x = date, y = index_2019, color = metric)) +
    covid_rect(alpha = 0.06, fill = "#D95F02") +
    geom_hline(yintercept = 100, color = "grey55", linewidth = 0.4) +
    geom_line(linewidth = 0.8, na.rm = TRUE) +
    scale_color_manual(values = c(
      "RevPAR" = "#1B9E77",
      "Competitor RevPAR" = "#7570B3",
      "Recent reviews" = "#E45756",
      "Similarity" = "#4C78A8"
    )) +
    scale_y_continuous(labels = label_number(accuracy = 1, suffix = "")) +
    date_scale +
    labs(
      title = "COVID-period index relative to 2019",
      subtitle = "Each monthly series is indexed to its own 2019 average = 100.",
      x = NULL,
      y = "Index, 2019 average = 100",
      caption = "Useful for visualizing whether COVID moved performance, review flow, and similarity in the same direction."
    ) +
    base_theme(),
  "fig07_covid_index_2019_base.png"
)

figures$period_box <- save_plot(
  ggplot(d %>% filter(!is.na(covid_period), !is.na(ln_RevPAR_clean)), aes(x = covid_period, y = ln_RevPAR_clean, fill = covid_period)) +
    geom_violin(alpha = 0.35, color = NA, trim = TRUE) +
    geom_boxplot(width = 0.18, outlier.alpha = 0.08, outlier.size = 0.5) +
    scale_fill_manual(values = c(
      "Pre-COVID 2011-2019" = "#4C78A8",
      "2020 shock" = "#E45756",
      "2021-2022 pandemic tail" = "#54A24B"
    )) +
    labs(
      title = "Distribution of log RevPAR by COVID period",
      subtitle = "Violin and boxplot view of performance before COVID, in 2020, and after 2020.",
      x = NULL,
      y = "ln_RevPAR_clean",
      caption = "This is an unconditional distribution, not a fixed-effects estimate."
    ) +
    base_theme() +
    theme(axis.text.x = element_text(angle = 10, hjust = 1), legend.position = "none"),
  "fig08_ln_revpar_by_covid_period.png"
)

city_month <- d %>%
  group_by(CityID, date) %>%
  summarise(revpar_mean = mean_na(RevPAR_clean), hotels = n_distinct(HotelID), .groups = "drop") %>%
  filter(hotels >= 3)

figures$city_revpar <- save_plot(
  ggplot(city_month, aes(x = date, y = revpar_mean, color = CityID)) +
    covid_rect(alpha = 0.07, fill = "#7570B3") +
    geom_line(linewidth = 0.8, alpha = 0.92, na.rm = TRUE) +
    scale_y_continuous(labels = dollar_format(accuracy = 1)) +
    date_scale +
    labs(
      title = "RevPAR trends by city",
      subtitle = "Mean RevPAR_clean by CityID and month.",
      x = NULL,
      y = "Mean RevPAR_clean",
      caption = "Only city-month cells with at least three active hotels are plotted."
    ) +
    base_theme(),
  "fig09_city_revpar_trends.png"
)

star_month <- d %>%
  filter(!is.na(star_group)) %>%
  group_by(star_group, date) %>%
  summarise(revpar_mean = mean_na(RevPAR_clean), hotels = n_distinct(HotelID), .groups = "drop") %>%
  filter(hotels >= 5)

figures$star_revpar <- save_plot(
  ggplot(star_month, aes(x = date, y = revpar_mean, color = star_group)) +
    covid_rect(alpha = 0.08, fill = "#D95F02") +
    geom_line(linewidth = 0.9, na.rm = TRUE) +
    scale_color_manual(values = c("Low star (<=3)" = "#4C78A8", "High star (>3)" = "#F58518")) +
    scale_y_continuous(labels = dollar_format(accuracy = 1)) +
    date_scale +
    labs(
      title = "RevPAR by star group around COVID",
      subtitle = "Low-star boundary follows the COVID extension definition: star_class <= 3.",
      x = NULL,
      y = "Mean RevPAR_clean",
      caption = "This figure helps visualize the H4 COVID reversal story descriptively."
    ) +
    base_theme(),
  "fig10_star_group_revpar_covid.png"
)

revpar_heat <- monthly %>%
  mutate(
    year = factor(Year),
    month = factor(month.abb[Mon], levels = month.abb)
  )

figures$heatmap <- save_plot(
  ggplot(revpar_heat, aes(x = month, y = year, fill = revpar_mean)) +
    geom_tile(color = "white", linewidth = 0.25) +
    scale_fill_gradient2(
      low = "#4C78A8",
      mid = "white",
      high = "#E45756",
      midpoint = median_na(revpar_heat$revpar_mean),
      labels = dollar_format(accuracy = 1),
      na.value = "grey90"
    ) +
    labs(
      title = "Seasonality heatmap for RevPAR",
      subtitle = "Monthly mean RevPAR_clean by calendar year and calendar month.",
      x = NULL,
      y = NULL,
      fill = "RevPAR",
      caption = "The 2022 panel ends in September."
    ) +
    base_theme() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)),
  "fig11_revpar_year_month_heatmap.png",
  width = 9.2,
  height = 5.5
)

sim_bins <- d %>%
  filter(!is.na(sim_mean), !is.na(ln_RevPAR_clean)) %>%
  mutate(sim_bin = ntile(sim_mean, 10)) %>%
  group_by(sim_bin) %>%
  summarise(
    n = n(),
    sim_mean_bin = mean_na(sim_mean),
    ln_revpar_mean = mean_na(ln_RevPAR_clean),
    ln_revpar_se = sd_na(ln_RevPAR_clean) / sqrt(n()),
    sim_min = safe_min(sim_mean),
    sim_max = safe_max(sim_mean),
    .groups = "drop"
  )

figures$sim_bins <- save_plot(
  ggplot(sim_bins, aes(x = sim_mean_bin, y = ln_revpar_mean)) +
    geom_errorbar(aes(ymin = ln_revpar_mean - 1.96 * ln_revpar_se, ymax = ln_revpar_mean + 1.96 * ln_revpar_se), width = 0.002, color = "grey45") +
    geom_line(color = "#4C78A8", linewidth = 0.8) +
    geom_point(aes(size = n), color = "#4C78A8", alpha = 0.9) +
    scale_size_continuous(labels = comma) +
    labs(
      title = "Binned relationship between similarity and log RevPAR",
      subtitle = "Hotel-month observations are split into deciles of sim_mean.",
      x = "Mean sim_mean within decile",
      y = "Mean ln_RevPAR_clean",
      size = "Rows",
      caption = "Raw descriptive bins; not a substitute for the fixed-effects regressions."
    ) +
    base_theme(),
  "fig12_similarity_revpar_bins.png"
)

review_bins <- d %>%
  filter(!is.na(ln_lag_volumn_acc), !is.na(ln_RevPAR_clean)) %>%
  mutate(review_bin = ntile(ln_lag_volumn_acc, 10)) %>%
  group_by(review_bin) %>%
  summarise(
    n = n(),
    ln_reviews_mean = mean_na(ln_lag_volumn_acc),
    reviews_mean = mean_na(lag_volumn_acc),
    ln_revpar_mean = mean_na(ln_RevPAR_clean),
    ln_revpar_se = sd_na(ln_RevPAR_clean) / sqrt(n()),
    .groups = "drop"
  )

figures$review_bins <- save_plot(
  ggplot(review_bins, aes(x = reviews_mean, y = ln_revpar_mean)) +
    geom_errorbar(aes(ymin = ln_revpar_mean - 1.96 * ln_revpar_se, ymax = ln_revpar_mean + 1.96 * ln_revpar_se), width = 0, color = "grey45") +
    geom_line(color = "#E45756", linewidth = 0.8) +
    geom_point(aes(size = n), color = "#E45756", alpha = 0.9) +
    scale_x_log10(labels = comma) +
    scale_size_continuous(labels = comma) +
    labs(
      title = "Binned relationship between cumulative reviews and log RevPAR",
      subtitle = "Hotel-month observations are split into deciles of lagged cumulative review volume.",
      x = "Mean lagged cumulative reviews within decile, log scale",
      y = "Mean ln_RevPAR_clean",
      size = "Rows",
      caption = "This visualizes popularity-performance association without controls."
    ) +
    base_theme(),
  "fig13_cumulative_reviews_revpar_bins.png"
)

key_vars <- d %>%
  transmute(
    ln_RevPAR = ln_RevPAR_clean,
    sim_mean,
    recent_reviews = ln_recent_volumn,
    cumulative_reviews = ln_lag_volumn_acc,
    recent_sd,
    rating_last5 = rating_last_5,
    avg_rating_acc = lag_avg_rating_acc,
    competitor_RevPAR = ln_avg_com_RevPAR,
    lag_ln_RevPAR = ln_lag_RevPAR_clean,
    star_class
  )

corr_mat <- cor(key_vars, use = "pairwise.complete.obs")
corr_df <- as.data.frame(as.table(corr_mat)) %>%
  rename(var1 = Var1, var2 = Var2, corr = Freq) %>%
  mutate(
    var1 = factor(var1, levels = colnames(corr_mat)),
    var2 = factor(var2, levels = rev(colnames(corr_mat)))
  )

figures$corr <- save_plot(
  ggplot(corr_df, aes(x = var1, y = var2, fill = corr)) +
    geom_tile(color = "white", linewidth = 0.25) +
    geom_text(aes(label = number(corr, accuracy = 0.01)), size = 2.5, color = "grey15") +
    scale_fill_gradient2(low = "#4C78A8", mid = "white", high = "#E45756", midpoint = 0, limits = c(-1, 1)) +
    labs(
      title = "Correlation heatmap for core variables",
      subtitle = "Pairwise correlations in the baseline focus100 sample.",
      x = NULL,
      y = NULL,
      fill = "Corr.",
      caption = "Pairwise complete observations are used for each correlation."
    ) +
    base_theme() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      panel.grid = element_blank()
    ),
  "fig14_core_variable_correlation_heatmap.png",
  width = 9.2,
  height = 7.2
)

fig_table <- tibble(
  figure = c(
    "Figure 1",
    "Figure 2",
    "Figure 3",
    "Figure 4",
    "Figure 5",
    "Figure 6",
    "Figure 7",
    "Figure 8",
    "Figure 9",
    "Figure 10",
    "Figure 11",
    "Figure 12",
    "Figure 13",
    "Figure 14"
  ),
  file = unlist(figures, use.names = FALSE),
  purpose = c(
    "Panel coverage by month",
    "Revenue performance trend over year-month",
    "Cumulative review accumulation over year-month",
    "Current and recent review-flow trend",
    "Core review-similarity trend",
    "Rating trend for reputation controls",
    "COVID-period normalized index",
    "Log RevPAR distribution before and during COVID",
    "City-level RevPAR trajectories",
    "Star-group RevPAR around COVID",
    "Seasonality heatmap for RevPAR",
    "Raw binned similarity-performance relation",
    "Raw binned popularity-performance relation",
    "Correlation structure among core variables"
  )
)

md_lines <- c(
  "# Core-Simi Descriptive Figures 260522",
  "",
  "本文件集中放置基于 `outputs/core_simi_260501/data/core_simi_panel_260501.dta` 生成的描述性图。除特别说明外，所有图都使用主回归样本 `cs_sample_focus100 == 1`。这些图用于展示数据结构、时间趋势、COVID 冲击和核心变量之间的描述性关系；它们不是固定效应或 GMM 的因果估计。",
  "",
  "## How To Reproduce",
  "",
  "```bash",
  "Rscript scripts/r/build_core_simi_figures_260522.R",
  "```",
  "",
  paste0("- Figure directory: `", normalizePath(fig_dir, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Monthly summary CSV: `", normalizePath(monthly_csv, winslash = "/", mustWork = FALSE), "`"),
  "",
  "## Sample Snapshot",
  "",
  pipe_table(sample_summary),
  "",
  "## COVID Period Snapshot",
  "",
  pipe_table(period_summary),
  "",
  "## Figure Inventory",
  "",
  pipe_table(fig_table),
  "",
  "## Figures",
  "",
  "### 1. Monthly Sample Coverage",
  "",
  "先看每个月有多少 hotel-month 观测和活跃酒店，避免把样本覆盖变化误读成经济趋势。",
  "",
  paste0("![](", rel_fig(figures$coverage), ")"),
  "",
  "### 2. RevPAR Over Year-Month",
  "",
  "`RevPAR_clean` 的月度均值和中位数。COVID 期间阴影有助于直接观察 2020 年以后的收入冲击和恢复。",
  "",
  paste0("![](", rel_fig(figures$revpar_trend), ")"),
  "",
  "### 3. Cumulative Review Volume Over Year-Month",
  "",
  "`volumn_acc` 展示酒店累计评论量如何随时间增长；均值和中位数同时画出，方便识别头部酒店对均值的拉动。",
  "",
  paste0("![](", rel_fig(figures$cum_reviews), ")"),
  "",
  "### 4. Review Flow Over Year-Month",
  "",
  "近期评论窗口和当月评论量可以辅助判断 COVID 是否改变评论产生频率。",
  "",
  paste0("![](", rel_fig(figures$recent_reviews), ")"),
  "",
  "### 5. Review Similarity Over Year-Month",
  "",
  "`sim_mean` 是主解释变量。这个图检查相似度本身是否存在明显时间趋势或 COVID 期间变化。",
  "",
  paste0("![](", rel_fig(figures$similarity), ")"),
  "",
  "### 6. Rating Trend",
  "",
  "评分变量既是控制变量，也参与声誉异质性分组。这里展示 `rating_last_5`、`lag_avg_rating_month` 和 `lag_avg_rating_acc` 的月度均值，y 轴使用完整 1-5 评分刻度。",
  "",
  paste0("![](", rel_fig(figures$ratings), ")"),
  "",
  "### 7. COVID Index Relative To 2019",
  "",
  "把 RevPAR、竞争酒店 RevPAR、近期评论量和相似度都标准化为 2019 年均值等于 100，便于在一张图上比较 COVID 期间相对变化幅度。",
  "",
  paste0("![](", rel_fig(figures$covid_index), ")"),
  "",
  "### 8. Log RevPAR By COVID Period",
  "",
  "COVID 前、2020 shock 年、2021-2022 pandemic tail 的 `ln_RevPAR_clean` 分布对比。",
  "",
  paste0("![](", rel_fig(figures$period_box), ")"),
  "",
  "### 9. City-Level RevPAR Trends",
  "",
  "按 `CityID` 展示收入趋势，检查 COVID 冲击是否主要由某个城市驱动。",
  "",
  paste0("![](", rel_fig(figures$city_revpar), ")"),
  "",
  "### 10. Star-Group RevPAR Around COVID",
  "",
  "按 COVID extension 中使用的 `star_class <= 3` 分界展示低星级和高星级酒店收入走势。",
  "",
  paste0("![](", rel_fig(figures$star_revpar), ")"),
  "",
  "### 11. RevPAR Seasonality Heatmap",
  "",
  "Year-month 热力图能同时展示季节性、年份趋势和 2020 年以后的异常月份。",
  "",
  paste0("![](", rel_fig(figures$heatmap), ")"),
  "",
  "### 12. Similarity And Log RevPAR Bins",
  "",
  "把 `sim_mean` 按十分位分箱，展示原始的相似度-绩效关系。正式结论仍以 FE/GMM 表为准。",
  "",
  paste0("![](", rel_fig(figures$sim_bins), ")"),
  "",
  "### 13. Cumulative Reviews And Log RevPAR Bins",
  "",
  "按滞后累计评论量分箱，展示 popularity 与绩效之间的描述性关系。",
  "",
  paste0("![](", rel_fig(figures$review_bins), ")"),
  "",
  "### 14. Core Variable Correlation Heatmap",
  "",
  "核心变量相关矩阵有助于快速识别控制变量之间的共线性和与因变量的简单相关方向。",
  "",
  paste0("![](", rel_fig(figures$corr), ")"),
  "",
  "## Interpretation Notes",
  "",
  "- `RevPAR_clean` 和 `ln_RevPAR_clean` 是绩效变量；图中 revenue 统一按 RevPAR 理解。",
  "- COVID 阴影从 2020-03 开始，到样本结束 2022-09；period 表把 2020 单独作为 shock 年，把 2021-2022 作为后续 pandemic tail。",
  "- 时间趋势图是月度聚合，可能受到活跃酒店数量变化影响，所以 Figure 1 应和后续趋势图一起看。",
  "- binned plots 和 correlation heatmap 都是 raw descriptive evidence，不控制酒店固定效应、年月固定效应或动态滞后项。"
)

write_lines(md_lines, md_path)

message("Wrote figures to: ", fig_dir)
message("Wrote markdown to: ", md_path)
message("Wrote monthly summary to: ", monthly_csv)
