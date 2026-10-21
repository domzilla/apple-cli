---
id: '261021-0ZG5108'
title: 'asa: test conventions like asc''s'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.205081Z'
status: open
labels:
- test
---



- `src/asaTests/DocsTests.swift` hardcodes a `/tmp` path; asc's tests use `FileManager.default.temporaryDirectory` plus a UUID. Do the same.
- asa tests use `@testable import AppleCLIKit`; asc tests use a plain `import AppleCLIKit`. Use the plain import unless a test needs internal API.
