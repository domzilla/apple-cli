//
//  AccessTokenProviderTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import asa

@Suite("AccessTokenProvider")
struct AccessTokenProviderTests {
    /// Hands out `token-1`, `token-2`, … and counts the fetches.
    actor TokenSource {
        private(set) var fetchCount = 0

        func next() async throws -> AccessToken {
            self.fetchCount += 1
            let value = "token-\(self.fetchCount)"
            try await Task.sleep(for: .milliseconds(50))
            return try AccessTokenProviderTests.token(value, expiresIn: 3600)
        }
    }

    static func token(_ value: String, expiresIn: TimeInterval) throws -> AccessToken {
        try AccessToken(response: Data("{\"access_token\": \"\(value)\", \"expires_in\": \(expiresIn)}".utf8))
    }

    @Test("A fetched token is cached until it nears expiry")
    func cachesToken() async throws {
        let source = TokenSource()
        let provider = AccessTokenProvider { try await source.next() }
        #expect(try await provider.token() == "token-1")
        #expect(try await provider.token() == "token-1")
        #expect(await source.fetchCount == 1)
    }

    @Test("A token passed at startup is used without a fetch")
    func usesInitialToken() async throws {
        let source = TokenSource()
        let provider = try AccessTokenProvider(token: Self.token("startup", expiresIn: 3600)) {
            try await source.next()
        }
        #expect(try await provider.token() == "startup")
        #expect(await source.fetchCount == 0)
    }

    @Test(
        "A token within the refresh margin of its expiry is replaced; one just outside it is kept",
        arguments: [
            (AccessTokenProvider.refreshMargin - 30, "token-1", 1),
            (AccessTokenProvider.refreshMargin + 60, "startup", 0),
        ]
    )
    func refreshMargin(expiresIn: TimeInterval, expected: String, fetchCount: Int) async throws {
        let source = TokenSource()
        let provider = try AccessTokenProvider(token: Self.token("startup", expiresIn: expiresIn)) {
            try await source.next()
        }
        #expect(try await provider.token() == expected)
        #expect(await source.fetchCount == fetchCount)
    }

    @Test("Concurrent requests share one fetch")
    func sharesConcurrentFetch() async throws {
        let source = TokenSource()
        let provider = AccessTokenProvider { try await source.next() }
        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await provider.token() }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(tokens == Array(repeating: "token-1", count: 10))
        #expect(await source.fetchCount == 1)
    }

    @Test("Invalidating the cached token makes the next request fetch a new one")
    func invalidatesCurrentToken() async throws {
        let source = TokenSource()
        let provider = AccessTokenProvider { try await source.next() }
        #expect(try await provider.token() == "token-1")
        await provider.invalidate("token-1")
        #expect(try await provider.token() == "token-2")
        #expect(await source.fetchCount == 2)
    }

    @Test("A late invalidation of an older token keeps the token that replaced it")
    func keepsNewerTokenOnLateInvalidation() async throws {
        let source = TokenSource()
        let provider = AccessTokenProvider { try await source.next() }
        #expect(try await provider.token() == "token-1")
        await provider.invalidate("token-1")
        #expect(try await provider.token() == "token-2")
        await provider.invalidate("token-1")
        #expect(try await provider.token() == "token-2")
        #expect(await source.fetchCount == 2)
    }
}
