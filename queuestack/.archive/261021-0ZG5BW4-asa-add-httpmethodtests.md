---
id: '261021-0ZG5BW4'
title: 'asa: add HTTPMethodTests'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.195623Z'
status: closed
labels:
- test
---


asc has `src/ascTests/HTTPMethodTests.swift`; asa has none. Cover `HTTPMethod(argument:)`: case-insensitive parsing of GET/POST/PUT/DELETE and rejection of PATCH and unknown methods.
