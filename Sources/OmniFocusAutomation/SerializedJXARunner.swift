import Foundation

final class SerializedJXARunner: @unchecked Sendable {
    private let runner: ScriptRunner
    private let queue: DispatchQueue
    private let lock = NSLock()
    private let defaultTimeout: TimeInterval

    init(runner: ScriptRunner, defaultTimeout: TimeInterval = 15.0) {
        self.runner = runner
        self.defaultTimeout = defaultTimeout
        self.queue = DispatchQueue(label: "focusrelay.omni.jxa.serial", qos: .utility)
    }

    func runJavaScript(_ source: String, timeout: TimeInterval? = nil) throws -> String {
        let timeout = timeout ?? defaultTimeout
        let done = DispatchSemaphore(value: 0)
        let resultBox = ResultBox()

        queue.async { [runner, lock] in
            lock.lock()
            defer { lock.unlock() }
            autoreleasepool {
                do {
                    let output = try runner.runJavaScript(source)
                    resultBox.store(.success(output))
                } catch {
                    resultBox.store(.failure(error))
                }
            }
            done.signal()
        }

        if done.wait(timeout: .now() + timeout) == .timedOut {
            throw AutomationError.executionFailed("JXA execution timed out after \(Int(timeout))s")
        }

        guard let result = resultBox.load() else {
            throw AutomationError.executionFailed("JXA execution failed without a result")
        }
        return try result.get()
    }
}

private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<String, Error>?

    func store(_ result: Result<String, Error>) {
        lock.lock()
        value = result
        lock.unlock()
    }

    func load() -> Result<String, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
