---
id: '261021-0YNETJ2'
title: asa spec show <Object> recursion guard compares title to page name
author: Dominic Rodemer
created_at: '2026-10-21T08:43:26.017648Z'
status: closed
labels:
- bug
---


`DocsLookup.show(object:)` (`src/asa/Classes/DocsLookup.swift`) seeds `seen` with `page.title` (e.g. `CampaignCreate`), but `resolve` compares page names (`campaigncreate`). A self-referencing type is expanded one level deeper than intended.

**Fix:** seed with `[Self.pageName(object: name)]`.

**Test:** a fixture object whose property refers back to itself, shown via `show(object:)`, isn't expanded.
