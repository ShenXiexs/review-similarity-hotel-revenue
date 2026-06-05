# Inputs

This folder is for non-code project inputs that are required or useful for rebuilding result chains.

## Current Contents

- `auxiliary/chain/`
  Legacy helper files previously stored at the repository root as `chain/`.

## Related External Inputs

The current project also relies on local data areas outside this folder, especially `full-data/` and historical upstream sources referenced by legacy scripts.

## Input Policy

- raw or external-source files should be documented here even when they cannot be committed
- helper mapping files should not live at the repository root
- each active result chain should eventually document its required upstream inputs in a manifest
