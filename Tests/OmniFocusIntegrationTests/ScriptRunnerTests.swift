import Testing
@testable import OmniFocusAutomation

private final class ScriptRunnerCallBox: @unchecked Sendable {
    var osaKitCalls = 0
    var osaScriptCalls = 0
    var lastSource: String?
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
