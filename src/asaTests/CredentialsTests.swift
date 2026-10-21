//
//  CredentialsTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation
import Testing
@testable import asa

@Suite("Credentials")
struct CredentialsTests {
    @Test("IDs in the format the Apple Ads UI shows are accepted")
    func acceptsValidIDs() throws {
        let credentials = try Credentials.validated(
            clientID: Fixtures.clientID,
            teamID: Fixtures.teamID,
            keyID: Fixtures.keyID,
            adAccountID: "123456789",
            privateKeyPEM: "PEM"
        )
        #expect(credentials.clientID.rawValue == Fixtures.clientID)
        #expect(credentials.teamID.rawValue == Fixtures.teamID)
        #expect(credentials.keyID.rawValue == Fixtures.keyID)
        #expect(credentials.adAccountID.rawValue == "123456789")
        #expect(credentials.privateKeyPEM == "PEM")
    }

    @Test(
        "Malformed or mixed-up IDs are a credentials error naming the field",
        arguments: [
            ("27478e71-3bb0-4588-998c-182e2b405577", Fixtures.teamID, Fixtures.keyID, "1", "client_id"),
            (Fixtures.clientID, "", Fixtures.keyID, "1", "team_id"),
            (Fixtures.clientID, Fixtures.teamID, Fixtures.clientID, "1", "key_id"),
            (Fixtures.clientID, Fixtures.teamID, Fixtures.keyID, "", "ad_account_id"),
            (Fixtures.clientID, Fixtures.teamID, Fixtures.keyID, "org 1", "ad_account_id"),
        ]
    )
    func rejectsInvalidIDs(clientID: String, teamID: String, keyID: String, adAccountID: String, field: String) {
        #expect {
            try Credentials.validated(
                clientID: clientID,
                teamID: teamID,
                keyID: keyID,
                adAccountID: adAccountID,
                privateKeyPEM: "PEM"
            )
        } throws: { error in
            guard let error = error as? CLIError, case let .credentials(message) = error else {
                return false
            }
            return message.hasPrefix(field)
        }
    }

    @Test("Credentials never print the private key")
    func credentialsRedactKey() {
        let credentials = Credentials(
            clientID: Credentials.ClientID(rawValue: Fixtures.clientID),
            teamID: Credentials.TeamID(rawValue: Fixtures.teamID),
            keyID: Credentials.KeyID(rawValue: Fixtures.keyID),
            adAccountID: Credentials.AdAccountID(rawValue: "1"),
            privateKeyPEM: "SECRET"
        )
        #expect(!"\(credentials)".contains("SECRET"))
        #expect(!String(reflecting: credentials).contains("SECRET"))
    }
}
