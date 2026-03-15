# Performance Progress: 2026-03-15

Branch:
- `exp/master-documented-query-baseline`

## Scope

This update continues the clean-branch `list_tasks` work after:
- transport choice was settled in favor of `plugin-url`
- reliability hardening removed the old timeout pattern
- initial streaming work proved that no-total-count workloads could avoid unnecessary full materialization

## What Changed

### 1. Extended `list_tasks` benchmark coverage

Files:
- `Sources/FocusRelayCLI/BenchmarkListTasksCommand.swift`
- `Sources/FocusRelayCLI/BenchmarkGateCheckCommand.swift`
- `Tests/OmniFocusIntegrationTests/OmniFocusIntegrationTests.swift`

Changes:
- Added explicit no-total-count scenarios to the benchmark:
  - `default_no_total`
  - `inbox_only_no_total`
  - `available_only_no_total`
  - `flagged_only_no_total`
- Extended mismatch detection so parity is checked on:
  - `returnedCount`
  - `totalCount`
  - `nextCursor`
  - first item ID
  - last item ID
- Extended the semantic gate with no-total-count `list_tasks` checks.
- Extended the live bridge-vs-JXA parity test with no-total-count scenarios.

Result:
- The benchmark now measures the path we actually optimized, rather than only the `includeTotalCount=true` path.

### 2. Continued `list_tasks` optimization on `plugin-url`

File:
- `Plugin/FocusRelayBridge.omnijs/Resources/BridgeLibrary.js`

Change:
- Added a counted streaming fast path for simple `includeTotalCount=true` queries when completion sorting is not required.
- This means simple workloads can now:
  - count matches
  - collect the requested page
  - avoid building a full filtered array of matching tasks

The path is currently intended for documented-safe simple scenarios only:
- default available view
- inbox-only available view
- available-only
- flagged-only

It is intentionally not used for completion-sorted scenarios.

## Validation

### Semantic gate

Artifact:
- `swift run focusrelay benchmark-gate-check --tool list-tasks`

Result:
- passed, including the new no-total-count scenarios

Key checks that now pass:
- `list_tasks_parity_default_no_total`
- `list_tasks_parity_inbox_only_no_total`
- `list_tasks_parity_available_only_no_total`
- `list_tasks_parity_flagged_only_no_total`

### Extended smoke benchmark

Artifact:
- `docs/benchmarks/list-tasks-smoke-post-counted-stream-20260315-1218/summary.md`

Result:
- plugin: `0` errors, `0` timeouts
- jxa: `0` errors, `0` timeouts
- parity mismatches: `0`

### New no-total-count measurements

Smoke result highlights:
- `default`
  - plugin p50 `2004.91ms`
- `default_no_total`
  - plugin p50 `1613.52ms`
- `available_only`
  - plugin p50 `1950.44ms`
- `available_only_no_total`
  - plugin p50 `1614.77ms`
- `inbox_only`
  - plugin p50 `223.12ms`
- `inbox_only_no_total`
  - plugin p50 `221.81ms`

Interpretation:
- The no-total-count path is now benchmarked directly.
- For the common simple non-inbox workloads, dropping `totalCount` saves roughly `300-400ms` in the smoke run.
- The plugin path now beats JXA on the no-total-count `default` and `available_only` scenarios in this benchmark.

### Direct command timing retained as supporting evidence

Earlier direct timing, still consistent with the benchmark trend:
- `.build/debug/focusrelay list-tasks --available-only true --fields id,name --limit 50`
  - `real 5.97`
- `.build/debug/focusrelay list-tasks --available-only true --include-total-count --fields id,name --limit 50`
  - `real 8.48`

This remains useful as a spot check showing that early stop is a real wall-clock win.

## What Was Actually Optimized

Two distinct paths are now separated clearly:

1. **No-total-count simple path**
- Early stop after collecting enough rows for the page.
- This is where the biggest direct savings appear.

2. **Total-count simple path**
- Still scans all matching tasks to compute `totalCount`.
- But it no longer builds a full filtered task array before paging when completion sorting is not required.
- This is a lower-risk, lower-gain optimization, but it reduces allocation pressure and keeps semantics intact.

## Next Optimization Target

The next `list_tasks` work should focus on:
- `completed_after_anchor`
- any other completion-sorted workloads

Reason:
- simple available/default/flagged/inbox queries now have targeted fast paths
- completion-sorted queries still fall back to full scan + full sort
- that is now the clearest remaining high-cost path inside `list_tasks`

The next optimization should be careful:
- preserve exact completion-date ordering
- preserve cursor semantics
- preserve total-count semantics
- avoid introducing undocumented Omni Automation usage

## Current Recommendation

- Keep `plugin-url` as the production default.
- Keep optimizing `list_tasks` on the plugin path.
- Use the extended benchmark for future `list_tasks` changes so no-total-count performance is measured directly rather than inferred.
