---
id: '261021-0ZG530T'
title: Add RequestPath+ASA helper like asc's
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.141843Z'
status: closed
labels:
- refactoring
---


asc has `src/asc/Classes/RequestPath+ASC.swift` (`RequestPath(_ raw:)` with the ASC host). asa calls `RequestPath(rawPath, host: APIClient.host)` inline (`src/asa/Classes/Server.swift`, tests).

**Do:** add `src/asa/Classes/RequestPath+ASA.swift` with the same convenience init and use it in `Server` and the tests.
