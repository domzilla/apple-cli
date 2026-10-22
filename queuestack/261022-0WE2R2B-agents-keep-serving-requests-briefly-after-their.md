---
id: '261022-0WE2R2B'
title: Agents keep serving requests briefly after their TTL
author: Dominic Rodemer
created_at: '2026-10-22T08:05:22.366648Z'
status: open
labels:
- bug
---



Found in the live test. The asc agent with `--ttl 10m` (expiry 08:04:07Z) still answered `agent status` at 08:04:16Z ("in 0 min") and was gone by 08:04:42Z. `Agent.serve` (`src/AppleCLIKit/Classes/Agent.swift`) relies on `Task.sleep` until `expiresAt`, which may fire late (timer coalescing), so requests can still be signed for a few seconds past the TTL.

**Fix:** in `AgentConnection.handle`, refuse requests (and shut down) once `Date() >= expiresAt`, independent of the sleep. Applies to both asc and asa.

**Test:** a connection handler with an `expiresAt` in the past refuses a request.
