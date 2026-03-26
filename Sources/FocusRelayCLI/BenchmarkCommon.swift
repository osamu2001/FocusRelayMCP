import ArgumentParser
import Foundation

enum BenchmarkTransport: String, Codable, CaseIterable {
    case plugin
    case jxa
}

struct BenchmarkStatsAccumulator {
    var successCount: Int = 0
    var errorCount: Int = 0
    var timeoutCount: Int = 0
    var latencies: [Double] = []

    mutating func ingest(ok: Bool, timeout: Bool, latencyMs: Double) {
        if ok {
            successCount += 1
            latencies.append(latencyMs)
        } else {
            errorCount += 1
            if timeout {
                timeoutCount += 1
            }
        }
    }
}

func benchmarkOutputDirectory(defaultPrefix: String, customPath: String?) throws -> URL {
    let fm = FileManager.default
    let base: URL
    if let customPath, !customPath.isEmpty {
        base = URL(fileURLWithPath: customPath, isDirectory: true)
    } else {
        let ts = benchmarkTimestampLabel(Date())
        base = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("docs", isDirectory: true)
            .appendingPathComponent("benchmarks", isDirectory: true)
            .appendingPathComponent("\(defaultPrefix)-\(ts)", isDirectory: true)
    }
    try fm.createDirectory(at: base, withIntermediateDirectories: true)
    return base
}

func benchmarkInitializeFiles(_ urls: URL...) throws {
    for url in urls {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 0)
        try handle.close()
    }
}

func benchmarkAppendJSONLine<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    guard var line = String(data: data, encoding: .utf8) else {
        throw ValidationError("Failed to encode benchmark event as UTF-8.")
    }
    line.append("\n")
    try benchmarkAppendLine(line, to: url)
}

func benchmarkAppendLine(_ line: String, to url: URL) throws {
    let data = Data(line.utf8)
    if let handle = try? FileHandle(forWritingTo: url) {
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    } else {
        try data.write(to: url)
    }
}

func benchmarkPercentile(_ values: [Double], p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = min(sorted.count - 1, max(0, Int((Double(sorted.count) - 1) * p)))
    return sorted[index]
}

func benchmarkFormatDouble(_ value: Double) -> String {
    String(format: "%.2f", value)
}

func benchmarkFormatPercentage(_ numerator: Int, _ denominator: Int) -> String {
    guard denominator > 0 else { return "0.00%" }
    return benchmarkFormatDouble((Double(numerator) / Double(denominator)) * 100) + "%"
}

func benchmarkISO8601(_ date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func benchmarkTimestampLabel(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: date)
}

func benchmarkTimeoutFlag(_ error: Error) -> Bool {
    error.localizedDescription.lowercased().contains("timed out")
        || error.localizedDescription.lowercased().contains("timeout")
}

func benchmarkEnforceInterval(started: Date, intervalMS: Int) async throws {
    guard intervalMS > 0 else { return }
    let elapsed = Date().timeIntervalSince(started) * 1000
    if elapsed < Double(intervalMS) {
        let sleepMS = Double(intervalMS) - elapsed
        try await Task.sleep(nanoseconds: UInt64(sleepMS * 1_000_000))
    }
}

func benchmarkCooldownIfNeeded(cooldownMS: Int) async throws {
    guard cooldownMS > 0 else { return }
    try await Task.sleep(nanoseconds: UInt64(cooldownMS) * 1_000_000)
}
