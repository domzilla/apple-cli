//
//  ClientSecret.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

/// The JWT that authenticates an access token request at `appleid.apple.com`.
enum ClientSecret {
    static let audience = "https://appleid.apple.com"
    /// Apple allows up to 180 days, but each secret is used for a single token request.
    static let lifetime: TimeInterval = 10 * 60

    // MARK: Public

    static func token(for credentials: Credentials, now: Date = Date()) throws -> String {
        let issuedAt = Int(now.timeIntervalSince1970)
        return try ES256.token(
            header: ["alg": "ES256", "kid": credentials.keyID.rawValue],
            payload: [
                "aud": self.audience,
                "exp": issuedAt + Int(self.lifetime),
                "iat": issuedAt,
                "iss": credentials.teamID.rawValue,
                "sub": credentials.clientID.rawValue,
            ],
            privateKeyPEM: credentials.privateKeyPEM
        )
    }
}
