---
id: '261021-0YNDG9V'
title: asa spec builds the docs index before validating arguments
author: Dominic Rodemer
created_at: '2026-10-21T08:43:25.998665Z'
status: closed
labels:
- bug
---


`ASA.runSpec` (`src/asa/Classes/ASA.swift`) constructs `DocsLookup(endpoints: Docs.shared.index(), …)` before checking the subcommand. On a cold cache, `asa spec`, `asa spec find` with no terms, or `asa spec foo` trigger a full index build (~200 downloads); offline with no cache they report a network error instead of the usage message. `asc spec` validates arguments first.

**Fix:** validate arguments first and build the lookup only inside the valid `find` / `show` cases. `show <Object>` doesn't need the index at all.
