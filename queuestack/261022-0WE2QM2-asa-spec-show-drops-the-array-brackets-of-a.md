---
id: '261022-0WE2QM2'
title: asa spec show drops the array brackets of a request body
author: Dominic Rodemer
created_at: '2026-10-22T08:05:22.357843Z'
status: open
labels:
- bug
---



Found in the live test. `POST /v1/recommendations/{daily-budgets,target-cpas}/{apply,dismiss}` take an **array** body (`[ApplyDailyCapRecommendation]`). Apple's DocC `bodyContentType` tokens are `[`, the type, `]`, but `DocsPage.bodyType` (`src/asa/Classes/DocsPage.swift`) keeps only the token with an identifier, so `asa spec show` reports `"type": "ApplyDailyCapRecommendation"`. Sending an object then fails with HTTP 400 "Request body is not readable"; an array works.

**Fix:** build the body type name from all tokens (e.g. `[ApplyDailyCapRecommendation]`), as parameters already do via `typeName`, while still resolving the element type's fields.

**Test:** a fixture endpoint page with an array body shows the bracketed type and the element's resolved properties.
