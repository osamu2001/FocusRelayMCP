import ArgumentParser
import Foundation
import OmniFocusAutomation
import OmniFocusCore

struct BenchmarkListTasks: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "benchmark-list-tasks",
        abstract: "Benchmark list_tasks for plugin vs JXA transports.",
        aliases: ["benchmark_list_tasks"]
    )

    @Option(name: .customLong("duration-hours"), help: "Measured phase duration in hours.")
    var durationHours: Double = 3.0

    @Option(name: .customLong("warmup-calls"), help: "Warmup calls per transport before measured runs.")
    var warmupCalls: Int = 20

    @Option(name: .customLong("interval-ms"), help: "Minimum start-to-start interval between calls in milliseconds.")
    var intervalMS: Int = 1500

    @Option(name: .customLong("cooldown-ms"), help: "Cooldown delay after failed/timeout calls in milliseconds.")
    var cooldownMS: Int = 3000

    @Option(name: .customLong("completed-after"), help: "Fixed ISO8601 anchor for completed-date scenario.")
    var completedAfter: String = "2020-01-01T00:00:00Z"

    @Option(name: .customLong("output-dir"), help: "Output directory. Defaults to docs/benchmarks/<timestamp>.")
    var outputDir: String?

    func run() async throws {
        let completedAfterDate = try ISO8601DateParser.parse(completedAfter, argumentName: "--completed-after")
        let scenarios = listTaskScenarios(completedAfter: completedAfterDate)
        let outputURL = try listTaskBenchmarkOutputDirectory(customPath: outputDir)
        let rawURL = outputURL.appendingPathComponent("raw.jsonl")
        let summaryURL = outputURL.appendingPathComponent("summary.md")
        FileManager.default.createFile(atPath: rawURL.path, contents: nil)

        print("Benchmark output directory: \(outputURL.path)")
        print("Scenarios: \(scenarios.map(\.name).joined(separator: ", "))")

        let pluginService = OmniFocusBridgeService()
        let jxaService = OmniAutomationService()

        var callIndex = 0
        var stats: [String: [String: ListTaskStats]] = [:]
        var mismatches = 0

        if warmupCalls > 0 {
            for _ in 0..<warmupCalls {
                let scenario = scenarios[callIndex % scenarios.count]
                _ = try await listTaskBenchCall(
                    transport: "plugin",
                    scenario: scenario,
                    phase: "warmup",
                    service: pluginService,
                    intervalMS: intervalMS,
                    cooldownMS: cooldownMS,
                    callIndex: &callIndex,
                    rawURL: rawURL
                )
            }
            for _ in 0..<warmupCalls {
                let scenario = scenarios[callIndex % scenarios.count]
                _ = try await listTaskBenchCall(
                    transport: "jxa",
                    scenario: scenario,
                    phase: "warmup",
                    service: jxaService,
                    intervalMS: intervalMS,
                    cooldownMS: cooldownMS,
                    callIndex: &callIndex,
                    rawURL: rawURL
                )
            }
        }

        let start = Date()
        let end = start.addingTimeInterval(durationHours * 3600)
        print("Measured phase started at \(listTaskISO8601(start)); ending at \(listTaskISO8601(end))")

        while Date() < end {
            let scenario = scenarios[callIndex % scenarios.count]

            let pluginEvent = try await listTaskBenchCall(
                transport: "plugin",
                scenario: scenario,
                phase: "measured",
                service: pluginService,
                intervalMS: intervalMS,
                cooldownMS: cooldownMS,
                callIndex: &callIndex,
                rawURL: rawURL
            )
            ingestListTaskEvent(pluginEvent, into: &stats)
            if pluginEvent.timeout {
                await runListTaskTimeoutRecoveryGate()
            }

            let jxaEvent = try await listTaskBenchCall(
                transport: "jxa",
                scenario: scenario,
                phase: "measured",
                service: jxaService,
                intervalMS: intervalMS,
                cooldownMS: cooldownMS,
                callIndex: &callIndex,
                rawURL: rawURL
            )
            ingestListTaskEvent(jxaEvent, into: &stats)
            if jxaEvent.timeout {
                await runListTaskTimeoutRecoveryGate()
            }

            if pluginEvent.ok && jxaEvent.ok && pluginEvent.totalCount != jxaEvent.totalCount {
                mismatches += 1
            }
        }

        let summary = renderListTaskSummary(
            startedAt: start,
            endedAt: Date(),
            scenarios: scenarios.map(\.name),
            stats: stats,
            mismatches: mismatches
        )
        try summary.write(to: summaryURL, atomically: true, encoding: .utf8)

        print("Benchmark complete.")
        print("Raw data: \(rawURL.path)")
        print("Summary: \(summaryURL.path)")
    }
}

private struct ListTaskScenario {
    let name: String
    let filter: TaskFilter
}

private struct ListTaskEvent: Codable {
    let timestamp: String
    let phase: String
    let callIndex: Int
    let transport: String
    let scenario: String
    let latencyMs: Double
    let ok: Bool
    let timeout: Bool
    let error: String?
    let returnedCount: Int?
    let totalCount: Int?
}

private struct ListTaskStats {
    var success: Int = 0
    var errors: Int = 0
    var timeouts: Int = 0
    var latencies: [Double] = []

    mutating func ingest(_ event: ListTaskEvent) {
        if event.ok {
            success += 1
            latencies.append(event.latencyMs)
        } else {
            errors += 1
            if event.timeout { timeouts += 1 }
        }
    }
}

private func listTaskScenarios(completedAfter: Date) -> [ListTaskScenario] {
    [
        ListTaskScenario(name: "default", filter: TaskFilter(includeTotalCount: true)),
        ListTaskScenario(name: "inbox_only", filter: TaskFilter(inboxOnly: true, includeTotalCount: true)),
        ListTaskScenario(name: "available_only", filter: TaskFilter(availableOnly: true, includeTotalCount: true)),
        ListTaskScenario(name: "completed_after_anchor", filter: TaskFilter(completed: true, completedAfter: completedAfter, includeTotalCount: true)),
        ListTaskScenario(name: "flagged_only", filter: TaskFilter(flagged: true, includeTotalCount: true))
    ]
}

private func listTaskBenchCall(
    transport: String,
    scenario: ListTaskScenario,
    phase: String,
    service: any OmniFocusService,
    intervalMS: Int,
    cooldownMS: Int,
    callIndex: inout Int,
    rawURL: URL
) async throws -> ListTaskEvent {
    callIndex += 1
    let started = Date()
    do {
        let page = try await service.listTasks(
            filter: scenario.filter,
            page: PageRequest(limit: 50),
            fields: ["id", "name", "completed", "available", "completionDate"]
        )
        let elapsed = Date().timeIntervalSince(started) * 1000
        try await listTaskEnforceInterval(started: started, intervalMS: intervalMS)
        let event = ListTaskEvent(
            timestamp: listTaskISO8601Now(),
            phase: phase,
            callIndex: callIndex,
            transport: transport,
            scenario: scenario.name,
            latencyMs: elapsed,
            ok: true,
            timeout: false,
            error: nil,
            returnedCount: page.returnedCount,
            totalCount: page.totalCount
        )
        try listTaskAppendJSONLine(event, to: rawURL)
        return event
    } catch {
        let elapsed = Date().timeIntervalSince(started) * 1000
        let timeout = listTaskIsTimeout(error)
        try await listTaskEnforceInterval(started: started, intervalMS: intervalMS)
        if cooldownMS > 0 {
            try? await Task.sleep(nanoseconds: UInt64(cooldownMS) * 1_000_000)
        }
        let event = ListTaskEvent(
            timestamp: listTaskISO8601Now(),
            phase: phase,
            callIndex: callIndex,
            transport: transport,
            scenario: scenario.name,
            latencyMs: elapsed,
            ok: false,
            timeout: timeout,
            error: error.localizedDescription,
            returnedCount: nil,
            totalCount: nil
        )
        try listTaskAppendJSONLine(event, to: rawURL)
        return event
    }
}

private func runListTaskTimeoutRecoveryGate() async {
    let env = ProcessInfo.processInfo.environment
    let recoveryMs = max(0, env["FOCUS_RELAY_TIMEOUT_RECOVERY_MS"].flatMap(Int.init) ?? 10_000)
    if recoveryMs > 0 {
        try? await Task.sleep(nanoseconds: UInt64(recoveryMs) * 1_000_000)
    }
    // Lightweight readiness probe before resuming to reduce timeout cascades.
    _ = try? OmniFocusBridgeService().healthCheck()
}

private func ingestListTaskEvent(_ event: ListTaskEvent, into stats: inout [String: [String: ListTaskStats]]) {
    guard event.phase == "measured" else { return }
    var perScenario = stats[event.scenario] ?? [:]
    var perTransport = perScenario[event.transport] ?? ListTaskStats()
    perTransport.ingest(event)
    perScenario[event.transport] = perTransport
    stats[event.scenario] = perScenario
}

private func renderListTaskSummary(
    startedAt: Date,
    endedAt: Date,
    scenarios: [String],
    stats: [String: [String: ListTaskStats]],
    mismatches: Int
) -> String {
    func p(_ values: [Double], _ q: Double) -> String {
        guard !values.isEmpty else { return "n/a" }
        let sorted = values.sorted()
        let idx = Int(Double(sorted.count - 1) * q)
        return String(format: "%.2f", sorted[idx])
    }

    var lines: [String] = []
    lines.append("# list_tasks Benchmark Summary")
    lines.append("")
    lines.append("- Started: \(listTaskISO8601(startedAt))")
    lines.append("- Ended: \(listTaskISO8601(endedAt))")
    lines.append("- Scenarios: \(scenarios.joined(separator: ", "))")
    lines.append("")
    lines.append("## Scenario Stats")
    lines.append("")
    for scenario in scenarios {
        lines.append("### \(scenario)")
        let scoped = stats[scenario] ?? [:]
        for transport in ["plugin", "jxa"] {
            let s = scoped[transport] ?? ListTaskStats()
            let total = s.success + s.errors
            let errorRate = total > 0 ? (Double(s.errors) / Double(total)) * 100.0 : .nan
            let timeoutRate = total > 0 ? (Double(s.timeouts) / Double(total)) * 100.0 : .nan
            let er = errorRate.isFinite ? String(format: "%.2f%%", errorRate) : "n/a"
            let tr = timeoutRate.isFinite ? String(format: "%.2f%%", timeoutRate) : "n/a"
            lines.append("- \(transport): total=\(total), success=\(s.success), errors=\(s.errors), error_rate=\(er), timeouts=\(s.timeouts), timeout_rate=\(tr), p50_ms=\(p(s.latencies, 0.5)), p95_ms=\(p(s.latencies, 0.95)), p99_ms=\(p(s.latencies, 0.99))")
        }
        lines.append("")
    }

    lines.append("## Parity")
    lines.append("")
    lines.append("- Mismatch count: \(mismatches)")
    return lines.joined(separator: "\n")
}

private func listTaskBenchmarkOutputDirectory(customPath: String?) throws -> URL {
    if let customPath, !customPath.isEmpty {
        let url = URL(fileURLWithPath: customPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let timestamp = formatter.string(from: Date())
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("docs", isDirectory: true)
        .appendingPathComponent("benchmarks", isDirectory: true)
        .appendingPathComponent("list-tasks-\(timestamp)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func listTaskAppendJSONLine<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    guard var line = String(data: data, encoding: .utf8) else { return }
    line.append("\n")
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(line.utf8))
}

private func listTaskIsTimeout(_ error: Error) -> Bool {
    let message = error.localizedDescription.lowercased()
    return message.contains("timed out") || message.contains("timeout")
}

private func listTaskEnforceInterval(started: Date, intervalMS: Int) async throws {
    guard intervalMS > 0 else { return }
    let elapsed = Date().timeIntervalSince(started)
    let target = Double(intervalMS) / 1000.0
    if elapsed < target {
        try await Task.sleep(nanoseconds: UInt64((target - elapsed) * 1_000_000_000))
    }
}

private func listTaskISO8601Now() -> String {
    listTaskISO8601(Date())
}

private func listTaskISO8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}
