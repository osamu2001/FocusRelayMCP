import Dispatch
import Foundation
import Testing
@testable import OmniFocusAutomation

private final class ScriptRunnerCallBox: @unchecked Sendable {
    var osaKitCalls = 0
    var osaScriptCalls = 0
    var lastSource: String?
}

private final class PipeDrainProbe: @unchecked Sendable {
    private let startedReaders = DispatchSemaphore(value: 0)
    private let releaseReaders = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var waitObservedReadersStarted = false

    func readStdout() -> Data {
        startedReaders.signal()
        releaseReaders.wait()
        return Data((String(repeating: "x", count: 128 * 1024) + "\n").utf8)
    }

    func readStderr() -> Data {
        startedReaders.signal()
        releaseReaders.wait()
        return Data()
    }

    func waitUntilExit() {
        let first = startedReaders.wait(timeout: .now() + 2)
        let second = startedReaders.wait(timeout: .now() + 2)
        lock.lock()
        waitObservedReadersStarted = first == .success && second == .success
        lock.unlock()
        releaseReaders.signal()
        releaseReaders.signal()
    }

    func observedReadersBeforeWait() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return waitObservedReadersStarted
    }
}

@Test
func scriptRunnerFallsBackToOsascriptForAppleEventAuthorizationErrors() throws {
    let box = ScriptRunnerCallBox()
    let runner = ScriptRunner(
        osaKitExecutor: { source in
            box.osaKitCalls += 1
            box.lastSource = source
            throw AutomationError.executionFailed("""
            {
                OSAScriptErrorNumberKey = "-1743";
            }
            """)
        },
        osaScriptExecutor: { source in
            box.osaScriptCalls += 1
            box.lastSource = source
            return #"{"ok":true}"#
        }
    )

    let output = try runner.runJavaScript(#"JSON.stringify({ok:true})"#)

    #expect(output == #"{"ok":true}"#)
    #expect(box.osaKitCalls == 1)
    #expect(box.osaScriptCalls == 1)
    #expect(box.lastSource == #"JSON.stringify({ok:true})"#)
}

@Test
func scriptRunnerKeepsNonAuthorizationFailuresOnOsaKitPath() {
    let box = ScriptRunnerCallBox()
    let runner = ScriptRunner(
        osaKitExecutor: { _ in
            box.osaKitCalls += 1
            throw AutomationError.executionFailed("OSAScriptErrorNumberKey = \"-1708\"")
        },
        osaScriptExecutor: { _ in
            box.osaScriptCalls += 1
            return "unexpected"
        }
    )

    #expect(throws: AutomationError.self) {
        _ = try runner.runJavaScript("1")
    }
    #expect(box.osaKitCalls == 1)
    #expect(box.osaScriptCalls == 0)
}

@Test
func scriptRunnerDrainsOsascriptPipesBeforeWaitingForExit() throws {
    let probe = PipeDrainProbe()

    let output = try ScriptRunner.collectOSAScriptResult(
        waitUntilExit: { probe.waitUntilExit() },
        terminationStatus: { 0 },
        readStdout: { probe.readStdout() },
        readStderr: { probe.readStderr() }
    )

    #expect(probe.observedReadersBeforeWait())
    #expect(output == String(repeating: "x", count: 128 * 1024))
}

@Test
func scriptRunnerPrefersLargeStandardErrorFromOsascriptFailure() {
    let largeError = String(repeating: "e", count: 128 * 1024)

    do {
        _ = try ScriptRunner.collectOSAScriptResult(
            waitUntilExit: {},
            terminationStatus: { 1 },
            readStdout: { Data("ignored".utf8) },
            readStderr: { Data(largeError.utf8) }
        )
        Issue.record("Expected collectOSAScriptResult to throw for non-zero termination status")
    } catch let AutomationError.executionFailed(message) {
        #expect(message == largeError)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
