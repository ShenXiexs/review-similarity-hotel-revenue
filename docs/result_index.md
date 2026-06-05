# Result Index

## Objective

The repository should expose a single clear answer to three questions:

1. Which result chain is the main one?
2. Where are the final tables and figures?
3. Which files are archival only?

## Intended Deliverables

### `artifacts/baseline/`

- role: historical baseline replication
- status: scaffold created, outputs not yet migrated
- final deliverables expected:
  - `current/results/tables/`
  - `current/results/figures/`
  - `current/results/csv/`
  - `current/results/logs/`
  - `current/research/notes/result_baseline.md`

### `artifacts/core_simi/`

- role: primary current paper result chain
- status: scaffold created, outputs not yet migrated
- final deliverables expected:
  - `current/results/tables/`
  - `current/results/figures/`
  - `current/results/csv/`
  - `current/results/logs/`
  - `current/research/notes/result_core_simi.md`

### `artifacts/mechanism/`

- role: supporting mechanism and extension chain
- status: scaffold created, outputs not yet migrated
- final deliverables expected:
  - `current/results/tables/`
  - `current/results/figures/`
  - `current/results/csv/`
  - `current/results/logs/`
  - `current/research/notes/result_mechanism.md`

## Current Temporary Source Of Truth

Until migration is complete:

- active code remains under `scripts/r/` and `scripts/stata/`
- current empirical outputs still largely live under `outputs/`
- archived root logs remain under `archive/legacy_logs/`
- legacy drafts remain under `archive/legacy_rmd/`

## Intended Master Summary

The project should eventually maintain a single machine-readable summary file:

`artifacts/master_results.csv`

Recommended columns:

- `chain`
- `release_id`
- `hypothesis`
- `sample`
- `dep_var`
- `focal_var`
- `model`
- `coef`
- `se`
- `p_value`
- `n_obs`
- `output_file`
- `notes`

## Promotion Rule

A result should be treated as final only when all of the following exist for the same chain and release:

- the generated data file
- the final table outputs
- the raw execution log
- a short written result note
- a manifest declaring inputs, scripts, and outputs
