//
//  ES256.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CryptoKit
import Foundation

/// Signs JSON Web Tokens with a P-256 key (ES256), as both App Store Connect and Apple Ads require.
public enum ES256 {
    // MARK: Public

    /// Returns the signed token. The key is never part of an error message.
    public static func token(header: [String: Any], payload: [String: Any], privateKeyPEM: String) throws -> String {
        let key: P256.Signing.PrivateKey
        do {
            key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        } catch {
            throw CLIError.credentials("the private key is not a valid P-256 PEM key")
        }
        let signingInput = try self.base64URL(self.json(header)) + "." + self.base64URL(self.json(payload))
        let signature = try key.signature(for: Data(signingInput.utf8))
        return signingInput + "." + self.base64URL(signature.rawRepresentation)
    }

    /// Base64url without padding, as JWTs use it.
    public static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: Private

    private static func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
