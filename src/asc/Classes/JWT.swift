//
//  JWT.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

enum JWT {
    /// Apple rejects tokens that live longer than 20 minutes.
    static let lifetime: TimeInterval = 15 * 60

    // MARK: Public

    static func token(for credentials: Credentials, now: Date = Date()) throws -> String {
        let issuedAt = Int(now.timeIntervalSince1970)
        return try ES256.token(
            header: ["alg": "ES256", "kid": credentials.keyID.rawValue, "typ": "JWT"],
            payload: [
                "aud": "appstoreconnect-v1",
                "exp": issuedAt + Int(self.lifetime),
                "iat": issuedAt,
                "iss": credentials.issuerID.rawValue,
            ],
            privateKeyPEM: credentials.privateKeyPEM
        )
    }
}
