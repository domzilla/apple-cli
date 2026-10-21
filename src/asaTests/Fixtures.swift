//
//  Fixtures.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CryptoKit
import Foundation
import Testing
@testable import asa

enum Fixtures {
    static let clientID = "SEARCHADS.27478e71-3bb0-4588-998c-182e2b405577"
    static let teamID = "SEARCHADS.9703f56c-10ce-4876-8f59-e78e5e23a152"
    static let keyID = "d136aa66-0c3b-4bd4-9892-c20e8db024ab"

    static func credentials(key: P256.Signing.PrivateKey = P256.Signing.PrivateKey()) -> Credentials {
        Credentials(
            clientID: Credentials.ClientID(rawValue: self.clientID),
            teamID: Credentials.TeamID(rawValue: self.teamID),
            keyID: Credentials.KeyID(rawValue: self.keyID),
            adAccountID: Credentials.AdAccountID(rawValue: "123456789"),
            privateKeyPEM: key.pemRepresentation
        )
    }

    static func decodeBase64URL(_ part: Substring) throws -> Data {
        var base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return try #require(Data(base64Encoded: base64))
    }

    static func decodeJWTPart(_ part: Substring) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: self.decodeBase64URL(part)) as? [String: Any])
    }

    static func hasValidES256Signature(_ token: String, key: P256.Signing.PublicKey) throws -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        try #require(parts.count == 3)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: self.decodeBase64URL(parts[2]))
        return key.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8))
    }

    static func json(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
