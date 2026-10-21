//
//  AccessTokenTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation
import Testing
@testable import asa

@Suite("AccessToken")
struct AccessTokenTests {
    @Test("The token response from Apple's OAuth guide is parsed, with the expiry relative to now")
    func parsesResponse() throws {
        let response = Data("""
        {"access_token": "eyJhbGciOiJkaXIi.abc", "token_type": "Bearer", "expires_in": 3600, "scope": "searchadsorg"}
        """.utf8)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let token = try AccessToken(response: response, now: now)
        #expect(token.value == "eyJhbGciOiJkaXIi.abc")
        #expect(token.expiresAt == Date(timeIntervalSince1970: 1_800_003_600))
    }

    @Test(
        "Responses without a token are a credentials error",
        arguments: ["{\"error\": \"invalid_client\"}", "{\"access_token\": \"x\"}", "", "[]"]
    )
    func rejectsResponse(_ body: String) {
        #expect(throws: CLIError.self) {
            try AccessToken(response: Data(body.utf8))
        }
    }

    @Test("The token request is a form POST to appleid.apple.com with the four required parameters in the body")
    func tokenRequest() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let request = try AccessToken.request(for: Fixtures.credentials(), now: now)

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://appleid.apple.com/auth/oauth2/token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")

        var components = URLComponents()
        components.percentEncodedQuery = try String(decoding: #require(request.httpBody), as: UTF8.self)
        let parameters = try Dictionary(
            uniqueKeysWithValues: #require(components.queryItems).map { ($0.name, $0.value ?? "") }
        )
        #expect(parameters.count == 4)
        #expect(parameters["grant_type"] == "client_credentials")
        #expect(parameters["client_id"] == Fixtures.clientID)
        #expect(parameters["scope"] == "searchadsorg")

        let secret = try #require(parameters["client_secret"]).split(separator: ".")
        try #require(secret.count == 3)
        #expect(try Fixtures.decodeJWTPart(secret[1])["sub"] as? String == Fixtures.clientID)
        #expect(try Fixtures.decodeJWTPart(secret[1])["iat"] as? Int == 1_800_000_000)
    }
}
