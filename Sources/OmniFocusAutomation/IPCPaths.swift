import Foundation

struct IPCPaths {
    let baseURL: URL
    let requestsURL: URL
    let responsesURL: URL
    let locksURL: URL
    let logsURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.requestsURL = baseURL.appendingPathComponent("requests", isDirectory: true)
        self.responsesURL = baseURL.appendingPathComponent("responses", isDirectory: true)
        self.locksURL = baseURL.appendingPathComponent("locks", isDirectory: true)
        self.logsURL = baseURL.appendingPathComponent("logs", isDirectory: true)
    }

    static func `default`() -> IPCPaths {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let container = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("com.omnigroup.OmniFocus4", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("FocusRelayIPC", isDirectory: true)

        if FileManager.default.fileExists(atPath: container.deletingLastPathComponent().path) {
            return IPCPaths(baseURL: container)
        }

        let fallback = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("focusrelay", isDirectory: true)
        return IPCPaths(baseURL: fallback)
    }
}
