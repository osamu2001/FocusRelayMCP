import Foundation
import OmniFocusCore

public final class OmniFocusBridgeService: OmniFocusService {
    private let client: BridgeClient
    private let cache = CatalogCache()
    private let cacheTTL: TimeInterval

    public init(cacheTTL: TimeInterval = 300) {
        self.client = BridgeClient()
        self.cacheTTL = cacheTTL
    }

    public func listTasks(filter: TaskFilter, page: PageRequest, fields: [String]?) async throws -> Page<TaskItem> {
        return try await client.listTasks(filter: filter, page: page, fields: fields)
    }

    public func getTask(id: String, fields: [String]?) async throws -> TaskItem {
        return try await client.getTask(id: id, fields: fields)
    }

    public func listProjects(
        page: PageRequest,
        statusFilter: String?,
        includeTaskCounts: Bool,
        reviewDueBefore: Date?,
        reviewDueAfter: Date?,
        reviewPerspective: Bool,
        completed: Bool?,
        completedBefore: Date?,
        completedAfter: Date?,
        fields: [String]?
    ) async throws -> Page<ProjectItem> {
        guard cacheTTL > 0 else {
            return try await client.listProjects(
                page: page,
                statusFilter: statusFilter,
                includeTaskCounts: includeTaskCounts,
                reviewDueBefore: reviewDueBefore,
                reviewDueAfter: reviewDueAfter,
                reviewPerspective: reviewPerspective,
                completed: completed,
                completedBefore: completedBefore,
                completedAfter: completedAfter,
                fields: fields
            )
        }
        let shouldBypassCache = reviewPerspective || reviewDueBefore != nil || reviewDueAfter != nil || completed != nil || completedBefore != nil || completedAfter != nil
        if !shouldBypassCache {
            let key = CacheKey.projects(
                page: page,
                fields: fields,
                statusFilter: statusFilter,
                includeTaskCounts: includeTaskCounts
            )
            if let cached = await cache.getProjects(key: key) {
                return cached
            }
            let pageResult = try await client.listProjects(
                page: page,
                statusFilter: statusFilter,
                includeTaskCounts: includeTaskCounts,
                reviewDueBefore: reviewDueBefore,
                reviewDueAfter: reviewDueAfter,
                reviewPerspective: reviewPerspective,
                completed: completed,
                completedBefore: completedBefore,
                completedAfter: completedAfter,
                fields: fields
            )
            await cache.setProjects(pageResult, key: key, ttl: cacheTTL)
            return pageResult
        }

        return try await client.listProjects(
            page: page,
            statusFilter: statusFilter,
            includeTaskCounts: includeTaskCounts,
            reviewDueBefore: reviewDueBefore,
            reviewDueAfter: reviewDueAfter,
            reviewPerspective: reviewPerspective,
            completed: completed,
            completedBefore: completedBefore,
            completedAfter: completedAfter,
            fields: fields
        )
    }

    public func listTags(page: PageRequest, statusFilter: String?, includeTaskCounts: Bool) async throws -> Page<TagItem> {
        guard cacheTTL > 0 else {
            return try await client.listTags(page: page, statusFilter: statusFilter, includeTaskCounts: includeTaskCounts)
        }
        let key = CacheKey.tags(
            page: page,
            statusFilter: statusFilter,
            includeTaskCounts: includeTaskCounts
        )
        if let cached = await cache.getTags(key: key) {
            return cached
        }
        let pageResult = try await client.listTags(page: page, statusFilter: statusFilter, includeTaskCounts: includeTaskCounts)
        await cache.setTags(pageResult, key: key, ttl: cacheTTL)
        return pageResult
    }

    public func getTaskCounts(filter: TaskFilter) async throws -> TaskCounts {
        return try await client.getTaskCounts(filter: filter)
    }

    public func getProjectCounts(filter: TaskFilter) async throws -> ProjectCounts {
        return try await client.getProjectCounts(filter: filter)
    }

    public func healthCheck() async throws -> BridgeHealthResult {
        let response = try await client.ping()
        return BridgeHealthResult(
            ok: response.ok,
            plugin: response.data?.plugin,
            version: response.data?.version,
            error: response.error?.message,
            timingMs: response.timingMs
        )
    }
}

public struct BridgeHealthResult: Codable, Sendable {
    public let ok: Bool
    public let plugin: String?
    public let version: String?
    public let error: String?
    public let timingMs: Int?
}
