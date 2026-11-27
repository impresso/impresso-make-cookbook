# Release Notes: v2.0.0

**Release Date:** 2026-11-13  
**Comparison:** [v1.4.0...v2.0.0](https://github.com/impresso/impresso-make-cookbook/compare/v1.4.0...v2.0.0)

## Overview

Version 2.0.0 adds two new pipelines (media sources and S3 on-demand aggregation),
grows the re-OCR module into a full workflow, and makes collection runs year-aware
and safer to orchestrate. All recipes now share one resolved `PYTHON` interpreter,
help is organised into per-topic pages, and uv can be used to set up the venv.

It is a major release because a few variables were removed and some defaults
changed. Parent repositories should read the migration section before bumping the
submodule.

## Breaking changes and migration

| Change | What to do in a parent repository |
|---|---|
| `NEWSPAPER_LIST_YEAR_ANCHOR` removed | Drop it from configs; use year-aware collection items (`PROVIDER/NEWSPAPER/YEAR`) instead |
| `STAMP_SYNC_PYTHON` removed | Set `PYTHON` instead (only needed to override the auto-detected interpreter) |
| Fallback interpreter is `python3`, not `python3.$(PYTHON_MINOR_VERSION)` | Use a project `.venv`, an activated venv or `PYTHON=...`; check with `make check-python-env` |
| `make collection` runs `COLLECTION_TARGET` (default `newspaper`) per item instead of `all` | Set `COLLECTION_TARGET=all` if you relied on the old behaviour |
| Explicit sync targets always query S3 | Expect a fresh S3 listing on every `make sync-*`; normal processing still uses the stamp files |
| `S3_BUCKET_REBUILT` default is now `122-rebuilt-final`, `S3_BUCKET_LINGPROC` is `142-processed-data-final` | Set the old values explicitly if you depended on them |
| `include cookbook/make_settings.mk` is required before setup/processing fragments | Follow the include order in `AGENTS.md` |
| `AGENT.md` renamed to `AGENTS.md` | Update links |

After bumping, activate the new commit guard in the cookbook checkout:
`git -C cookbook config core.hooksPath .githooks`.

## What's new

### Pipelines
- **Media sources:** full paths/sync/setup/processing/aggregation family with
  year filtering, sampling, dtype and anachronism filtering options.
- **S3 on-demand aggregation:** configurable inputs, per-newspaper aggregation
  and a monolithic `aggregate-all` target.
- **Re-OCR:** PERO engine and segmentation options, Tesseract/HF font models,
  IIIF tunnel, lexicon setup, sampling, year-package sync, coverage and output
  statistics, and layout/line benchmark targets.
- **Topics and langident:** run-level topic aggregates, image-caption language
  identification, configurable lingproc length limits and chunking.

### Orchestration
- Year-aware collection items, year-scoped stamp sync, and `make -n` propagation
  through collection runs.
- S3 preflight checks and WIP locks in the nel, newsagencies and
  consolidatedcanonical recipes.
- Read-only collection completeness audit (`completeness.mk`).
- `make collection` writes a timestamped log under `$(BUILD_DIR)/logs/`.
- Dry-run S3 delete commands per pipeline and an S3 cross-bucket folder move.

### Setup and help
- One `PYTHON` for all recipes, resolved in `make_settings.mk`; `make check-python-env`.
- Optional uv: `make setup-venv-uv` / `make sync-venv-uv` install `requirements.txt`
  (the `Pipfile` stays the source of truth; `make update-pip-requirements-file`
  regenerates it).
- `help.mk` with `make help-<topic>` pages and copyable command lines.
- Pre-commit hook against commits from a detached `HEAD`.

### Fixes
- Wrong default bucket names for rebuilt and lingproc outputs (see migration).
- `PYTHON` was passed unexpanded to the shell in some sync recipes.
- Newspaper year file filtering, dry-run detection and CFG file validation.

## Dependencies

`requirements.txt` was regenerated: notably `smart-open` 7 → 9, `urllib3` 2.8,
`jq` 1.13. The `Pipfile` allows pre-releases, so `wrapt` resolves to a dev release.

See `CHANGELOG.md` for the complete list of changes.
