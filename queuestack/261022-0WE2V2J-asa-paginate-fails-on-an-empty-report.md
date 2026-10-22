---
id: '261022-0WE2V2J'
title: asa --paginate fails on an empty report
author: Dominic Rodemer
created_at: '2026-10-22T08:05:22.347248Z'
status: open
labels:
- bug
---



Found in the live test (2026-10-22). A report with no data comes back as `{"result":{},"pagination":{"offset":0,"pageSize":0,"totalCount":0}}`: `result` is an empty object without `rows`. `QueryPages.add` (`src/asa/Classes/QueryPages.swift`) then throws "the query response has no result rows to paginate" (exit 1), although the request succeeded. Reproduced with `POST /v1/reports/apps/ads/query --paginate` and `POST /v1/reports/apps/campaigns/query --paginate` for a period without activity.

**Fix:** treat a `result` object without `rows` as zero rows when `totalCount` is 0 (and keep failing when rows are missing but `totalCount` > 0). The merged output should be the first page unchanged, with an empty `rows` array or as Apple sent it.

**Test:** an empty-report page (shape above) merges to a result without error.
