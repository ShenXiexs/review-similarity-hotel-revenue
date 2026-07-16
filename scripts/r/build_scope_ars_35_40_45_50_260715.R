# Build additional review-scope ARS variables for scopes 35, 40, 45, and 50.
# The original scope builder is reused in-memory so the review-window definition
# remains identical: current-month reviews plus the N most recent prior reviews.

builder <- "/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/r/build_scope_ars_260509.R"
code <- readLines(builder, warn = FALSE)

code <- sub('RUN_ID <- "260509"', 'RUN_ID <- "260715_scope35_50"', code, fixed = TRUE)
code <- sub('SCOPES <- c(5L, 10L, 15L, 20L, 30L)',
            'SCOPES <- c(35L, 40L, 45L, 50L)', code, fixed = TRUE)
code <- sub('path_panel <- file.path(data_dir, "core_simi_panel_260501.dta")',
            'path_panel <- file.path(data_dir, "core_simi_panel_260501_with_scope_ars.dta")',
            code, fixed = TRUE)
code <- sub('ars_scope_5_10_15_20_30_260509.dta',
            'ars_scope_35_40_45_50_260715.dta', code, fixed = TRUE)
code <- sub('core_simi_panel_260501_with_scope_ars.dta',
            'core_simi_panel_260501_with_scope_ars_35_50_260715.dta', code, fixed = TRUE)
code <- sub('path_panel <- file.path(data_dir, "core_simi_panel_260501_with_scope_ars_35_50_260715.dta")',
            'path_panel <- file.path(data_dir, "core_simi_panel_260501_with_scope_ars.dta")',
            code, fixed = TRUE)
code <- sub('ars_scope_audit_260509.csv',
            'ars_scope_audit_35_40_45_50_260715.csv', code, fixed = TRUE)
code <- sub('build_scope_ars_260509.log',
            'build_scope_ars_35_40_45_50_260715.log', code, fixed = TRUE)
code <- sub('ars_scope_260509', 'ars_scope_35_40_45_50_260715', code, fixed = TRUE)

eval(parse(text = code), envir = .GlobalEnv)
