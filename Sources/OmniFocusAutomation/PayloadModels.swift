import Foundation

struct TaskItemPayload: Codable {
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

struct ProjectItemPayload: Codable {
    let id: String?
    let name: String?
    let note: String?
    let status: String?
    let flagged: Bool?
}

struct TagItemPayload: Codable {
    let id: String?
    let name: String?
}
