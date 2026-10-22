---
id: '261022-0WE2XMN'
title: 'asa spec show: include Apple''s payload examples'
author: Dominic Rodemer
created_at: '2026-10-22T08:05:22.375157Z'
status: open
labels:
- feature
---



Found in the live test. Many endpoints have required filters or fields that the schema alone doesn't reveal, e.g. change history needs an `eventTime` BETWEEN filter plus `entityType`; suggestions need `promotedObjectId`, `promotedObjectType` and `queryType`; `GET /v1/search/geo` needs `supplySource`. Apple's endpoint pages contain "Payload Examples" (DocC `codeListing` blocks) that show exactly these. Using them would have avoided most of the 400s in the live test.

**Do:** add the endpoint page's example request bodies (code listings) to `asa spec show <METHOD> <path>` output, e.g. as an `examples` array of strings. Keep the JSON shape otherwise unchanged. Cover with a fixture test.
