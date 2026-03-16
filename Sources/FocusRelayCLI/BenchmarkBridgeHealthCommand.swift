import ArgumentParser
import Foundation
import OmniFocusAutomation

struct BenchmarkBridgeHealth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "benchmark-bridge-health",
        abstract: "Benchmark bridge health checks to baseline IPC overhead.",
        aliases: ["benchmark_bridge_health"]
    )

    @Option(name: .customLong("duration-hours"), help: "Measured phase duration in hours.")
    var durationHours: Double = 0.5

    @Option(name: .customLong("warmup-calls"), help: "Warmup calls before measured runs.")
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
        let outputURL = try benchmarkOutputDirectory(defaultPrefix: "bridge-health", customPath: outputDir)
        let rawURL = outputURL.appendingPathComponent("raw.jsonl")
        let summaryURL = outputURL.appendingPathComponent("summary.md")
        benchmarkInitializeFiles(rawURL)

        print("Benchmark output directory: \(outputURL.path)")

        let service = OmniFocusBridgeService()
        var callIndex = 0
        var stats = BenchmarkStatsAccumulator()
        var bridgeTimings: [Double] = []
        var overheads: [Double] = []

        if warmupCalls > 0 {
            for _ in 0..<warmupCalls {
                _ = try await healthBenchCall(
                    service: service,
                    phase: "warmup",
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
            let event = try await healthBenchCall(
                service: service,
                phase: "measured",
                intervalMS: intervalMS,
                cooldownMS: cooldownMS,
                callIndex: &callIndex,
                rawURL: rawURL
            )
            stats.ingest(ok: event.ok, timeout: event.timeout, latencyMs: event.latencyMs)
            if let timing = event.bridgeTimingMs {
                bridgeTimings.append(Double(timing))
            }
            if let overhead = event.transportOverheadMs {
                overheads.append(overhead)
            }
        }

        let summary = renderBridgeHealthSummary(
            startedAt: startedAt,
            endedAt: Date(),
            stats: stats,
            bridgeTimings: bridgeTimings,
            overheads: overheads
        )
        try summary.write(to: summaryURL, atomically: true, encoding: .utf8)

        print("Benchmark complete.")
        print("Raw data: \(rawURL.path)")
        print("Summary: \(summaryURL.path)")
    }
}

private struct BridgeHealthBenchEvent: Codable {
    let timestamp: String
    let phase: String
    let callIndex: Int
    let latencyMs: Double
    let ok: Bool
    let timeout: Bool
    let error: String?
    let bridgeTimingMs: Int?
    let transportOverheadMs: Double?
}

private func healthBenchCall(
    service: OmniFocusBridgeService,
    phase: String,
    intervalMS: Int,
    cooldownMS: Int,
    callIndex: inout Int,
    rawURL: URL
) async throws -> BridgeHealthBenchEvent {
    callIndex += 1
    let started = Date()
    do {
        let result = try service.healthCheck()
        let elapsed = Date().timeIntervalSince(started) * 1000
        let timing = result.timingMs
        let overhead = timing.map { max(0, elapsed - Double($0)) }
        let event = BridgeHealthBenchEvent(
            timestamp: benchmarkISO8601(),
            phase: phase,
            callIndex: callIndex,
            latencyMs: elapsed,
            ok: result.ok,
            timeout: false,
            error: result.error,
            bridgeTimingMs: timing,
            transportOverheadMs: overhead
        )
        try benchmarkAppendJSONLine(event, to: rawURL)
        try await benchmarkEnforceInterval(started: started, intervalMS: intervalMS)
        return event
    } catch {
        let elapsed = Date().timeIntervalSince(started) * 1000
        let timeout = benchmarkTimeoutFlag(error)
        let event = BridgeHealthBenchEvent(
            timestamp: benchmarkISO8601(),
            phase: phase,
            callIndex: callIndex,
            latencyMs: elapsed,
            ok: false,
            timeout: timeout,
            error: error.localizedDescription,
            bridgeTimingMs: nil,
            transportOverheadMs: nil
        )
        try benchmarkAppendJSONLine(event, to: rawURL)
        try await benchmarkCooldownIfNeeded(timeout: timeout, cooldownMS: cooldownMS)
        try await benchmarkEnforceInterval(started: started, intervalMS: intervalMS)
        return event
    }
}

private func renderBridgeHealthSummary(
    startedAt: Date,
    endedAt: Date,
    stats: BenchmarkStatsAccumulator,
    bridgeTimings: [Double],
    overheads: [Double]
) -> String {
    let total = stats.successCount + stats.errorCount
    var lines: [String] = []
    lines.append("# bridge_health Benchmark Summary")
    lines.append("")
    lines.append("- Started: \(benchmarkISO8601(startedAt))")
    lines.append("- Ended: \(benchmarkISO8601(endedAt))")
    lines.append("- Dispatch transport: \(ProcessInfo.processInfo.environment["FOCUS_RELAY_BRIDGE_DISPATCH_TRANSPORT"] ?? "url")")
    lines.append("- total=\(total), success=\(stats.successCount), errors=\(stats.errorCount), timeouts=\(stats.timeoutCount), error_rate=\(benchmarkFormatPercentage(stats.errorCount, total))")
    lines.append("- latency p50_ms=\(benchmarkFormatDouble(benchmarkPercentile(stats.latencies, p: 0.50))), p95_ms=\(benchmarkFormatDouble(benchmarkPercentile(stats.latencies, p: 0.95))), p99_ms=\(benchmarkFormatDouble(benchmarkPercentile(stats.latencies, p: 0.99)))")
    lines.append("- bridgeTiming p50_ms=\(benchmarkFormatDouble(benchmarkPercentile(bridgeTimings, p: 0.50))), p95_ms=\(benchmarkFormatDouble(benchmarkPercentile(bridgeTimings, p: 0.95)))")
    lines.append("- transportOverhead p50_ms=\(benchmarkFormatDouble(benchmarkPercentile(overheads, p: 0.50))), p95_ms=\(benchmarkFormatDouble(benchmarkPercentile(overheads, p: 0.95)))")
    return lines.joined(separator: "\n")
}
