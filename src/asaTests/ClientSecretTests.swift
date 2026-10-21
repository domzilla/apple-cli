//
//  ClientSecretTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import CryptoKit
import Foundation
import Testing
@testable import asa

@Suite("ClientSecret")
struct ClientSecretTests {
    @Test("The client secret has the header and claims Apple's OAuth guide requires and a valid ES256 signature")
    func secretIsValid() throws {
        let key = P256.Signing.PrivateKey()
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let token = try ClientSecret.token(for: Fixtures.credentials(key: key), now: now)
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        try #require(parts.count == 3)

        let header = try Fixtures.decodeJWTPart(parts[0])
        #expect(header.count == 2)
        #expect(header["alg"] as? String == "ES256")
        #expect(header["kid"] as? String == Fixtures.keyID)

        let payload = try Fixtures.decodeJWTPart(parts[1])
        #expect(payload.count == 5)
        #expect(payload["sub"] as? String == Fixtures.clientID)
        #expect(payload["iss"] as? String == Fixtures.teamID)
        #expect(payload["aud"] as? String == "https://appleid.apple.com")
        #expect(payload["iat"] as? Int == 1_800_000_000)
        #expect(payload["exp"] as? Int == 1_800_000_600)

        #expect(try Fixtures.hasValidES256Signature(token, key: key.publicKey))
    }

    @Test("A key generated with the openssl command from Apple's guide (SEC1 PEM) signs")
    func acceptsOpenSSLKey() throws {
        let result = try ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/openssl"),
            arguments: ["ecparam", "-genkey", "-name", "prime256v1", "-noout"],
            timeout: 10
        )
        try #require(result.status == 0)
        let pem = String(decoding: result.stdout, as: UTF8.self)
        try #require(pem.hasPrefix("-----BEGIN EC PRIVATE KEY-----"))

        var credentials = Fixtures.credentials()
        credentials = Credentials(
            clientID: credentials.clientID,
            teamID: credentials.teamID,
            keyID: credentials.keyID,
            adAccountID: credentials.adAccountID,
            privateKeyPEM: pem
        )
        let token = try ClientSecret.token(for: credentials)
        let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
        #expect(try Fixtures.hasValidES256Signature(token, key: key.publicKey))
    }
}
