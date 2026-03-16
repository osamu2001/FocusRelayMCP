# Performance Progress: 2026-03-17 Catalog and IPC Baselines

Branch:
- \`fix/catalog-cache-key-correctness\`

## Scope

This follow-up adds baseline coverage for:
- \`list_projects\`
- \`list_tags\`
- bridge IPC overhead

The goal is not to optimize these paths yet. The goal is to leave representative before values for the next tickets:
- \`focusrelay-b4l.3\`
- \`focusrelay-b4l.4\`
- \`focusrelay-b4l.5\`
- \`focusrelay-b4l.6\`

## What Changed

Files:
- \`Sources/FocusRelayCLI/BenchmarkCommon.swift\`
- \`Sources/FocusRelayCLI/BenchmarkListProjectsCommand.swift\`
- \`Sources/FocusRelayCLI/BenchmarkListTagsCommand.swift\`
- \`Sources/FocusRelayCLI/BenchmarkBridgeHealthCommand.swift\`
- \`Sources/FocusRelayCLI/BenchmarkGateCheckCommand.swift\`

Summary:
- added explicit catalog baseline commands
- added a bridge-health benchmark to track IPC overhead separately from query cost
- added list-projects and list-tags benchmark gate scopes
- benchmarked catalog paths with \`cacheTTL=0\` so the numbers reflect the underlying query path rather than the catalog cache

## Validation

Commands:
- \`swift test\`
- \`swift run focusrelay benchmark-gate-check --tool list-projects\`
- \`swift run focusrelay benchmark-gate-check --tool list-tags\`

Result:
- all passed

## Representative Smoke Baselines

Artifacts:
- \`docs/benchmarks/list-projects-20260316-154301/summary.md\`
- \`docs/benchmarks/list-tags-20260316-154311/summary.md\`
- \`docs/benchmarks/bridge-health-20260316-154321/summary.md\`

### \`list_projects\`

- \`active_minimal\`
  - p50 \`454.29ms\`
- \`active_counts\`
  - p50 \`2194.90ms\`
- \`active_counts_stalled\`
  - p50 \`2259.72ms\`

Interpretation:
- the task-count path dominates \`list_projects\`
- the extra stalled-project fields are slightly more expensive than counts alone
- this is a good before baseline for flattening repeated \`flattenedTasks\` access

### \`list_tags\`

- \`active_no_counts\`
  - p50 \`2541.06ms\`
  - p95 \`2654.03ms\`
- \`active_with_counts\`
  - p50 \`2863.56ms\`

Interpretation:
- even the nominal no-count scenario is expensive on the current plugin path
- this is the right baseline for the \`includeTaskCounts=false\` cleanup follow-up

### bridge IPC overhead

- total calls: \`10\`
- latency p50 \`170.39ms\`
- latency p95 \`2701.02ms\`
- bridge timing p50 \`15ms\`
- transport overhead p50 \`155.39ms\`
- transport overhead p95 \`2683.02ms\`

Interpretation:
- the plugin itself is usually fast on \`ping\`
- most of the observed wall-clock cost is outside the plugin timing and belongs to dispatch / wait / file-poll overhead
- this is the before baseline for cleanup and polling follow-up work

## Current Recommendation

1. Treat these as plugin-path baselines, not transport A/B evidence.
2. Use the same commands again after \`.3\`, \`.4\`, \`.5\`, or \`.6\`.
3. Keep the default three-tool suite unchanged; catalog and IPC follow-up runs should stay explicit.
