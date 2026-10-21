---
id: '261021-0ZG5RPP'
title: 'asa: refuse asset uploads with a clear error'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.223680Z'
status: closed
labels:
- feature
---


`POST /v1/assets/upload` needs multipart form data, which `asa` can't send (bodies are JSON). Today the request goes out and fails at the API; the apple-ads skill carries a note about it instead.

**Do:** have `asa` refuse `POST /v1/assets/upload` with a usage error ("asset uploads need multipart form data, which asa doesn't support; upload assets in the Apple Ads UI"), test it, and drop the note from the skill.
