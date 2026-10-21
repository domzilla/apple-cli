---
id: '261021-0YND124'
title: asa --paginate fails on entity queries without fetchTotalCount
author: Dominic Rodemer
created_at: '2026-10-21T08:43:25.979945Z'
status: open
labels:
- bug
---



`QueryPages.add` (`src/asa/Classes/QueryPages.swift`) requires `pagination.totalCount`, but Apple's `QueryPaginationResult` only returns it when the request sets `fetchTotalCount: true`. So `asa POST /v1/campaigns/query --paginate` fails after the first page unless the caller adds it. With `asc`, `--paginate` needs nothing extra.

**Fix:** in `nextBody`, set `pagination.fetchTotalCount = true` for entity queries (paths outside `/v1/reports/`, whose `RequestPagination` has no such field). Alternatively, when `totalCount` is missing, stop on a page shorter than the requested `pageSize`. Then remove the `fetchTotalCount` rule from the apple-ads skill (SKILL.md "API shape" and the `--paginate` bullet) and from README.

**Test:** an entity query body without `fetchTotalCount` gets it in `nextBody`, and a report body doesn't.
