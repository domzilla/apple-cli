//
//  APIClient.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

struct APIClient {
    static let host = "api.ads.apple.com"
    static let maxRateLimitRetries = 5
    static let maxBackoff: TimeInterval = 16
    static let maxServerWait: TimeInterval = 300

    /// Endpoints scoped to the organization instead of an ad account. Budget order writes fail with 403 when they
    /// carry an ad account, so none of these get the `X-AP-Context` header.
    static let orgScopedEndpoints: [(method: HTTPMethod, path: String)] = [
        (.get, "/v1/me"),
        (.get, "/v1/acls"),
        (.get, "/v1/orgs/*"),
        (.get, "/v1/advertiser-resources"),
        (.post, "/v1/ad-accounts"),
        (.post, "/v1/shared-budgets"),
        (.put, "/v1/shared-budgets/*"),
        (.delete, "/v1/shared-budgets/*"),
    ]

    let adAccountID: Credentials.AdAccountID
    let tokens: AccessTokenProvider

    // MARK: Public

    /// Sends one request. Retries on 429 as Apple's rate-limit guide describes, and once on 401 with a new token.
    func send(method: HTTPMethod, path: RequestPath, body: Data?) async throws -> Data {
        var request = URLRequest(url: path.url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let context = Self.context(method: method, path: path, adAccountID: self.adAccountID) {
            request.setValue(context, forHTTPHeaderField: "X-AP-Context")
        }

        var attempt = 0
        var hasRenewedToken = false
        while true {
            let token = try await self.tokens.token()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.uncached.data(for: request)
            let http = response as! HTTPURLResponse

            if http.statusCode == 401, !hasRenewedToken {
                hasRenewedToken = true
                await self.tokens.invalidate(token)
                continue
            }
            if http.statusCode == 429, attempt < Self.maxRateLimitRetries {
                attempt += 1
                try await Task.sleep(for: .seconds(Self.retryDelay(http, attempt: attempt)))
                continue
            }
            guard (200..<300).contains(http.statusCode) else {
                throw CLIError.api(status: http.statusCode, body: data)
            }
            return data
        }
    }

    /// Requests every page of a `POST .../query` endpoint and merges them into one response.
    func sendPaginated(path: RequestPath, body: Data?) async throws -> Data {
        var pages = try QueryPages(path: path.path, body: body)
        while let pageBody = try pages.nextBody() {
            try await pages.add(self.send(method: .post, path: path, body: pageBody))
        }
        return try pages.merged()
    }

    static func context(method: HTTPMethod, path: RequestPath, adAccountID: Credentials.AdAccountID) -> String? {
        let isOrgScoped = self.orgScopedEndpoints.contains { endpoint in
            let pattern = endpoint.path.split(separator: "/")
            return endpoint.method == method
                && pattern.count == path.segments.count
                && zip(pattern, path.segments).allSatisfy { $0 == "*" || $0 == $1 }
        }
        return isOrgScoped ? nil : "adAccountId=\(adAccountID.rawValue)"
    }

    /// `Retry-After`, else `RateLimit-Reset` (bounded at 5 minutes), else exponential backoff capped at 16 seconds.
    static func retryDelay(_ response: HTTPURLResponse, attempt: Int) -> TimeInterval {
        let header = response.value(forHTTPHeaderField: "Retry-After")
            ?? response.value(forHTTPHeaderField: "RateLimit-Reset")
        if let delay = header.flatMap(TimeInterval.init) {
            return min(max(delay, 0), self.maxServerWait)
        }
        return min(pow(2, Double(attempt)), self.maxBackoff)
    }
}
