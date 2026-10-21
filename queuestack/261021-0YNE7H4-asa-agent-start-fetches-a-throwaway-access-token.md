---
id: '261021-0YNE7H4'
title: asa agent start fetches a throwaway access token outside the agent
author: Dominic Rodemer
created_at: '2026-10-21T08:43:26.007572Z'
status: open
labels:
- bug
---



The `load` closure in `ASA.run` (`src/asa/Classes/ASA.swift`) calls `AccessToken.fetch` in the foreground process to validate the credentials, then discards the token. The agent fetches a second token on its first request. So every session requests two tokens, and one briefly exists in a process other than the agent, contrary to AGENTS.md ("the agent also holds the OAuth access token").

**Fix:** pass the validated token to the agent in the startup payload (piped through stdin like the credentials) and seed `AccessTokenProvider` with it. This needs the startup to carry tool-specific state, e.g. by making asa's agent credentials type include the initial token.
