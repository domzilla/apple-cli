---
id: '261021-0ZG5YV9'
title: 'asa: clean up ClientSecret tests'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.168307Z'
status: closed
labels:
- test
---


In `src/asaTests/ClientSecretTests.swift`:
- `lifetimeIsBelowAppleMaximum` only restates a constant. The test guide calls that pointless, so remove it (asc's equivalent at least guards Apple's 20-minute limit; if kept, assert it against the token's real `exp - iat`).
- The base64url decoding and signature verification are duplicated in `secretIsValid` and `acceptsOpenSSLKey`. Move them into `Fixtures`.
