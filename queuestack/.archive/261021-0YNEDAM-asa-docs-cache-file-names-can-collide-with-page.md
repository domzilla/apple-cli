---
id: '261021-0YNEDAM'
title: asa docs cache file names can collide with page names
author: Dominic Rodemer
created_at: '2026-10-21T08:43:26.044154Z'
status: closed
labels:
- bug
---


`Docs` (`src/asa/Classes/Docs.swift`) stores the index as `index.json` and the root page as `root.json` in the same folder as pages, which are stored as `<page>.json`. A documentation page named `index` or `root` would overwrite them. Unlikely, but cheap to rule out.

**Fix:** keep pages in a `pages/` subfolder next to `index.json`.
