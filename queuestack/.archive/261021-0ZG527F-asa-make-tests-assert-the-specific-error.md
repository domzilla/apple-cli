---
id: '261021-0ZG527F'
title: 'asa: make tests assert the specific error'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.177422Z'
status: closed
labels:
- test
---


Two tests pass on any error:
- `DocsLookupTests.templateMatching` (`src/asaTests/DocsLookupTests.swift`) proves `/v1/campaigns/query` isn't read as `{id}` only by expecting some error. Instead, record the page names `loadPage` was asked for and assert `post-campaigns-query`.
- `DocsTests.staleCache` (`src/asaTests/DocsTests.swift`) expects any error when there's no cache. Assert the download failure.
