import Foundation
import Testing
@testable import OmniFocusAutomation

@Test
func bridgeClientConfigurationDefaults() {
    let configuration = BridgeClientConfiguration.fromEnvironment([:])

    #expect(configuration.responseTimeout == 45.0)
    #expect(configuration.responsePollInterval == 0.05)
    #expect(configuration.dispatchTransport == .urlScheme)
    #expect(configuration.dispatchTimeout == 20.0)
}

@Test
func bridgeClientConfigurationUsesEnvironmentOverrides() {
    let configuration = BridgeClientConfiguration.fromEnvironment([
        "FOCUS_RELAY_BRIDGE_RESPONSE_TIMEOUT_SECONDS": "30",
        "FOCUS_RELAY_BRIDGE_RESPONSE_POLL_MS": "25",
        "FOCUS_RELAY_BRIDGE_DISPATCH_TRANSPORT": "jxa",
        "FOCUS_RELAY_BRIDGE_DISPATCH_TIMEOUT_SECONDS": "18"
    ])

    #expect(configuration.responseTimeout == 30.0)
    #expect(configuration.responsePollInterval == 0.025)
    #expect(configuration.dispatchTransport == .jxaEvaluate)
    #expect(configuration.dispatchTimeout == 18.0)
}

@Test
func bridgeClientConfigurationIgnoresInvalidEnvironmentOverrides() {
    let configuration = BridgeClientConfiguration.fromEnvironment([
        "FOCUS_RELAY_BRIDGE_RESPONSE_TIMEOUT_SECONDS": "0",
        "FOCUS_RELAY_BRIDGE_RESPONSE_POLL_MS": "-1",
        "FOCUS_RELAY_BRIDGE_DISPATCH_TIMEOUT_SECONDS": "0"
    ])

    #expect(configuration.responseTimeout == 45.0)
    #expect(configuration.responsePollInterval == 0.05)
    #expect(configuration.dispatchTransport == .urlScheme)
    #expect(configuration.dispatchTimeout == 20.0)
}

@Test
func strandedRedispatchDelayIsBounded() {
    #expect(strandedRedispatchDelay(timeout: 45.0) == 2.0)
    #expect(abs(strandedRedispatchDelay(timeout: 12.0) - 1.2) < 0.000_001)
    #expect(strandedRedispatchDelay(timeout: 3.0) == 0.5)
}

@Test
func lateStrandedRecoveryGraceIsBounded() {
    #expect(lateStrandedRecoveryGrace(timeout: 45.0) == 9.0)
    #expect(abs(lateStrandedRecoveryGrace(timeout: 12.0) - 3.0) < 0.000_001)
    #expect(lateStrandedRecoveryGrace(timeout: 120.0) == 10.0)
}

@Test
func bridgeDispatchTransportDefaultsToURL() {
    #expect(BridgeDispatchTransport.fromEnvironment([:]) == .urlScheme)
    #expect(BridgeDispatchTransport.fromEnvironment(["FOCUS_RELAY_BRIDGE_DISPATCH_TRANSPORT": "url"]) == .urlScheme)
}

@Test
func bridgeDispatchTransportSupportsJXA() {
    #expect(BridgeDispatchTransport.fromEnvironment(["FOCUS_RELAY_BRIDGE_DISPATCH_TRANSPORT": "jxa"]) == .jxaEvaluate)
    #expect(BridgeDispatchTransport.fromEnvironment(["FOCUS_RELAY_BRIDGE_DISPATCH_TRANSPORT": "JXA"]) == .jxaEvaluate)
}

@Test
func buildBridgeDispatchScriptUsesStableDispatchRequestFile() {
    let script = buildBridgeDispatchScript(basePath: "/tmp/focusrelay")

    #expect(script.contains("/dispatch/request.json"))
    #expect(!script.contains("var requestId = argument;"))
    #expect(script.contains("handleRequest(requestId, basePath)"))
}

@Test
func lateStrandedRecoveryOnlyAppliesToURLTransportWithoutLock() {
    #expect(shouldAttemptLateStrandedRecovery(
        transport: .urlScheme,
        requestExists: true,
        responseExists: false,
        lockExists: false
    ))

    #expect(!shouldAttemptLateStrandedRecovery(
        transport: .urlScheme,
        requestExists: true,
        responseExists: false,
        lockExists: true
    ))

    #expect(!shouldAttemptLateStrandedRecovery(
        transport: .jxaEvaluate,
        requestExists: true,
        responseExists: false,
        lockExists: false
    ))

    #expect(!shouldAttemptLateStrandedRecovery(
        transport: .urlScheme,
        requestExists: false,
        responseExists: false,
        lockExists: false
    ))
}

@Test
func staleCleanupIfNeededRunsImmediatelyThenThrottles() throws {
    let tempRoot = try makeTemporaryIPCBaseURL()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let client = BridgeClient(
        paths: IPCPaths(baseURL: tempRoot),
        fileManager: .default,
        staleInterval: 10,
        configuration: .fromEnvironment([:])
    )

    let start = Date(timeIntervalSince1970: 1_000)
    #expect(client.shouldRunStaleCleanup(now: start))
    #expect(!client.shouldRunStaleCleanup(now: start.addingTimeInterval(5)))
    #expect(client.shouldRunStaleCleanup(now: start.addingTimeInterval(10)))
}

@Test
func cleanupStaleFilesRemovesExpiredIPCArtifacts() throws {
    let tempRoot = try makeTemporaryIPCBaseURL()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let paths = IPCPaths(baseURL: tempRoot)
    let fileManager = FileManager.default
    try [paths.requestsURL, paths.responsesURL, paths.locksURL].forEach {
        try fileManager.createDirectory(at: $0, withIntermediateDirectories: true)
    }

    let now = Date(timeIntervalSince1970: 10_000)
    let staleDate = now.addingTimeInterval(-700)
    let staleRequest = try makeIPCArtifact(at: paths.requestsURL, named: "old-request.json", modifiedAt: staleDate)
    let staleResponse = try makeIPCArtifact(at: paths.responsesURL, named: "old-response.json", modifiedAt: staleDate)
    let staleLock = try makeIPCArtifact(at: paths.locksURL, named: "old.lock", modifiedAt: staleDate)

    let client = BridgeClient(
        paths: paths,
        fileManager: fileManager,
        staleInterval: 600,
        configuration: .fromEnvironment([:])
    )

    client.cleanupStaleFiles(now: now)

    #expect(!fileManager.fileExists(atPath: staleRequest.path))
    #expect(!fileManager.fileExists(atPath: staleResponse.path))
    #expect(!fileManager.fileExists(atPath: staleLock.path))
}

@Test
func cleanupStaleFilesKeepsFreshIPCArtifacts() throws {
    let tempRoot = try makeTemporaryIPCBaseURL()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let paths = IPCPaths(baseURL: tempRoot)
    let fileManager = FileManager.default
    try [paths.requestsURL, paths.responsesURL, paths.locksURL].forEach {
        try fileManager.createDirectory(at: $0, withIntermediateDirectories: true)
    }

    let now = Date(timeIntervalSince1970: 20_000)
    let freshDate = now.addingTimeInterval(-30)
    let freshRequest = try makeIPCArtifact(at: paths.requestsURL, named: "fresh-request.json", modifiedAt: freshDate)
    let freshResponse = try makeIPCArtifact(at: paths.responsesURL, named: "fresh-response.json", modifiedAt: freshDate)
    let freshLock = try makeIPCArtifact(at: paths.locksURL, named: "fresh.lock", modifiedAt: freshDate)

    let client = BridgeClient(
        paths: paths,
        fileManager: fileManager,
        staleInterval: 600,
        configuration: .fromEnvironment([:])
    )

    client.cleanupStaleFiles(now: now)

    #expect(fileManager.fileExists(atPath: freshRequest.path))
    #expect(fileManager.fileExists(atPath: freshResponse.path))
    #expect(fileManager.fileExists(atPath: freshLock.path))
}

private func makeTemporaryIPCBaseURL() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeIPCArtifact(at directory: URL, named name: String, modifiedAt: Date) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try Data("test".utf8).write(to: url)
    try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: url.path)
    return url
}
