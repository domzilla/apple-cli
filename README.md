# apple-cli

Two minimal command-line clients for AI agents, installed together:

- `asc` for the App Store Connect API, with a built-in blocklist
- `asa` for the Apple Ads Platform API

Both sign requests with a key held only in memory by a short-lived background agent.

## Install

```bash
brew install domzilla/tap/apple-cli
```

Both tools require the [1Password CLI](https://developer.1password.com/docs/cli/) with the desktop app integration enabled.

## asc

A minimal App Store Connect API client for AI agents. It signs requests with a key held only in memory, and refuses prohibited operations – removing apps from sale, price changes, releases, submissions, deleting users and more – before anything is sent.

### Usage

Store each API key as a 1Password item with the fields `key_id`, `issuer_id`, optionally `vendor_number`, and the key attached as `AuthKey_<key_id>.p8`.

```bash
# Load the key once per session (one 1Password approval); stops after 30 minutes by default
asc agent start --credentials "op://Vault/Item" --ttl 30m

# Requests go through the agent
asc GET "/v1/apps?fields[apps]=name,bundleId" --paginate
asc PATCH /v1/appStoreVersionLocalizations/<id> --body change.json

# Look up endpoints in Apple's API spec
asc spec find customerReviews
asc spec show POST /v1/customerReviewResponses

asc agent stop
```

Run `asc --help` for all options and exit codes.

### Safety

- The key is read from 1Password by the agent and kept only in its memory. It is never written to disk, logged or passed as an argument.
- The blocklist is compiled into the binary and checked before a request is signed. There is no override.
- Writes are only allowed while Apple's published API spec matches the one the blocklist was reviewed against, so new endpoints can't slip through unreviewed.
- No third-party dependencies: only Apple frameworks and system tools.

## asa

A minimal client for the [Apple Ads Platform API](https://developer.apple.com/documentation/apple-ads-platform-api) (`api.ads.apple.com/v1`), the successor of the Campaign Management API v5. Full read and write access: campaigns, ad groups, keywords, ads, creatives, budget orders, reports, insights and recommendations.

### Usage

Create an API user and key pair as described in [Implementing OAuth for the Apple Ads Platform API](https://developer.apple.com/documentation/apple-ads-platform-api/implementing-oauth-for-the-apple-ads-platform-api). Store each key as a 1Password item with the fields `client_id`, `team_id`, `key_id`, `ad_account_id` and the private key attached as `private-key.pem`. Use one item per ad account.

```bash
# Load the key and get an access token (one 1Password approval)
asa agent start --credentials "op://Vault/Apple Ads" --ttl 30m

asa GET /v1/acls
asa POST /v1/campaigns/query --body query.json --paginate
asa PUT /v1/campaigns/<id> --body change.json
asa POST /v1/reports/apps/campaigns/query --body report.json --out report.json

# Look up endpoints and fields in Apple's documentation
asa spec find keyword
asa spec show POST /v1/campaigns
asa spec show CampaignStatus

asa agent stop
```

- Every request carries `X-AP-Context: adAccountId=<ad_account_id>`, except org-level endpoints (`/v1/me`, `/v1/acls`, `/v1/orgs/{id}`, `/v1/advertiser-resources`, creating ad accounts, and budget order writes).
- The access token is refreshed before it expires and after a 401. Rate limits (429) are retried with `Retry-After`.
- Apple publishes no OpenAPI spec for this API, so `asa spec` builds its endpoint index from Apple's documentation pages, cached in `~/Library/Caches/asa/` and refreshed after 24 hours.
- `--paginate` walks `pagination.offset` of a `POST .../query` request until `totalCount` and merges the rows.

Run `asa --help` for all options and exit codes.

## License

MIT
