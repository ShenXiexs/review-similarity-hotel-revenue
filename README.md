# Review_Simi_Sales

This repository has been reduced to the reproducibility chain for `Paper_Results_260407.md`.

Current structure:

- `Paper_Results_260407.md`: latest results writeup
- `Review_Simi_260325.Rmd`: main data-processing pipeline
- `scripts/r/`: retained R scripts used by the current heterogeneity and boundary checks
- `scripts/stata/`: retained Stata scripts used by the current tables, GMM, COVID, and heterogeneity runs
- `outputs/`: retained data, tables, scans, and logs referenced by or generated for the current paper results

Removed content:

- older result drafts
- outdated exploratory scripts
- outdated logs and search outputs
- reference and document folders not used by the current paper-results chain

Note:

- `Review_Simi_260325.Rmd` still references upstream raw inputs outside this repository via absolute paths under `Data/revenue_1205/`.
- The in-repo retained dataset for downstream Stata/R scripts is `outputs/valid_match_review_acc_260407_main.dta`.
