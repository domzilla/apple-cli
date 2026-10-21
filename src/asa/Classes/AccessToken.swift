//
//  AccessToken.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

/// An OAuth access token for the Apple Ads Platform API. It lives one hour and stays in the agent's memory.
struct AccessToken {
    static let tokenURL = URL(string: "https://appleid.apple.com/auth/oauth2/token")!
    static let scope = "searchadsorg"

    let value: String
    let expiresAt: Date

    /// Parses the token endpoint's response.
    init(response: Data, now: Date = Date()) throws {
        struct Body: Decodable {
            let accessToken: String
            let expiresIn: TimeInterval
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let body = try? decoder.decode(Body.self, from: response) else {
            throw CLIError.credentials("unexpected response from the token endpoint")
        }
        self.value = body.accessToken
        self.expiresAt = now.addingTimeInterval(body.expiresIn)
    }

    // MARK: Public

    /// Requests a new token with a fresh client secret.
    static func fetch(for credentials: Credentials) async throws -> AccessToken {
        let (data, response) = try await URLSession.uncached.data(for: self.request(for: credentials))
        let status = (response as! HTTPURLResponse).statusCode
        guard (200..<300).contains(status) else {
            // The body is an OAuth error such as {"error":"invalid_client"}; it never contains the secret.
            throw CLIError.credentials(
                "the token request failed with HTTP \(status): \(String(decoding: data, as: UTF8.self))"
            )
        }
        return try AccessToken(response: data)
    }

    static func request(for credentials: Credentials, now: Date = Date()) throws -> URLRequest {
        var components = URLComponents()
        components.queryItems = try [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: credentials.clientID.rawValue),
            URLQueryItem(name: "client_secret", value: ClientSecret.token(for: credentials, now: now)),
            URLQueryItem(name: "scope", value: self.scope),
        ]
        var request = URLRequest(url: self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // In the body, not the URL, so the secret never shows up in a logged URL.
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        return request
    }
}
