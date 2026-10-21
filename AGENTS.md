# apple-cli - AGENTS.md

## Project Overview
`apple-cli` ships two minimal command-line clients for Apple's business APIs, built for AI agents:
- `asc`: App Store Connect API. It signs requests, handles pagination, rate limits and report downloads, and refuses blocked operations. The ASC account runs the whole business, so the guardrails in this file come before everything else.
- `asa`: Apple Ads Platform API (`api.ads.apple.com/v1`). It authenticates with OAuth access tokens, scopes requests to one ad account, handles `/query` pagination and rate limits, and looks up endpoints in Apple's documentation. Full read and write access on purpose: it has no blocklist and no spec gate.

## Tech Stack
- **Language**: Swift
- **Type**: Swift Package (two executables)
- **Platforms**: macOS

## Layout
- `src/AppleCLIKit`: shared library: background agent, Unix socket, 1Password, ES256 signing, request command plumbing, `Info.plist` (one version for both tools).
- `src/asc`: App Store Connect client, blocklist and spec gate.
- `src/asa`: Apple Ads client: OAuth access tokens, `X-AP-Context`, pagination of `/query` endpoints, and `asa spec find/show` built from Apple's DocC documentation JSON (no OpenAPI spec is published), cached in `~/Library/Caches/asa/docs/`.
- Each tool runs its own agent (`~/Library/Caches/asc/`, `~/Library/Caches/asa/`), so both can run at once.

## Guides (MANDATORY)
Read `~/Agents/Guides/xcode-project-guide.md` in full before planning or editing anything.

Read these in full before touching the matching code:
- Swift style (`.swift`): `~/Agents/Style/swift-swiftui-style-guide.md`

## Dependencies
None. Use only Apple frameworks (Foundation, CryptoKit) and system tools (`/usr/bin/gunzip`, `/usr/bin/unzip`, 1Password `op`). Never add third-party packages: a compromised dependency could take over the ASC or Apple Ads account.

## Security Rules (MANDATORY)

### Both tools
- **Keys**: `<tool> agent start` reads the key with `op read` and hands it to the background agent through its stdin pipe. Only the agent holds it, in memory, until its TTL ends or `<tool> agent stop`. Never write a private key or access token to disk, print it, log it or pass it as a command-line argument or environment variable. IDs (Key ID, Issuer ID, Client ID, Team ID, Ad Account ID) are not secret and may appear in `agent status`.
  - `asc` reads `key_id`, `issuer_id`, optional `vendor_number` and the attachment `AuthKey_<key_id>.p8`.
  - `asa` reads `client_id`, `team_id`, `key_id`, `ad_account_id` and the attachment `private-key.pem`. The agent also holds the OAuth access token it gets from `appleid.apple.com`, in memory only, and renews it before it expires and after a 401.
- **Host lock**: requests only go to the tool's own API host (`RequestPath` rejects any other host), so a key or token can never be sent elsewhere.
- **No caching of responses**: API calls use `URLSession.uncached` (ephemeral, no URL cache, no cookies), because responses hold business data.

### asc
- **Blocklist**: `Blocklist.swift` is compiled into the binary and is checked before a JWT is created. A blocked request must never be signed or sent, and there is no override flag.
- **Blocked operations**:
  - changing availability of apps, in-app purchases and subscriptions (includes removing from sale), ending pre-orders
  - changing prices of apps, in-app purchases and subscriptions
  - revoking or deactivating certificates
  - managing users, roles, visible apps and invitations
  - expiring builds
  - submitting versions, in-app purchases, subscriptions, subscription groups or featuring nominations for review; releasing versions; changing release type, release date or phased release
  - enabling Family Sharing (irreversible)
  - alternative distribution and marketplace settings
  - deleting App Store versions, in-app purchases, subscriptions, subscription groups, custom product pages, in-app events, A/B tests, Xcode Cloud products and workflows, webhooks, license agreements, App Clip experiences and Game Center objects (the objects themselves; editing their relationships stays allowed)
- **Allowed on purpose** (the user decided; don't block them): offers and offer codes, bundle IDs, capabilities, profiles, merchant and pass type IDs, TestFlight beta review submissions, starting A/B tests, Game Center releases, analytics report request deletion.
- **Blocklist tests**: Every blocklist rule needs a test that proves it blocks. Never remove or loosen a rule without explicit user instruction.
- **New endpoints**: Apple adds endpoints with spec updates, and a blocklist allows them until reviewed. That is why writes are pinned to the reviewed spec (see API Spec).

### asa
- **No guardrails, by decision**: the user decided Apple Ads needs full read and write access. `asa` has no blocklist and no spec gate. Don't add either, and don't treat their absence as a gap, without explicit user instruction.
- **Ad account scope**: every request carries `X-AP-Context: adAccountId=<ad_account_id>` from the 1Password item, except the org-level endpoints in `APIClient.orgScopedEndpoints`, which Apple documents without it (budget order writes fail with 403 when they carry it).

## API Spec

### asc
- `asc` downloads Apple's OpenAPI spec from `https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip` and caches it in `~/Library/Caches/asc/`, checking for a newer version at most once per 24h.
- The reviewed spec version and the SHA-256 of `openapi.oas.json` are compile-time constants. Writes are allowed only if the current spec matches both. Reads always work.
- A newer or changed spec, or a failed check, blocks writes (fail closed) until the user reviews the new write endpoints against the blocklist and the constants are bumped.
- Never bump the constants without explicit user instruction.

### asa
- Apple publishes no OpenAPI spec for the Apple Ads Platform API. `asa spec find/show` builds its endpoint index from Apple's DocC documentation JSON (`https://developer.apple.com/tutorials/data/documentation/apple-ads-platform-api`): the topic pages, the endpoint pages they link, and on `show` the data object pages of the body and its nested types.
- The index and the root page are cached in `~/Library/Caches/asa/docs/`, the other pages in its `pages/` subfolder; all are re-downloaded after 24h. A failed download falls back to the cached copy, so lookups work offline once cached.
- The docs only serve lookups; nothing in `asa` is gated on them.

## Configuration
- No environment-variable configuration or defaults. Everything, including the 1Password key references (`op://…`) and the agent TTL, is passed as arguments.
- `asa` takes the ad account from the 1Password item (`ad_account_id`), so one item per ad account; switching accounts means stopping the agent and starting it with another item.

## Build Commands
Build output goes to `--scratch-path`, outside the repo, instead of the default `.build` folder.
```bash
# Build
swift build --scratch-path /tmp/asc-build

# Clean
swift package clean --scratch-path /tmp/asc-build
```

## Testing (MANDATORY)
`swift test --scratch-path /tmp/asc-build`

Tests must never call the live APIs (App Store Connect, Apple Ads or `appleid.apple.com`) or download Apple's spec or documentation. Use fixtures, a temporary cache directory, and a local address that refuses connections (e.g. `http://127.0.0.1:9`) to exercise download failures.
