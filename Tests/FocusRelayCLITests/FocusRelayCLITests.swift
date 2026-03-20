import Foundation
import Testing
@testable import FocusRelayCLI
@testable import OmniFocusCore

@Test
func fieldListParsesCommaSeparatedValues() {
    #expect(FieldList.parse(nil).isEmpty)
    #expect(FieldList.parse("").isEmpty)
    #expect(FieldList.parse("id,name, completionDate") == ["id", "name", "completionDate"])
}

@Test
func iso8601DateParserAcceptsValidDates() throws {
    let date = try ISO8601DateParser.parse("2026-02-04T12:00:00Z", argumentName: "--due-before")
    #expect(date.timeIntervalSince1970 > 0)
}

@Test
func iso8601DateParserRejectsInvalidDates() {
    var didThrow = false
    do {
        _ = try ISO8601DateParser.parse("not-a-date", argumentName: "--due-before")
    } catch {
        didThrow = true
    }
    #expect(didThrow)
}

@Test
func listTagsScopeSkipsJXAInboxProbe() {
    #expect(shouldRunJXAProbe(for: .all))
    #expect(!shouldRunJXAProbe(for: .listTags))
    #expect(!shouldRunJXAProbe(for: .listProjects))
}

@Test
func projectRowSignatureIncludesRequestedNameAndCounts() {
    let base = ProjectItem(
        id: "project-1",
        name: "Alpha",
        status: "active",
        flagged: false,
        availableTasks: 1,
        remainingTasks: 2,
        completedTasks: 3,
        droppedTasks: 4,
        totalTasks: 10
    )
    let renamed = ProjectItem(
        id: "project-1",
        name: "Beta",
        status: "active",
        flagged: false,
        availableTasks: 1,
        remainingTasks: 2,
        completedTasks: 3,
        droppedTasks: 4,
        totalTasks: 10
    )
    let recounted = ProjectItem(
        id: "project-1",
        name: "Alpha",
        status: "active",
        flagged: false,
        availableTasks: 9,
        remainingTasks: 2,
        completedTasks: 3,
        droppedTasks: 4,
        totalTasks: 10
    )

    #expect(
        gateProjectRowSignature(base, fields: ["id", "name"], includeTaskCounts: true)
            != gateProjectRowSignature(renamed, fields: ["id", "name"], includeTaskCounts: true)
    )
    #expect(
        gateProjectRowSignature(base, fields: ["id", "name"], includeTaskCounts: true)
            != gateProjectRowSignature(recounted, fields: ["id", "name"], includeTaskCounts: true)
    )
}

@Test
func tagRowSignatureIncludesStatusAndCountsWhenRequested() {
    let base = TagItem(id: "tag-1", name: "Office", status: "active", availableTasks: 1, remainingTasks: 2, totalTasks: 3)
    let statusChanged = TagItem(id: "tag-1", name: "Office", status: "onHold", availableTasks: 1, remainingTasks: 2, totalTasks: 3)
    let countChanged = TagItem(id: "tag-1", name: "Office", status: "active", availableTasks: 9, remainingTasks: 2, totalTasks: 3)

    #expect(gateTagRowSignature(base, includeTaskCounts: false) != gateTagRowSignature(statusChanged, includeTaskCounts: false))
    #expect(gateTagRowSignature(base, includeTaskCounts: true) != gateTagRowSignature(countChanged, includeTaskCounts: true))
}

@Test
func projectBenchmarkSourcesUseChildrenScenario() throws {
    let benchmarkProjects = try String(contentsOfFile: "Sources/FocusRelayCLI/BenchmarkListProjectsCommand.swift", encoding: .utf8)
    let gateCheck = try String(contentsOfFile: "Sources/FocusRelayCLI/BenchmarkGateCheckCommand.swift", encoding: .utf8)

    #expect(benchmarkProjects.contains("active_counts_children"))
    #expect(!benchmarkProjects.contains("active_counts_stalled"))
    #expect(gateCheck.contains("active_counts_children"))
    #expect(!gateCheck.contains("active_counts_stalled"))
}

@Test
func benchmarkInitializeFilesTruncatesExistingContents() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let rawURL = directoryURL.appendingPathComponent("raw.jsonl")
    try "stale-data\n".write(to: rawURL, atomically: true, encoding: .utf8)

    try benchmarkInitializeFiles(rawURL)

    let data = try Data(contentsOf: rawURL)
    #expect(data.isEmpty)
}

@Test
func benchmarkCooldownAppliesWithoutTimeoutFlag() async throws {
    let started = ContinuousClock.now
    try await benchmarkCooldownIfNeeded(cooldownMS: 25)
    let elapsed = started.duration(to: .now)
    #expect(elapsed >= .milliseconds(15))
}

@Test
func bridgeHealthBenchmarkCoolsDownWhenBridgeReportsUnhealthy() throws {
    let source = try String(contentsOfFile: "Sources/FocusRelayCLI/BenchmarkBridgeHealthCommand.swift", encoding: .utf8)
    let projectsSource = try String(contentsOfFile: "Sources/FocusRelayCLI/BenchmarkListProjectsCommand.swift", encoding: .utf8)
    let tagsSource = try String(contentsOfFile: "Sources/FocusRelayCLI/BenchmarkListTagsCommand.swift", encoding: .utf8)

    #expect(source.contains("if !result.ok {"))
    #expect(source.contains("benchmarkCooldownIfNeeded(cooldownMS: cooldownMS)"))
    #expect(projectsSource.contains("benchmarkCooldownIfNeeded(cooldownMS: cooldownMS)"))
    #expect(tagsSource.contains("benchmarkCooldownIfNeeded(cooldownMS: cooldownMS)"))
    #expect(!source.contains("benchmarkCooldownIfNeeded(timeout: timeout, cooldownMS: cooldownMS)"))
}
