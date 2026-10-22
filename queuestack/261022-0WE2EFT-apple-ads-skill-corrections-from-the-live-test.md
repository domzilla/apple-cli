---
id: '261022-0WE2EFT'
title: 'apple-ads skill: corrections from the live test'
author: Dominic Rodemer
created_at: '2026-10-22T08:05:22.383784Z'
status: open
labels:
- task
---



Fixes to `/Users/dom/Agents/Skills/apple-ads/` (Agents repo), all observed in the live test on 2026-10-22:

- **Role name:** `GET /v1/acls` returned the role `API Campaign Manager` for a key with write access; the skill's role table says "API Account Manager". Use the names the API returns (keep Admin and the read-only role, verify its exact name if possible).
- **Ads and placements:** `POST /v1/ads` fails for campaigns on `APPSTORE_SEARCH_RESULTS` ("Ads not supported for campaigns with its supply source"). Search results campaigns serve without an ad. The "Create an App Store campaign" step 6 must say ads/creatives are only for the other placements (Search tab, Today tab, product pages).
- **Deleting DPP ads/creatives:** ads and creatives of type `DEFAULT_PRODUCT_PAGE` can't be deleted (`CAN_NOT_DELETE_DPP_CREATIVE_AD`, `OPERATION_ON_RESOURCE_NOT_SUPPORTED`); they go away with their campaign or stay. Mention it under Working with writes.
- **Bid strategies:** `MANUAL_CPM` is rejected for App Store ad accounts; App Store uses `MANUAL_CPT` (goal `TAP`) or `MAX_CONVERSIONS` (goal `INSTALL`).
- **Negative keywords query:** `POST /v1/negative-keywords/query` requires an `adGroupId` filter.
- **references/reports.md:** `MONTHLY` was rejected for 2025-01-01 to 2025-03-31 (90 days inclusive), so "≥ 90 days" is off by at least one day; say "more than 90 days" or verify the exact rule.
- **Required filters:** note that many query endpoints have required filters (change history: `eventTime` BETWEEN + `entityType`; suggestions: `promotedObjectId`, `promotedObjectType`, and `queryType` for phrases/categories; recommendations: `promotedObjectId`, `promotedObjectType`; `GET /v1/search/geo`: `supplySource`) and that Apple's 400 response names the missing one.
