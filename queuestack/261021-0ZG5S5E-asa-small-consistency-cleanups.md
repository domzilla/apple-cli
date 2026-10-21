---
id: '261021-0ZG5S5E'
title: 'asa: small consistency cleanups'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.159740Z'
status: open
labels:
- refactoring
---



- `src/asa/Classes/HTTPMethod.swift`: `CaseIterable` is unused; remove it unless a test needs it (see the HTTPMethodTests item).
- `src/asa/Classes/Server.swift`: `perform` has no doc comment; asc's `Server.perform` has one. Add one saying what asa checks before sending.
- `src/asa/Classes/Docs.swift` (`buildIndex`): `spec find` sorts methods alphabetically within a path; asc lists GET, POST, PATCH, DELETE in `HTTPMethod.allCases` order. Sort by `HTTPMethod.allCases` order (GET, POST, PUT, DELETE).
