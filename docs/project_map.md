# Project Map

## Purpose

This file defines the intended boundary between active research deliverables, legacy materials, inputs, source code, and historical outputs.

## Top-Level Folders

- `artifacts/`
  Canonical future home for generated research outputs. This should become the only supported destination for final tables, figures, logs, and machine-readable summaries.

- `archive/`
  Legacy materials kept for traceability but not treated as active project entrypoints.

- `config/`
  Shared path and project settings used by both R and Stata workflows.

- `docs/`
  Human-readable navigation, result map, variable references, and workflow notes.

- `full-data/`
  Local non-committed or heavy upstream inputs used by current scripts.

- `inputs/`
  Non-code project inputs that support the project, including auxiliary mapping files such as the former `chain/` directory.

- `outputs/`
  Historical and currently active output root used by legacy scripts. This remains operational for now but is not the desired long-term destination.

- `pipelines/`
  Thin orchestration entrypoints for running each result chain end-to-end.

- `ref-md/`
  Legacy or reference markdown materials.

- `scripts/`
  Transitional holding area for legacy runnable code.

- `src/`
  Future home for cleaned and chain-specific source code.

## Active Result Chains

- `baseline`
  Legacy main replication line used to preserve comparability with older paper results.

- `core_simi`
  Main current chain that locks the focal explanatory variable to `sim_mean`.

- `mechanism`
  Supporting chain for ARS, management response, sentiment, and profile-based mechanism tests.

## Legacy Materials Already Archived

- root `.log` files were moved into `archive/legacy_logs/`
- root legacy R Markdown draft was moved into `archive/legacy_rmd/`
- `chain/` was moved into `inputs/auxiliary/chain/`

## Migration Rules

- new outputs should not be written to the repository root
- new documentation should distinguish current `outputs/` usage from future `artifacts/` usage
- new code should target configurable paths rather than hard-coded absolute paths
- existing `scripts/` files should be migrated rather than duplicated once a cleaned `src/` replacement is ready
