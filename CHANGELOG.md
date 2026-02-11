# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Automatic counting in list_tasks responses**: New `returnedCount` field always shows how many items are in the current response
- **Optional total count with includeTotalCount**: Set `includeTotalCount: true` in the filter to get `totalCount` (total matching items without pagination)
- **CLI support**: Added `--include-total-count` flag to `focusrelay list-tasks` command
- **Prevents LLM counting errors**: Explicit counts eliminate manual counting mistakes
- Initial release with core MCP server functionality
- OmniFocus plugin for automation
- Timezone-aware queries
- Project health analysis
- Tag analytics
- Stale task detection

## [1.0.0] - 2026-01-31

### Added
- Complete MCP server implementation
- OmniFocus Bridge plugin for automation
- Time-based task queries (morning/afternoon/evening)
- Project health tracking (isStalled, nextTask)
- Tag-based task counts
- Stale threshold filtering (7days, 30days, 90days, 180days, 270days, 365days)
- Homebrew formula for easy installation
- Comprehensive documentation

### Features
- Query tasks by due dates, defer dates, completion status
- Filter by tags, projects, duration
- Timezone detection for accurate time queries
- Single-pass filtering for performance
- Cache layer for projects and tags
- Security prompt handling for first-time users
