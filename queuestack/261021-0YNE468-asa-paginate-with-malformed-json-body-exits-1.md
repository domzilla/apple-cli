---
id: '261021-0YNE468'
title: asa --paginate with malformed JSON body exits 1 instead of 2
author: Dominic Rodemer
created_at: '2026-10-21T08:43:26.026536Z'
status: open
labels:
- bug
---



`QueryPages.init` (`src/asa/Classes/QueryPages.swift`) lets `JSONSerialization` throw for a body like `{`. `CLIError(error)` maps it to `.failure`, so the exit code is 1 (API error) instead of 2 (usage). `QueryPagesTests.rejectsBody` accepts any error.

**Fix:** catch the parse error and throw `CLIError.usage("--paginate needs a JSON object body")`. Assert `.usage` in the test.
