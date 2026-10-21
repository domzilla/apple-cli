//
//  RateLimitTests.swift
//  AppleCLIKitTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import AppleCLIKit

@Suite("RateLimit")
struct RateLimitTests {
    static func response(_ headers: [String: String], status: Int = 429) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: URL(string: "https://api.ads.apple.com/v1/me")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: headers
        ))
    }

    @Test("Retry-After wins over RateLimit-Reset, which wins over exponential backoff")
    func delayHeaders() throws {
        #expect(try RateLimit.delay(for: Self.response(["Retry-After": "3", "RateLimit-Reset": "9"]), attempt: 1) == 3)
        #expect(try RateLimit.delay(for: Self.response(["RateLimit-Reset": "9"]), attempt: 1) == 9)
        #expect(try RateLimit.delay(for: Self.response([:]), attempt: 1) == 2)
        #expect(try RateLimit.delay(for: Self.response([:]), attempt: 3) == 8)
    }

    @Test("Backoff is capped at 16 seconds, a server wait at 5 minutes, and neither is negative")
    func delayBounds() throws {
        #expect(try RateLimit.delay(for: Self.response([:]), attempt: 4) == 16)
        #expect(try RateLimit.delay(for: Self.response([:]), attempt: 5) == 16)
        #expect(try RateLimit.delay(for: Self.response(["Retry-After": "120"]), attempt: 1) == 120)
        #expect(try RateLimit.delay(for: Self.response(["RateLimit-Reset": "60"]), attempt: 1) == 60)
        #expect(try RateLimit.delay(for: Self.response(["Retry-After": "300"]), attempt: 1) == 300)
        #expect(try RateLimit.delay(for: Self.response(["Retry-After": "900"]), attempt: 1) == 300)
        #expect(try RateLimit.delay(for: Self.response(["RateLimit-Reset": "900"]), attempt: 1) == 300)
        #expect(try RateLimit.delay(for: Self.response(["Retry-After": "-1"]), attempt: 1) == 0)
    }

    @Test("A header that isn't a number of seconds falls back to backoff")
    func delayIgnoresNonNumericHeader() throws {
        let date = "Wed, 21 Oct 2026 07:28:00 GMT"
        #expect(try RateLimit.delay(for: Self.response(["Retry-After": date]), attempt: 2) == 4)
    }

    @Test("A 429 is retried up to five times, counting each retry")
    func retriesRateLimitedResponse() async throws {
        let response = try Self.response(["Retry-After": "0"])
        var attempt = 0
        for expected in 1...5 {
            #expect(try await RateLimit.waitBeforeRetry(response, attempt: &attempt))
            #expect(attempt == expected)
        }
        #expect(try await RateLimit.waitBeforeRetry(response, attempt: &attempt) == false)
        #expect(attempt == 5)
    }

    @Test("Responses other than 429 are not retried", arguments: [200, 401, 403, 500, 503])
    func ignoresOtherStatus(_ status: Int) async throws {
        var attempt = 0
        #expect(try await RateLimit.waitBeforeRetry(
            Self.response(["Retry-After": "0"], status: status),
            attempt: &attempt
        ) == false)
        #expect(attempt == 0)
    }
}
