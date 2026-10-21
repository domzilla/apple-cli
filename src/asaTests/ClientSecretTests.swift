//
//  ClientSecretTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CryptoKit
import Foundation
import Testing
@testable import AppleCLIKit
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

        var base64 = parts[2].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: #require(Data(base64Encoded: base64)))
        #expect(key.publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    @Test("The secret expires before Apple's 180-day maximum")
    func lifetimeIsBelowAppleMaximum() {
        #expect(ClientSecret.lifetime > 0)
        #expect(ClientSecret.lifetime < 180 * 24 * 60 * 60)
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
        let parts = token.split(separator: ".")
        let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
        var base64 = parts[2].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: #require(Data(base64Encoded: base64)))
        #expect(key.publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }
}
