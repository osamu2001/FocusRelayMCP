import Foundation
import Logging
import MCP
import OmniFocusAutomation
import OmniFocusCore

@main
struct FocusRelayMCPMain {
    static func main() async throws {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        let logger = Logger(label: "focus.relay.mcp")
        let server = Server(
            name: "FocusRelayMCP",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: true))
        )

        let service: OmniFocusService = OmniFocusBridgeService()

        await server.withMethodHandler(ListTools.self) { _ in
            let tools = [
                Tool(
                    name: "list_tasks",
                    description: "List OmniFocus tasks with filters and pagination",
                    inputSchema: toolSchema(
                        properties: [
                            "filter": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "completed": .object(["type": .string("boolean")]),
                                    "flagged": .object(["type": .string("boolean")]),
                                    "availableOnly": .object(["type": .string("boolean")]),
                                    "inboxView": .object(["type": .string("string")]),
                                    "project": .object(["type": .string("string")]),
                                    "tags": .object([
                                        "type": .string("array"),
                                        "items": .object(["type": .string("string")])
                                    ]),
                                    "dueBefore": .object(["type": .string("string")]),
                                    "dueAfter": .object(["type": .string("string")]),
                                    "deferBefore": .object(["type": .string("string")]),
                                    "deferAfter": .object(["type": .string("string")]),
                                    "search": .object(["type": .string("string")]),
                                    "inboxOnly": .object(["type": .string("boolean")]),
                                    "projectView": .object(["type": .string("string")])
                                ])
                            ]),
                            "page": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "limit": .object(["type": .string("integer")]),
                                    "cursor": .object(["type": .string("string")])
                                ])
                            ]),
                            "fields": .object([
                                "type": .string("array"),
                                "items": .object(["type": .string("string")])
                            ])
                        ]
                    ),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "get_task",
                    description: "Get a single task by ID",
                    inputSchema: toolSchema(
                        properties: [
                            "id": .object(["type": .string("string")]),
                            "fields": .object([
                                "type": .string("array"),
                                "items": .object(["type": .string("string")])
                            ])
                        ],
                        required: ["id"]
                    ),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "list_projects",
                    description: "List OmniFocus projects with pagination (use page.limit and nextCursor)",
                    inputSchema: toolSchema(
                        properties: [
                            "page": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "limit": .object(["type": .string("integer")]),
                                    "cursor": .object(["type": .string("string")])
                                ])
                            ]),
                            "fields": .object([
                                "type": .string("array"),
                                "items": .object(["type": .string("string")])
                            ])
                        ]
                    ),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "list_tags",
                    description: "List OmniFocus tags with pagination (use page.limit and nextCursor)",
                    inputSchema: toolSchema(
                        properties: [
                            "page": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "limit": .object(["type": .string("integer")]),
                                    "cursor": .object(["type": .string("string")])
                                ])
                            ])
                        ]
                    ),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "get_task_counts",
                    description: "Get task counts for a filter",
                    inputSchema: toolSchema(
                        properties: [
                            "filter": .object(["type": .string("object")])
                        ]
                    ),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "get_project_counts",
                    description: "Get project/action counts for a view filter",
                    inputSchema: toolSchema(
                        properties: [
                            "filter": .object(["type": .string("object")])
                        ]
                    ),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "debug_inbox_probe",
                    description: "Debug inbox query behavior (counts and samples)",
                    inputSchema: toolSchema(properties: [:]),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "debug_inbox_probe_alt",
                    description: "Debug inbox query behavior using alternate queries and timings",
                    inputSchema: toolSchema(properties: [:]),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "bridge_health_check",
                    description: "Check OmniFocus bridge plug-in availability and responsiveness",
                    inputSchema: toolSchema(properties: [:]),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                )
            ]

            return .init(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                switch params.name {
                case "list_tasks":
                    let filter = try decodeArgument(TaskFilter.self, from: params.arguments, key: "filter") ?? TaskFilter()
                    let hasPage = params.arguments?["page"] != nil
                    let page = hasPage ? (try decodeArgument(PageRequest.self, from: params.arguments, key: "page") ?? PageRequest(limit: 50)) : PageRequest(limit: 50)
                    let requestedFields = decodeStringArray(params.arguments?["fields"]) ?? []
                    let fields = requestedFields.isEmpty ? ["id", "name"] : requestedFields
                    let result = try await service.listTasks(filter: filter, page: page, fields: fields)
                    let fieldSet = Set(fields)
                    let items = result.items.map { makeTaskOutput(from: $0, fields: fieldSet) }
                    let output = PageOutput(items: items, nextCursor: result.nextCursor, totalCount: result.totalCount)
                    return .init(content: [.text(try encodeJSON(output))])
                case "get_task":
                    let id = try decodeArgument(String.self, from: params.arguments, key: "id") ?? ""
                    if id.isEmpty {
                        return .init(content: [.text("Missing id")], isError: true)
                    }
                    let requestedFields = decodeStringArray(params.arguments?["fields"]) ?? []
                    let fields = requestedFields.isEmpty ? ["id", "name"] : requestedFields
                    let result = try await service.getTask(id: id, fields: fields)
                    let fieldSet = Set(fields)
                    let output = makeTaskOutput(from: result, fields: fieldSet)
                    return .init(content: [.text(try encodeJSON(output))])
                case "list_projects":
                    let hasPage = params.arguments?["page"] != nil
                    let page = hasPage ? (try decodeArgument(PageRequest.self, from: params.arguments, key: "page") ?? PageRequest(limit: 150)) : PageRequest(limit: 150)
                    let requestedFields = decodeStringArray(params.arguments?["fields"]) ?? []
                    let fields = requestedFields.isEmpty ? ["id", "name"] : requestedFields
                    let result = try await service.listProjects(page: page, fields: fields)
                    let fieldSet = Set(fields)
                    let items = result.items.map { makeProjectOutput(from: $0, fields: fieldSet) }
                    let output = PageOutput(items: items, nextCursor: result.nextCursor, totalCount: result.totalCount)
                    return .init(content: [.text(try encodeJSON(output))])
                case "list_tags":
                    let hasPage = params.arguments?["page"] != nil
                    let page = hasPage ? (try decodeArgument(PageRequest.self, from: params.arguments, key: "page") ?? PageRequest(limit: 150)) : PageRequest(limit: 150)
                    let result = try await service.listTags(page: page)
                    let items = result.items.map { TagOutput(id: $0.id, name: $0.name) }
                    let output = PageOutput(items: items, nextCursor: result.nextCursor, totalCount: result.totalCount)
                    return .init(content: [.text(try encodeJSON(output))])
                case "get_task_counts":
                    let filter = try decodeArgument(TaskFilter.self, from: params.arguments, key: "filter") ?? TaskFilter()
                    let counts = try await service.getTaskCounts(filter: filter)
                    return .init(content: [.text(try encodeJSON(counts))])
                case "get_project_counts":
                    let filter = try decodeArgument(TaskFilter.self, from: params.arguments, key: "filter") ?? TaskFilter()
                    let counts = try await service.getProjectCounts(filter: filter)
                    return .init(content: [.text(try encodeJSON(counts))])
                case "debug_inbox_probe":
                    if let automation = service as? OmniAutomationService {
                        let result = try await automation.debugInboxProbe()
                        return .init(content: [.text(try encodeJSON(result))])
                    }
                    return .init(content: [.text("debug_inbox_probe is only available in JXA mode")], isError: true)
                case "debug_inbox_probe_alt":
                    if let automation = service as? OmniAutomationService {
                        let result = try await automation.debugInboxProbeAlt()
                        return .init(content: [.text(try encodeJSON(result))])
                    }
                    return .init(content: [.text("debug_inbox_probe_alt is only available in JXA mode")], isError: true)
                case "bridge_health_check":
                    let bridge = OmniFocusBridgeService()
                    let result = try bridge.healthCheck()
                    return .init(content: [.text(try encodeJSON(result))])
                default:
                    return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
                }
            } catch {
                logger.error("Tool call failed: \(error.localizedDescription)")
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }

        let transport = StdioTransport(logger: logger)
        try await server.start(transport: transport)
        while true {
            try await Task.sleep(nanoseconds: 60 * 60 * 24 * 1_000_000_000)
        }
    }
}

private func toolSchema(properties: [String: Value], required: [String] = []) -> Value {
    var schema: [String: Value] = [
        "type": "object",
        "properties": .object(properties)
    ]

    if !required.isEmpty {
        schema["required"] = .array(required.map { .string($0) })
    }

    return .object(schema)
}

private func decodeArgument<T: Decodable>(_ type: T.Type, from args: [String: Value]?, key: String) throws -> T? {
    guard let value = args?[key] else { return nil }
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data)
}

private func decodeStringArray(_ value: Value?) -> [String]? {
    guard let value else { return nil }
    let data = try? JSONEncoder().encode(value)
    guard let data else { return nil }
    return try? JSONDecoder().decode([String].self, from: data)
}

private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}

private struct TaskOutput: Encodable {
    let id: String?
    let name: String?
    let note: String?
    let projectID: String?
    let projectName: String?
    let tagIDs: [String]?
    let tagNames: [String]?
    let dueDate: Date?
    let deferDate: Date?
    let completed: Bool?
    let flagged: Bool?
    let estimatedMinutes: Int?
    let available: Bool?
}

private struct PageOutput<T: Encodable>: Encodable {
    let items: [T]
    let nextCursor: String?
    let totalCount: Int?
}

private struct ProjectOutput: Encodable {
    let id: String?
    let name: String?
    let note: String?
    let status: String?
    let flagged: Bool?
}

private struct TagOutput: Encodable {
    let id: String
    let name: String
}

private func makeTaskOutput(from task: TaskItem, fields: Set<String>) -> TaskOutput {
    TaskOutput(
        id: fields.contains("id") ? task.id : nil,
        name: fields.contains("name") ? task.name : nil,
        note: fields.contains("note") ? task.note : nil,
        projectID: fields.contains("projectID") ? task.projectID : nil,
        projectName: fields.contains("projectName") ? task.projectName : nil,
        tagIDs: fields.contains("tagIDs") ? task.tagIDs : nil,
        tagNames: fields.contains("tagNames") ? task.tagNames : nil,
        dueDate: fields.contains("dueDate") ? task.dueDate : nil,
        deferDate: fields.contains("deferDate") ? task.deferDate : nil,
        completed: fields.contains("completed") ? task.completed : nil,
        flagged: fields.contains("flagged") ? task.flagged : nil,
        estimatedMinutes: fields.contains("estimatedMinutes") ? task.estimatedMinutes : nil,
        available: fields.contains("available") ? task.available : nil
    )
}

private func makeProjectOutput(from project: ProjectItem, fields: Set<String>) -> ProjectOutput {
    ProjectOutput(
        id: fields.contains("id") ? project.id : nil,
        name: fields.contains("name") ? project.name : nil,
        note: fields.contains("note") ? project.note : nil,
        status: fields.contains("status") ? project.status : nil,
        flagged: fields.contains("flagged") ? project.flagged : nil
    )
}
