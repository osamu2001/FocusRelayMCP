import ArgumentParser
import Foundation
import OmniFocusAutomation
import OmniFocusCore

struct BenchmarkListProjects: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "benchmark-list-projects",
        abstract: "Benchmark list_projects on the plugin transport.",
        aliases: ["benchmark_list_projects"]
    )

    @Option(name: .customLong("duration-hours"), help: "Measured phase duration in hours.")
    var durationHours: Double = 0.5

    @Option(name: .customLong("warmup-calls"), help: "Warmup calls per transport before measured runs.")
    var warmupCalls: Int = 10

    @Option(name: .customLong("interval-ms"), help: "Minimum start-to-start interval between calls in milliseconds.")
    var intervalMS: Int = 5000

    @Option(name: .customLong("cooldown-ms"), help: "Cooldown delay after failed/timeout calls in milliseconds.")
    var cooldownMS: Int = 5000

    @Option(name: .customLong("output-dir"), help: "Output directory. Defaults to docs/benchmarks/<timestamp>.")
    var outputDir: String?

    func run() async throws {
        guard durationHours > 0 else {
            throw ValidationError("--duration-hours must be > 0.")
        }
        guard warmupCalls >= 0 else {
            throw ValidationError("--warmup-calls must be >= 0.")
        }
        guard intervalMS >= 0 else {
            throw ValidationError("--interval-ms must be >= 0.")
        }
        guard cooldownMS >= 0 else {
            throw ValidationError("--cooldown-ms must be >= 0.")
        }

        let scenarios = listProjectBenchmarkScenarios()
        let outputURL = try benchmarkOutputDirectory(defaultPrefix: "list-projects", customPath: outputDir)
        let rawURL = outputURL.appendingPathComponent("raw.jsonl")
        let summaryURL = outputURL.appendingPathComponent("summary.md")
        benchmarkInitializeFiles(rawURL)

        print("Benchmark output directory: \(outputURL.path)")
        print("Scenarios: \(scenarios.map(\.name).joined(separator: ", "))")

        let service = OmniFocusBridgeService(cacheTTL: 0)
        var callIndex = 0
        var stats: [String: BenchmarkStatsAccumulator] = [:]

        if warmupCalls > 0 {
            for _ in 0..<warmupCalls {
                let scenario = scenarios[callIndex % scenarios.count]
                _ = try await listProjectBenchCall(
                    scenario: scenario,
                    phase: "warmup",
                    service: service,
                    intervalMS: intervalMS,
                    cooldownMS: cooldownMS,
                    callIndex: &callIndex,
                    rawURL: rawURL
                )
            }
        }

        let startedAt = Date()
        let deadline = startedAt.addingTimeInterval(durationHours * 3600)
        print("Measured phase started at \(benchmarkISO8601(startedAt)); ending at \(benchmarkISO8601(deadline))")

        while Date() < deadline {
            let scenario = scenarios[callIndex % scenarios.count]
            let event = try await listProjectBenchCall(
                scenario: scenario,
                phase: "measured",
                service: service,
                intervalMS: intervalMS,
                cooldownMS: cooldownMS,
                callIndex: &callIndex,
                rawURL: rawURL
            )
            var bucket = stats[event.scenario] ?? BenchmarkStatsAccumulator()
            bucket.ingest(ok: event.ok, timeout: event.timeout, latencyMs: event.latencyMs)
            stats[event.scenario] = bucket
        }

        let summary = renderListProjectSummary(
            startedAt: startedAt,
            endedAt: Date(),
            scenarios: scenarios,
            stats: stats
        )
        try summary.write(to: summaryURL, atomically: true, encoding: .utf8)

        print("Benchmark complete.")
        print("Raw data: \(rawURL.path)")
        print("Summary: \(summaryURL.path)")
    }
}

private struct ListProjectBenchmarkScenario {
    let name: String
    let statusFilter: String?
    let includeTaskCounts: Bool
    let fields: [String]
}

private struct ListProjectBenchEvent: Codable {
    let timestamp: String
    let phase: String
    let callIndex: Int
    let scenario: String
    let latencyMs: Double
    let ok: Bool
    let timeout: Bool
    let error: String?
    let returnedCount: Int?
    let totalCount: Int?
    let nextCursor: String?
    let firstItemID: String?
    let lastItemID: String?
}

private func listProjectBenchmarkScenarios() -> [ListProjectBenchmarkScenario] {
    [
        ListProjectBenchmarkScenario(
            name: "active_minimal",
            statusFilter: "active",
            includeTaskCounts: false,
            fields: ["id", "name"]
        ),
        ListProjectBenchmarkScenario(
            name: "active_counts",
            statusFilter: "active",
            includeTaskCounts: true,
            fields: ["id", "name"]
        ),
        ListProjectBenchmarkScenario(
            name: "active_counts_stalled",
            statusFilter: "active",
            includeTaskCounts: true,
            fields: ["id", "name", "hasChildren", "nextTask", "containsSingletonActions", "isStalled"]
        )
    ]
}

private func listProjectBenchCall(
    scenario: ListProjectBenchmarkScenario,
    phase: String,
    service: OmniFocusBridgeService,
    intervalMS: Int,
    cooldownMS: Int,
    callIndex: inout Int,
    rawURL: URL
) async throws -> ListProjectBenchEvent {
    callIndex += 1
    let started = Date()
    do {
        let page = try await service.listProjects(
            page: PageRequest(limit: 50),
            statusFilter: scenario.statusFilter,
            includeTaskCounts: scenario.includeTaskCounts,
            reviewDueBefore: nil,
            reviewDueAfter: nil,
            reviewPerspective: false,
            completed: nil,
            completedBefore: nil,
            completedAfter: nil,
            fields: scenario.fields
        )
        let elapsed = Date().timeIntervalSince(started) * 1000
        let event = ListProjectBenchEvent(
            timestamp: benchmarkISO8601(),
            phase: phase,
            callIndex: callIndex,
            scenario: scenario.name,
            latencyMs: elapsed,
            ok: true,
            timeout: false,
            error: nil,
            returnedCount: page.returnedCount,
            totalCount: page.totalCount,
            nextCursor: page.nextCursor,
            firstItemID: page.items.first?.id,
            lastItemID: page.items.last?.id
        )
        try benchmarkAppendJSONLine(event, to: rawURL)
        try await benchmarkEnforceInterval(started: started, intervalMS: intervalMS)
        return event
    } catch {
        let elapsed = Date().timeIntervalSince(started) * 1000
        let timeout = benchmarkTimeoutFlag(error)
        let event = ListProjectBenchEvent(
            timestamp: benchmarkISO8601(),
            phase: phase,
            callIndex: callIndex,
            scenario: scenario.name,
            latencyMs: elapsed,
            ok: false,
            timeout: timeout,
            error: error.localizedDescription,
            returnedCount: nil,
            totalCount: nil,
            nextCursor: nil,
            firstItemID: nil,
            lastItemID: nil
        )
        try benchmarkAppendJSONLine(event, to: rawURL)
        try await benchmarkCooldownIfNeeded(timeout: timeout, cooldownMS: cooldownMS)
        try await benchmarkEnforceInterval(started: started, intervalMS: intervalMS)
        return event
    }
}

private func renderListProjectSummary(
    startedAt: Date,
    endedAt: Date,
    scenarios: [ListProjectBenchmarkScenario],
    stats: [String: BenchmarkStatsAccumulator]
) -> String {
    var lines: [String] = []
    lines.append("# list_projects Benchmark Summary")
    lines.append("")
    lines.append("- Started: \(benchmarkISO8601(startedAt))")
    lines.append("- Ended: \(benchmarkISO8601(endedAt))")
    lines.append("- Dispatch transport: \(ProcessInfo.processInfo.environment["FOCUS_RELAY_BRIDGE_DISPATCH_TRANSPORT"] ?? "url")")
    lines.append("")
    for scenario in scenarios {
        lines.append("## \(scenario.name)")
        let bucket = stats[scenario.name] ?? BenchmarkStatsAccumulator()
        let total = bucket.successCount + bucket.errorCount
        lines.append("- total=\(total), success=\(bucket.successCount), errors=\(bucket.errorCount), timeouts=\(bucket.timeoutCount), error_rate=\(benchmarkFormatPercentage(bucket.errorCount, total)), p50_ms=\(benchmarkFormatDouble(benchmarkPercentile(bucket.latencies, p: 0.50))), p95_ms=\(benchmarkFormatDouble(benchmarkPercentile(bucket.latencies, p: 0.95))), p99_ms=\(benchmarkFormatDouble(benchmarkPercentile(bucket.latencies, p: 0.99)))")
        lines.append("")
    }
    return lines.joined(separator: "\n")
}
