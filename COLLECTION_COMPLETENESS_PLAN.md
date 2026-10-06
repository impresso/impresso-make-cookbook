# Implementation Plan: Shared Collection Completeness Audits

## Implementation Status

Phase 1 is implemented in `lib/check_collection_completeness.py` with focused
mocked-S3 tests in `tests/test_collection_completeness.py`. The CLI requires an
explicit `--langident-root` when checking issues and accepts
`--canonical-input-kind` to match the pipeline's configured stream selection.
JSON contains detailed artifact observations and repair candidates; the runnable
rerun list remains empty until the Phase 3 repair adapter is available.
Phase 2 is implemented in `completeness.mk` and the parent Makefile, with
configuration/argument propagation tests. Single-newspaper audits accept
`NEWSPAPER_YEARS` through CLI `--years`; collection lists accept whitespace-separated
entries. Repair (Phase 3) is not implemented.

## Purpose and Scope

A successful `make collection` job does not establish that all expected output
artifacts exist on S3. Missing local input stamps can leave nothing to build,
existing output stamps can conceal missing remote data, and WIP guards can yield
to another worker without producing output. Partial copies can leave issues,
pages, and audios with different coverage. Ordinary recipe failures under `-k`
should still produce a failing job; keep-going is not itself a silent-success
mechanism.

Each processing task needs an explicit definition of completeness. Implement one
shared, read-only audit engine in `cookbook/`, with task-specific profiles that
map eligible inputs to expected output artifacts. Implement consolidated
canonical first, then add profiles after examining each task's processing rules.
Automatic repair is a separate, task-specific capability.

A final-stage audit cannot certify upstream stages. Conversely, a filtered task
must not require output for records it deliberately excludes. Reports identify
the task, run, scope, and checks performed so coverage is not mistaken for
end-to-end pipeline correctness.

## Shared Engine and Task Profiles

### Shared Engine Responsibilities

`cookbook/lib/check_collection_completeness.py` provides:

- Collection-item parsing, scope normalization, and validation.
- Metadata-aware paginated S3 listing through the existing configured S3 client,
  including endpoint and credentials handling. Preserve Key, Size, and
  LastModified; the existing `yield_s3_objects()` yields keys only.
- Bounded concurrent scans, retry handling, and explicit listing errors.
- Expected-versus-observed artifact comparison and consistent status aggregation.
- Read-only WIP observations, deterministic reports, and eligible rerun lists.
- CLI exit semantics and report provenance.

Use a small explicit profile registry/interface initially. Do not build a generic
configuration language or a separate S3 scanner for every task. Concurrency is
configurable; 16 workers is an initial default to benchmark, not a promise that
full page inventories finish in seconds. Bound memory by processing collection
items independently and avoid repeated scans for overlapping year selections.

### Profile Contract

Each profile defines:

1. **Identity and configuration:** task name, run/version, input and output roots,
   provider-path rules, supported scopes, and required settings.
2. **Expected work:** which input artifacts or configured groups imply outputs,
   prerequisites, deliberate exclusions, and filtering rules. Missing required
   upstream data is reported as an upstream blocker, not silently excluded.
3. **Artifact mapping:** required streams and input-to-output key mapping,
   including yearly transformation, direct copy, or aggregation relationships.
4. **Validity rules:** recognized data keys, required non-zero sizes, and any
   additional task-specific artifact checks. Auxiliary objects and directory
   markers must not count as data coverage.
5. **Lock policy:** applicable WIP keys and the configured age threshold.
6. **Repair support:** whether repair is implemented and which existing task
   entrypoints and local dependency markers it uses. Repair is not performed by
   the audit engine.

Select the profile explicitly with `--task` / `COMPLETENESS_TASK`. The parent
pipeline sets its default once; shared path fragments must not compete to select
it based on include order. Unsupported profiles fail clearly.

| Profile                 | Expected completeness                                                                                                                       | Delivery                      |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| `consolidatedcanonical` | Expected yearly issues plus all expected relative page/audio keys in the selected streams                                                   | First implementation          |
| `langident`             | Expected yearly output artifacts for eligible canonical input work units, with prerequisites and exclusions taken from its processing rules | Follow-up profile             |
| `lingproc`              | Expected yearly output artifacts for eligible input work units, with task-specific filters and prerequisites                                | Follow-up profile             |
| Aggregation tasks       | Expected output for each configured aggregation group, with required contributing inputs checked separately                                 | Future task-specific profiles |

These follow-up rows describe intended contracts, not verified implementations.
An optional future multi-task audit can aggregate profile reports while retaining
each task's status. It must not infer upstream completeness from a final output.

## Initial Profile: Consolidated Canonical

### Paths and Scope

Use explicit collection configuration:

- `S3_BUCKET_CANONICAL`
- `S3_BUCKET_CONSOLIDATEDCANONICAL`
- `RUN_VERSION_CONSOLIDATEDCANONICAL`
- `NEWSPAPER_HAS_PROVIDER`
- The pipeline's configured page/audio selection and
  `CONSOLIDATEDCANONICAL_WIP_MAX_AGE`

Construct per-item paths using the canonical path conventions:

- Input: `s3://{canonical-bucket}/{segment}/{stream}/`
- Output: `s3://{consolidated-bucket}/{version}/{segment}/{stream}/`
- Segment: `PROVIDER/NEWSPAPER` or `NEWSPAPER`, according to configuration.
- Issues: `{NEWSPAPER}-{YEAR}-issues.jsonl.bz2`
- Content: `pages/{NEWSPAPER}-{YEAR}/...` and/or
  `audios/{NEWSPAPER}-{YEAR}/...`

Do not append collection items to per-newspaper variables such as
`S3_PATH_CANONICAL_ISSUES`, or treat bucket/path strings without `s3://` as URIs.
Use existing configuration defaults rather than duplicating them in the audit
fragment.

Accept the collection runner's existing forms: `PROVIDER/NEWSPAPER`,
`NEWSPAPER`, and `PROVIDER/NEWSPAPER/YEAR`. Validate forms against provider mode;
do not guess ambiguous segments. Deduplicate overlapping scopes and apply year
filters to both input and output, including locks and anomalies. Reject malformed
entries. A specifically requested year absent upstream is an explicit upstream
blocker. Do not advertise providerless year entries until the collection runner
supports the same syntax.

### Expected Artifacts and Prerequisites

Audit the selected streams independently. The default checks issues plus the
page/audio streams selected by the pipeline. An explicit stream override is
recorded in the report; a pages-only audit makes no claim about issues.

For issues, canonical issue keys define expected yearly artifacts. Also report
whether the current processing rules can build each year: they depend on
canonical record stamps and yearly langident enrichment. Missing prerequisites
must not erase expected canonical issue years or trigger fruitless repair.

For selected copied streams, canonical relative data keys define expected output
keys. A year with 1,000 expected objects and 999 present is incomplete. Extra
output keys are observations and do not compensate for missing expected keys.
Content years without canonical issue data are reported as upstream
inconsistencies when issues are selected. Missing input in an explicitly selected
stream must be distinguished from an inapplicable stream in automatic mode.

Define recognized data-key rules from the existing copy/sync conventions. Exclude
logs, WIP files, and directory markers from artifact coverage. Flag zero-byte
source data as an upstream anomaly; copying it cannot produce a valid non-zero
output.

### Coverage and Classification

For each selected stream, let `E` be expected data keys and `V` be observed output
data keys satisfying the profile's validity rules:

- Covered: `E ∩ V`.
- Missing: expected keys absent from output.
- Invalid: expected keys present but invalid, including zero-byte artifacts.
- Unexpected: recognized output data keys outside `E`.
- Coverage: `100 * len(E ∩ V) / len(E)` when `E` is non-empty; otherwise `null`
  with an explicit empty/inapplicable reason.

Issue-year comparisons use subset coverage, not equality. Unexpected years do
not prevent completeness. Required artifacts with non-zero size establish
artifact coverage only: no JSONL record counts, semantic correctness, or content
integrity are certified. Schema validation is a separate check;
`cli_consolidatedcanonical.py --validate` does not establish OCR semantics or
cross-file record completeness. LastModified is collected for observations and
WIP age; freshness validation is outside the first implementation.

Assign exactly one primary status per normalized audit item, in this order:

1. `AUDIT_ERROR`: inventory or evaluation cannot be completed reliably, including
   permission/network failures and exhausted retries. Never reinterpret failed
   listings as empty inventories.
2. `EMPTY_INPUT`: no expected data artifacts exist in the requested scope. Record
   absent requested years or required streams as upstream blockers.
3. `COMPLETE`: every expected artifact in the selected scope is valid and no
   required upstream inconsistency remains.
4. `MISSING`: expected artifacts exist but none are present in output. Logs,
   locks, markers, and unexpected outputs do not count as present artifacts.
5. `INCOMPLETE`: all other evaluated cases, including partial coverage,
   zero-byte expected artifacts, or upstream inconsistencies with data present.

Keep orthogonal observations for active/stale WIPs, invalid source artifacts,
unexpected outputs, and upstream blockers. These never inflate primary status
counts. An item can have full artifact coverage but still require attention due
to a lock or upstream inconsistency.

### Read-Only Lock Policy

Discover WIP keys through listing metadata and compute age from LastModified
using the configured profile threshold. Age indicates whether the pipeline would
consider a lock stale; it does not prove that a worker is dead. Owner details are
optional and require a read of the WIP object if requested.

Never call `has_active_wip()` from the auditor: it deletes stale locks. Never
modify remote objects during an audit. Exclude scopes with active locks from the
eligible rerun list. A stale lock alone does not require reprocessing already
complete artifacts; report it separately. Lock state can change after an audit,
so repair must still honor the processing task's acquisition checks.

## CLI and Make Integration

Initial CLI shape:

```text
check_collection_completeness.py
    --task consolidatedcanonical
    --canonical-bucket BUCKET
    --consolidated-bucket BUCKET
    --run-version VERSION
    (--newspaper-list FILE | --newspaper NEWSPAPER)
    [--provider PROVIDER]
    --has-provider {0,1}
    [--langident-root s3://BUCKET/PROCESS/RUN]  # Required when checking issues
    [--canonical-input-kind {auto,pages,audios}]
    [--check-streams STREAMS]
    [--wip-max-age HOURS]
    [--concurrency N]
    [--output-dir DIR]
    [--log-level LEVEL]
```

Profile-specific arguments are validated by the selected profile. Add only the
arguments needed by subsequent profiles when they are implemented. `STREAMS`
accepts a validated comma-separated selection or the configured default.

`cookbook/completeness.mk` exposes:

- `COMPLETENESS_TASK`, explicitly defaulted by the parent pipeline.
- `COMPLETENESS_REPORT_DIR`, defaulting to
  `$(BUILD_DIR)/reports/completeness/$(COMPLETENESS_TASK)`.
- `COMPLETENESS_CONCURRENCY` and optional `COMPLETENESS_STREAMS` override.
- `check-collection-completeness` and `check-newspaper-completeness`.
- `help-completeness`, using the existing extensible help conventions.

Recipes use `$(PYTHON)`. Include the fragment once in the actual parent
Makefile after task configuration is available. Updating only
`cookbook/Makefile` does not integrate it into this repository. Advertise only
included targets. Examples for users continue to use `make`.

### Exit Semantics

The Python CLI returns:

- `0`: all requested items are complete, with no active locks or upstream blockers.
- `1`: audit succeeded but work remains or completeness is unverified, including
  incomplete/missing output, empty input, or active locks.
- `2`: audit/configuration/report-writing error; automatic repair must stop.

GNU Make maps ordinary recipe failures to its own failure exit status, so callers
must not interpret a Make exit of `2` as the auditor's `AUDIT_ERROR`. Any future
repair recipe invokes the Python auditor directly in a conditional shell block
and captures its exit code there, accounting for strict shell settings.

## Reports

Write JSON and TSV summaries plus:

- `newspapers_missing.txt`: scopes classified as missing.
- `newspapers_incomplete.txt`: scopes classified as incomplete.
- `newspapers_rerun.txt`: only scopes eligible for the task's supported rerun.
- A detailed artifact report containing affected streams, years, missing/invalid
  keys, and the reason a scope is blocked from repair.

Reports include a schema version, audit identifier, timestamp, task/profile,
resolved buckets/roots and run version, original collection selection, normalized
scope, selected streams, lock threshold, statuses, counts, coverage, and errors.
Keep primary status totals separate from overlapping anomaly totals. Preserve
per-year and per-stream details needed for targeted repair; newspaper-level
counts alone are insufficient.

Publish report files through temporary files and mark the report set complete
only after every file is written successfully. A failed audit must not expose a
stale rerun list as current. Repair validates provenance against its active
configuration and uses the matching report set. Concurrent runs require distinct
report directories. Keep pre-repair and post-repair reports separately.

## Task-Specific Repair: Later Phase

The initial deliverable is read-only auditing and reports. Add
`invalidate-incomplete-stamps` and `rerun-incomplete-collection` only after a
consolidated-canonical repair adapter is tested end to end. Other task profiles
do not gain repair support automatically.

The consolidated-canonical repair sequence must:

1. Run a fresh audit and capture the Python status directly. Stop on audit error.
2. Select affected scopes without active locks or upstream blockers. If none are
   eligible, report the remaining blockers and return non-success; do not invoke
   collection with an empty list.
3. Refresh relevant input sync state through existing helpers when missing or
   stale input stamps prevent target discovery. Synchronize before final output
   invalidation so sync cannot recreate an invalid target marker afterward.
4. Invalidate only exact local targets identified by the report: issue artifact
   placeholders, page stamps, or audio stamps as appropriate. Resolve paths from
   existing task variables and BUILD_DIR. Do not use wildcard deletion, hardcoded
   buckets, or remove unrelated logs. Preserve valid issue targets when only
   copied content is incomplete.
5. For existing invalid issue outputs, pass the public
   `CONSOLIDATEDCANONICAL_FORCE_OVERWRITE_OPTION=--force-overwrite` for the
   affected repair scope. This enables both the WIP preflight bypass of the
   output-exists check and replacement by the uploader. Setting only the internal
   WIP force flag is insufficient. A stale lock alone needs no force flag; normal
   acquisition handles expired locks and still respects active locks.
6. Invoke the existing processing entrypoints with the original configuration and
   precise supported scope. Do not replace stamp-based orchestration with direct
   copies. Avoid concurrent local workers sharing the same invalidated targets.
7. Audit the original requested scope again, even when a processing invocation
   failed where practical, and report remaining gaps. A successful rerun command
   alone never establishes completeness. Empty upstream input must not produce
   the message “Collection is fully complete on S3.”

## Validation Strategy

Use mocked S3 clients or a local mock endpoint; routine tests require no live S3
writes. Cover these behavioral cases:

- Metadata pagination, multiple pages, retries, permission failures, and partial
  listing failure without false completeness.
- Provider and providerless paths, malformed entries, overlapping selections,
  requested years absent upstream, and filtering both inventories by scope.
- 1,000 expected copied objects versus 999 outputs; valid issues with missing
  pages, valid pages with missing issues, and audio-only sources.
- Extra outputs neither hide missing keys nor inflate coverage beyond 100%.
- Pages-only checks, inapplicable versus required missing streams, logs/locks-only
  output, zero-byte source and output artifacts, and missing prerequisites.
- Active/stale lock observations without any S3 mutation; stale locks on complete
  outputs do not force a rerun.
- CLI exit semantics, empty eligible lists, deterministic reports, write failure,
  and rejection of mismatched or stale report provenance.
- Task-profile selection independent of include order, unsupported profiles, and
  parent-Makefile integration with dry-run checks.
- Before enabling repair: actual rebuild after remote deletion with a surviving
  local target; replacement of zero-byte remote issues; input stamp refresh;
  exact page/audio invalidation; preservation of unrelated files; and final audit
  failure when repair leaves gaps.

## Implementation Phases

1. **Shared engine and first profile:** implement the minimal profile interface,
   consolidated-canonical mappings, read-only inventories and comparisons,
   reports, exit semantics, and focused tests.
2. **Read-only Make integration:** add check/help targets to the shared fragment
   and this repository's actual Makefile; verify configuration propagation and
   dry-run behavior; document artifact-coverage limits.
3. **Consolidated-canonical repair:** implement and test its adapter, targeted
   invalidation, overwrite behavior, and post-repair audit before exposing repair
   targets.
4. **Additional task profiles:** inspect langident and lingproc processing rules,
   implement their eligibility and artifact mappings, and test each profile.
   Add aggregation profiles only with explicit group definitions. Keep repair
   disabled for each profile until its own adapter is verified.
5. **Documentation:** update cookbook README and CHANGELOG with supported
   profiles, commands, report meanings, and task-specific repair availability.

Initial user workflow:

```bash
make collection CFG=configs/config_consolidatedcanonical_v2025-11-23_initial.mk
make check-collection-completeness CFG=configs/config_consolidatedcanonical_v2025-11-23_initial.mk
make check-newspaper-completeness PROVIDER=BL NEWSPAPER=WTCH
```

Generated rerun lists identify candidate scope. Until the repair adapter is
implemented, document the task's required preparation rather than promising
that passing a list to `make collection` alone repairs remote gaps.
