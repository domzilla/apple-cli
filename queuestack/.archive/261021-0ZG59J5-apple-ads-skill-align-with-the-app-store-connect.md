---
id: '261021-0ZG59J5'
title: 'apple-ads skill: align with the app-store-connect skill'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.214264Z'
status: closed
labels:
- task
---


In `/Users/dom/Agents/Skills/apple-ads/SKILL.md` (Agents repo):
- Add a separate "## Reports" section like the asc skill's, saying to read `references/reports.md` before requesting any report. Reports are currently only a bullet under "Typical workflows".
- Once bug "asa --paginate fails on entity queries without fetchTotalCount" is fixed, remove the `fetchTotalCount` rule from "API shape" and the `--paginate` bullet.
- State the maximum `pageSize` for entity queries, if Apple documents one (`asa spec show QueryPagination`).
- Session lifecycle: the `agent status` comment leaves out `team_id`.
- Verify two unconfirmed claims against Apple's docs: that report responses always include `totalCount` (`ResponsePagination`), and the role names "API Account Read Only" / "API Account Manager" (the User ACL page lists Admin, API Account Manager, API Account Read Only).
