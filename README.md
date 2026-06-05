# Review_Simi_Sales

This repository is being reorganized into a result-oriented empirical research project. The current goal is to separate active deliverables, legacy materials, source code, and historical outputs so the main result chain is explicit and reproducible.

## Current Status

Phase 1 of the reorganization is now in place:

- loose root-level logs were moved into `archive/legacy_logs/`
- legacy draft Rmd was moved into `archive/legacy_rmd/`
- the former `chain/` helper folder was moved into `inputs/auxiliary/chain/`
- new top-level folders now distinguish `artifacts/`, `docs/`, `inputs/`, `config/`, `pipelines/`, `src/`, and `archive/`

The analytical code has not yet been fully migrated. Existing runnable scripts still live under `scripts/r/` and `scripts/stata/` until the next refactor stage moves active code into `src/`.

## Actual Repository Layout

```text
Code/
├── artifacts/
│   ├── baseline/
│   ├── core_simi/
│   └── mechanism/
├── archive/
│   ├── legacy_logs/
│   └── legacy_rmd/
├── config/
├── docs/
├── full-data/
├── inputs/
│   └── auxiliary/
├── outputs/
├── pipelines/
├── ref-md/
├── scripts/
├── src/
│   ├── r/
│   └── stata/
└── README.md
```

## Result Chains

The project will be managed through three explicit result chains:

1. `baseline`
   The legacy main-paper replication baseline.
2. `core_simi`
   The current main analysis centered on `sim_mean`.
3. `mechanism`
   Extensions on ARS, management response, sentiment, and hotel profile channels.

Each chain should eventually follow the same internal structure:

```text
artifacts/<chain>/
├── current/
│   ├── data/
│   ├── derived/
│   ├── results/
│   │   ├── tables/
│   │   ├── figures/
│   │   ├── csv/
│   │   └── logs/
│   └── research/
│       └── notes/
└── releases/
```

## Where To Start

- Read `docs/project_map.md` for the repository map.
- Read `docs/result_index.md` for the intended deliverable structure.
- Use `scripts/r/` and `scripts/stata/` as the temporary source of truth for runnable code until the staged migration into `src/` is complete.
- Treat `outputs/` as a legacy-but-real output area until the migration is complete; do not invent new root-level result destinations outside `artifacts/`.

## Known Gaps

- many R and Stata scripts still hard-code the historical absolute path `/Users/samxie/Research/ReviewSimi_Sales/Code`
- `outputs/` remains the practical output root for current scripts, but `artifacts/` is the intended long-term result root
- no single machine-readable manifest currently defines the active release across baseline, core-simi, and mechanism chains

## Next Refactor Stages

1. move active code from `scripts/` into chain-specific `src/` folders
2. centralize path handling in `config/paths.R` and `config/paths.do`
3. define per-chain manifests and reproducible pipeline entrypoints in `pipelines/`
4. migrate final supported outputs from `outputs/` into `artifacts/`
