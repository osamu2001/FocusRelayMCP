# Realistic Benchmark Profile: 2026-03-16

Branch:
- `exp/master-documented-query-baseline`

## Purpose

The original optimization work intentionally used aggressive stress benchmarks to expose reliability problems early.

That was useful, but it is not the right default profile for ongoing product validation.

This document defines three benchmark profiles:
1. smoke validation
2. realistic single-user validation
3. stress/diagnostic validation

## Recommended Default Profile

Use the **realistic single-user validation** profile for routine regression checks.

Reason:
- FocusRelayMCP is a single-user OmniFocus integration
- normal usage is not a constant 1.5-second hammering loop
- this profile still exercises long-lived automation behavior without over-weighting unrealistic pressure

## Profile 1: Smoke Validation

Use when:
- validating a targeted code change before a longer run
- verifying plugin install + restart + semantic gate before spending more time

Settings:
- total duration: `10 minutes`
- warmup calls per transport: `10`
- interval: `2000ms`
- cooldown after failure: `3000ms`
- memory sampling: `60s`

Recommended command:
```bash
cd /Users/deverman/Documents/Code/swift/FocusRelayMCP-master-baseline
caffeinate -dimsu ./scripts/benchmark-suite.sh \
  --total-hours 0.5 \
  --warmup-calls 10 \
  --interval-ms 2000 \
  --cooldown-ms 3000 \
  --memory-interval-seconds 60 \
  --suite-dir docs/benchmarks/smoke-$(date +%Y%m%d-%H%M%S)
```

## Profile 2: Realistic Single-User Validation

Use when:
- evaluating whether a change is acceptable for likely real usage
- checking regressions before merge
- validating the default production path

Settings:
- total duration: `1.5 hours`
- per tool: `30 minutes`
- warmup calls per transport: `10`
- interval: `5000ms`
- cooldown after failure: `5000ms`
- memory sampling: `60s`

Recommended command:
```bash
cd /Users/deverman/Documents/Code/swift/FocusRelayMCP-master-baseline
caffeinate -dimsu ./scripts/benchmark-suite.sh \
  --total-hours 1.5 \
  --warmup-calls 10 \
  --interval-ms 5000 \
  --cooldown-ms 5000 \
  --memory-interval-seconds 60 \
  --suite-dir docs/benchmarks/realistic-$(date +%Y%m%d-%H%M%S)
```

Interpretation rule:
- use this profile to make product decisions
- do not let the harsher stress profile override this one unless it exposes a deterministic correctness bug

## Profile 3: Stress / Diagnostic Validation

Use when:
- investigating runtime pressure
- debugging timeout patterns
- validating recovery behavior after transport or query-engine changes

Settings:
- total duration: `3 hours`
- warmup calls per transport: `20`
- interval: `1500ms`
- cooldown after failure: `3000ms`
- memory sampling: `30s`

Recommended command:
```bash
cd /Users/deverman/Documents/Code/swift/FocusRelayMCP-master-baseline
caffeinate -dimsu ./scripts/benchmark-suite.sh \
  --total-hours 3 \
  --warmup-calls 20 \
  --interval-ms 1500 \
  --cooldown-ms 3000 \
  --memory-interval-seconds 30 \
  --suite-dir docs/benchmarks/stress-$(date +%Y%m%d-%H%M%S)
```

Interpretation rule:
- use this profile to diagnose tail behavior and queue pressure
- do not treat it as the only benchmark that matters for a single-user product

## Transport A/B Profile

Use when:
- re-evaluating transport only
- query semantics are already frozen
- you are explicitly comparing `plugin-url` and `plugin-jxa-dispatch`

Settings:
- total duration: `3 hours`
- transport driver: `scripts/benchmark-transport-ab.sh`
- same interval and cooldown as the stress profile by default

Recommended command:
```bash
cd /Users/deverman/Documents/Code/swift/FocusRelayMCP-master-baseline
RUN_ROOT="docs/benchmarks/transport-ab-$(date +%Y%m%d-%H%M%S)"
caffeinate -dimsu ./scripts/benchmark-transport-ab.sh \
  --total-hours 3 \
  --warmup-calls 20 \
  --interval-ms 1500 \
  --cooldown-ms 3000 \
  --memory-interval-seconds 30 \
  --run-root "$RUN_ROOT"
```

## Decision Rules

1. Always run semantic gates before benchmark interpretation.
2. Use smoke first after a code change.
3. Use the realistic profile for merge confidence.
4. Use the stress profile only when investigating reliability or runtime-pressure behavior.
5. Do not mix query changes and transport changes in the same benchmark program.

## Current Recommendation

For future work on this branch:
- default benchmark profile: **realistic single-user validation**
- stress profile: **diagnostic only**
- transport A/B: **only for isolated transport experiments**
