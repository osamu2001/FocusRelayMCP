import Foundation
import Testing
@testable import OmniFocusCore

@Test
func taskItemRoundTrip() throws {
    let task = TaskItem(
        id: "abc123",
        name: "Test Task",
        note: "Note",
        projectID: "proj1",
        projectName: "Project",
        tagIDs: ["tag1"],
        tagNames: ["Tag"],
        dueDate: Date(timeIntervalSince1970: 1_700_000_000),
        deferDate: nil,
        completed: false,
        flagged: true,
        estimatedMinutes: 30,
        available: true
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(task)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(TaskItem.self, from: data)

    #expect(decoded.id == task.id)
    #expect(decoded.name == task.name)
    #expect(decoded.flagged == task.flagged)
    #expect(decoded.estimatedMinutes == task.estimatedMinutes)
}

@Test
func pageDefaults() {
    let page = PageRequest()
    #expect(page.limit == 50)
    #expect(page.cursor == nil)
}
