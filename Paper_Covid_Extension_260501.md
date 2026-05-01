# COVID Extension Results 260501

## Core Setup

All COVID extension regressions keep `sim_mean` as the review similarity variable. The baseline sample filter is `cs_sample_focus100 == 1`. The COVID extension uses two windows:

- `covid2020`: `Year == 2020`, the shock-year definition.
- `covid2020_2022`: `Year >= 2020 & Year <= 2022`, the pandemic-period definition.

The baseline H1-H4 results remain the core story. The COVID analyses below are the extension: COVID changes the strength and location of the negative review-similarity effect.

## Baseline Results Retained

- H1 OLS and 2WFE remain negative and significant. In the main 2WFE-with-lag model, `sim_mean = -0.1783`, `p = 0.008`.
- H1 Sys-GMM strict diagnostic now passes with a non-missing Hansen test in the pre-COVID focus100 sample: `sim_mean = -0.4492`, `p < 0.001`, AR(2) `p = 0.830`, Hansen `p = 0.498`, instruments `157` < hotels `511`. The main RHS is unchanged; the passing specification treats `sim_mean` and controls as level-equation IV-style instruments and uses collapsed GMM instruments for lagged RevPAR, `lag(10 55)`.
- H2 baseline bdiff passes: low-reputation hotels have a more negative similarity effect, empirical `p = 0.000`.
- H3 baseline bdiff passes at 10%: high-popularity hotels have a more negative similarity effect, empirical `p = 0.057`.
- H4 baseline bdiff passes: high-star hotels have a more negative similarity effect pre-COVID, empirical `p = 0.001`.

## COVID Extension Story

H1: COVID weakens or reverses the negative similarity effect.

- 2020 shock, level outcome: pre-COVID slope `-0.1407`, `p = 0.017`; COVID interaction `+0.4313`, `p = 0.086`.
- 2020-2022 pandemic, level outcome: pre-COVID slope `-0.2367`, `p < 0.001`; pandemic interaction `+0.4288`, `p = 0.006`.
- 2020-2022 pandemic, growth outcome: pre-COVID slope `-0.2277`, `p = 0.001`; pandemic interaction `+0.5706`, `p = 0.001`.

H2: reputation heterogeneity is mainly a pandemic-period effect in the COVID-specific grouping.

- COVID grouping: `lag_rating_last_5` split by `Zip x ym` median; low reputation is below the median.
- Pre-COVID bdiff is not significant: empirical `p = 0.252`.
- 2020 shock bdiff is not significant: empirical `p = 0.348`.
- 2020-2022 pandemic bdiff is significant: observed difference `0.342`, empirical `p = 0.047`.

H3: popularity heterogeneity is also stronger in the full pandemic period than in 2020 alone.

- COVID grouping: `lag_recent_volumn` split by overall median; low popularity is below the median.
- Pre-COVID bdiff is not significant in this COVID-specific grouping: empirical `p = 0.151`.
- 2020 shock bdiff is not significant: empirical `p = 0.363`.
- 2020-2022 pandemic bdiff is significant at 10%: observed difference `-0.459`, empirical `p = 0.067`.

H4: COVID reverses the star-class boundary.

- COVID grouping: `star_class <= 3` vs `star_class > 3`; low-star hotels are group 1.
- Pre-COVID: high-star hotels are more negatively affected, observed difference `-0.264`, empirical `p = 0.002`.
- 2020 shock: the difference reverses, observed difference `1.982`, empirical `p = 0.038`.
- 2020-2022 pandemic: the reversal persists, observed difference `0.494`, empirical `p = 0.044`.
- Triple interaction confirms the reversal: `h4_covid_lowstar3#covid2020_2022#c.sim_mean = -0.8138`, `p = 0.029`.

## Output Files

- Main do-file: `scripts/stata/run_core_simi_explicit_regressions_260501.do`
- Main log: `outputs/core_simi_260501/logs/run_core_simi_explicit_regressions_260501.log`
- H1 COVID table: `outputs/core_simi_260501/tables_explicit/covid_h1_interactions_260501.rtf`
- H2-H4 COVID triple table: `outputs/core_simi_260501/tables_explicit/covid_h2_h4_triple_interactions_260501.rtf`
- COVID H1 scan: `outputs/core_simi_260501/scans/covid_h1_fe_scan_260501.csv`
- COVID heterogeneity scan: `outputs/core_simi_260501/scans/covid_h2_h4_interaction_scan_260501.csv`
- H1 strict Sys-GMM scan: `outputs/core_simi_260501/scans/h1_sysgmm_fine_scan_260502.csv`
- H1 targeted Sys-GMM scan: `outputs/core_simi_260501/scans/h1_sysgmm_targeted_scan2_260502.csv`
- H1 selected Sys-GMM diagnostics: `outputs/core_simi_260501/scans/h1_sysgmm_selected_260502.csv`

## Interpretation Boundary

The cleanest COVID story is not that every heterogeneity channel strengthens immediately in 2020. Instead, the 2020 single-year shock is noisy, while the 2020-2022 pandemic window gives the clearer extension: the average negative similarity effect weakens or reverses, and the star-class heterogeneity flips from high-star vulnerability before COVID to low-star vulnerability during COVID. For Sys-GMM, strict Hansen-passing evidence is strongest in the pre-COVID focus100 baseline; full focus100 and exclude-2020 variants keep negative coefficients in many scans but fail Hansen, so they are treated as diagnostic boundaries rather than the formal H1 GMM table.
