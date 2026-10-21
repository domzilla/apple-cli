---
id: '261021-0ZG549V'
title: Mark asc-only parts of AppleCLIKit as such
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.150792Z'
status: open
labels:
- refactoring
---



`CLIError.blocked` and `.specGate` (`src/AppleCLIKit/Classes/CLIError.swift`) and the "so the blocklist sees exactly the resource" wording in `RequestPath.swift` are asc-specific but live in the shared library.

**Do:** keep them (one shared exit-code space), but say in their doc comments that only asc uses them.
