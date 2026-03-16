# Final Optimization Summary: 2026-03-16

Branch:
- `exp/master-documented-query-baseline`

Associated issue:
- `#19` `Performance: Add decision-safe fast paths for list_tasks (plugin + JXA, separate architectures)`

## Final Decision

1. Keep `plugin-url` as the default production architecture.
2. Do not switch the product to pure JXA.
3. Do not switch the product to `plugin-jxa-dispatch`.
4. Treat pure JXA as a parity and benchmark reference path, not the main architecture.

## Why

The clean-branch work answered the architecture question well enough:
- `plugin-url` remained the best overall production choice after a corrected transport A/B.
- `plugin-jxa-dispatch` did not improve the system enough to justify a switch.
- pure JXA simplified the shape of the system on paper, but did not outperform the plugin path on the highest-value tools.

Primary supporting document:
- `docs/transport-decision-2026-03-13.md`

Primary transport A/B artifact:
- `docs/benchmarks/transport-ab-safe-20260312-210547/`

## What Was Completed

### 1. Documented-only query discipline

Completed:
- added `docs/omni-automation-contract.md`
- updated `agents.md` to require documented Omni Automation APIs in query engines
- removed reliance on undocumented Omni Automation collections from the clean-branch optimization approach

Outcome:
- the branch now has a defensible rule for future query work
- the previous mistake of optimizing against undocumented APIs should not be repeated

### 2. Benchmark process hardening

Completed:
- added explicit benchmark gate checks
- added per-tool benchmark commands for:
  - `get_task_counts`
  - `list_tasks`
  - `get_project_counts`
- added suite scripts and a transport A/B driver
- separated restart, readiness, semantic gate, and measured benchmark steps
- added timeout diagnostics for the tools that needed reliability investigation

Outcome:
- benchmark results on the clean branch are materially more trustworthy than the older mixed-experiment runs

### 3. `get_task_counts`

Completed:
- documented-only implementation discipline on the clean branch
- single-pass count path improvements
- targeted fast paths for the validated benchmark scenarios
- timeout diagnostics

Outcome:
- reliability became acceptable in the clean validation runs
- plugin latency improved materially vs the clean baseline
- no further `get_task_counts` optimization is justified right now

Representative artifact:
- `docs/benchmarks/task-counts-1h-post-fast-path-20260314-114300/summary.md`

### 4. `list_tasks`

Completed:
- timeout recovery hardening on `plugin-url`
- no-`totalCount` streaming path
- counted streaming path for simple `includeTotalCount=true` scenarios
- completion-sorted top-K path for completed-task queries
- extended benchmark coverage for no-`totalCount` scenarios

Outcome:
- the clean branch removed the earlier plugin timeout pattern from the validated 1-hour run
- no-`totalCount` scenarios are materially faster and are now benchmarked directly
- completion-sorted queries improved without breaking parity
- the branch is now at the point of diminishing returns for `list_tasks`

Representative artifacts:
- `docs/benchmarks/list-tasks-1h-post-hardening-20260313-145309/summary.md`
- `docs/benchmarks/list-tasks-1h-post-stream-fast-path-20260314-2313/summary.md`
- `docs/benchmarks/list-tasks-1h-post-completion-topk-20260315-1238/summary.md`

### 5. `get_project_counts`

Completed:
- correctness alignment with the `list_tasks` contract
- diagnostics for long-run timeout investigation
- validated 3-hour soak on the clean branch

Outcome:
- semantics are stable
- reliability became acceptable in the clean 3-hour soak
- no further `get_project_counts` optimization is justified right now

Representative artifact:
- `docs/benchmarks/project-counts-soak-diag-20260309-132541/summary.md`

## What Was Rejected

### 1. Pure JXA as the production architecture

Rejected because:
- it did not justify replacing the plugin query engine on the high-value read path
- it does not clearly outperform `plugin-url` in the final clean evidence
- it moves complexity rather than eliminating it

### 2. `plugin-jxa-dispatch` as the default transport

Rejected because:
- the corrected A/B did not show an overall system win
- it did not solve `list_tasks`
- it regressed `get_project_counts` reliability badly in the corrected transport A/B

### 3. Request-scoped availability memoization in `list_tasks`

Rejected because:
- it regressed the 1-hour validation run
- it introduced plugin timeouts without a defensible latency win

Supporting artifact:
- `docs/benchmarks/list-tasks-1h-post-availability-memo-20260315-2337/summary.md`

Supporting note:
- `docs/performance-progress-2026-03-15.md`

## What Is Not Worth Optimizing Further Right Now

1. `list_projects`
2. `list_tags`
3. transport replacement
4. additional speculative JS micro-optimizations in `list_tasks`

Reason:
- the remaining tail cost increasingly reflects OmniFocus runtime pressure and collection access cost under sustained automation load, not clearly bad query code
- further work here should be treated as a separate phase, not part of this optimization closeout

## Practical Interpretation

The stress benchmarks are harsher than normal single-user MCP usage.

That matters because:
- the validated clean-branch results are already good enough to justify stopping this optimization phase
- the remaining worst-case latency tails are not strong evidence that the architecture is wrong
- they are increasingly evidence that OmniFocus automation itself degrades under sustained pressure

## Final Recommendation

1. Merge the clean-branch optimization work.
2. Keep `plugin-url` as the default architecture.
3. Treat this optimization effort as complete.
4. If future work is needed, open a new phase for either:
   - realistic benchmark refinement
   - cache strategy
   - runtime-pressure recovery policy

## Related Documents

- `docs/PLAN to improve reliability and performance.md`
- `docs/transport-decision-2026-03-13.md`
- `docs/performance-progress-2026-03-14.md`
- `docs/performance-progress-2026-03-15.md`
- `docs/realistic-benchmark-profile-2026-03-16.md`
