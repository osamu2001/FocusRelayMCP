# FocusRelayMCP Next Steps

This file tracks planned work and completion status.

## Completed

- [x] Bridge mode working end-to-end (health check, inbox, projects, tags)
- [x] Inbox filtering aligns with OmniFocus "Available" view (parent dropped/completed excluded)
- [x] IPC cleanup for stale files + timeout cleanup

## In Progress

- [x] Decide final defaults for inboxView and availableOnly behavior
- [x] Add `get_task` (bridge + MCP)
- [x] Add `get_task_counts` (bridge + MCP)

## Next Up

- [x] Add paging tests for projects/tags in bridge mode
- [x] Add lock file cleanup policy in plug-in (optional)
- [x] Document bridge install/test flow in README (short checklist)
