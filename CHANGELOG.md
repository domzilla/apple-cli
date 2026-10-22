# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-10-22

### Added
- `asa`, a client for the Apple Ads Platform API, is installed alongside `asc`: full campaign management, reports and insights through a background agent that keeps the key from 1Password in memory.
- `asa` scopes every request to the ad account stored in the 1Password item and merges all pages of a query with `--paginate`.
- `asa spec find` and `asa spec show` look up endpoints, request fields, enum values and Apple's example requests in Apple's Apple Ads documentation, and `asa spec status [--check]` shows the endpoint index's size and age or rebuilds it.

### Changed
- When rate-limited, `asc` now also honors `RateLimit-Reset`, waits at most 5 minutes for a server-named wait and at most 16 seconds between its own retries.

### Fixed
- An agent whose TTL has ended now refuses requests and status with exit code 6 right away, instead of answering for a few more seconds.

## [1.2.0] - 2026-10-21

### Changed
- The project is now called apple-cli; install it with `brew install domzilla/tap/apple-cli`. The `asc` command is unchanged.

## [1.1.0] - 2026-10-09

### Fixed
- The blocklist now refuses changes to which stores sell a subscription, since dropping the App Store takes it off sale.
- The blocklist now refuses creating an App Store version with a release type or release date.
- `asc spec find` and `asc spec show` now work offline from the cached spec when the daily update check fails, and respond faster.
- Parallel writes during the daily spec update check no longer fail with a false "couldn't check Apple's API spec" error.

## [1.0.0] - 2026-10-09

### Added
- `asc` sends requests to the App Store Connect API, with pagination, rate-limit retries and decompressed sales and finance reports.
- `asc agent` keeps the API key from 1Password in memory for a limited time, so a session needs one approval instead of one per call.
- A built-in blocklist refuses prohibited operations such as availability and price changes, releases and submissions before anything is sent.
- Writes are disabled when Apple's API spec changes until the new spec has been reviewed.
- `asc spec find` and `asc spec show` look up endpoints in Apple's API spec and show which are blocked.
- `asc --version` prints the installed version.
