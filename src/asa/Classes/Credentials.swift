//
//  Credentials.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

/// An Apple Ads API key, loaded from a 1Password item that has the fields `client_id`, `team_id`, `key_id`,
/// `ad_account_id` and the attached file `private-key.pem`.
struct Credentials: Codable, CustomStringConvertible {
    struct ClientID: Codable {
        let rawValue: String
    }

    struct TeamID: Codable {
        let rawValue: String
    }

    struct KeyID: Codable {
        let rawValue: String
    }

    struct AdAccountID: Codable {
        let rawValue: String
    }

    let clientID: ClientID
    let teamID: TeamID
    let keyID: KeyID
    let adAccountID: AdAccountID
    let privateKeyPEM: String

    var description: String {
        "Credentials(clientID: \(self.clientID.rawValue), teamID: \(self.teamID.rawValue), "
            + "keyID: \(self.keyID.rawValue), adAccountID: \(self.adAccountID.rawValue), privateKey: <redacted>)"
    }

    // MARK: Public

    static func load(from itemReference: String) throws -> Credentials {
        let item = try OnePassword.validatedItemReference(itemReference)
        let op = try OnePassword()
        return try self.validated(
            clientID: op.read("\(item)/client_id"),
            teamID: op.read("\(item)/team_id"),
            keyID: op.read("\(item)/key_id"),
            adAccountID: op.read("\(item)/ad_account_id"),
            privateKeyPEM: op.read("\(item)/private-key.pem")
        )
    }

    /// Checks the IDs against the formats the Apple Ads UI shows, so a field mix-up fails before the first request.
    static func validated(
        clientID: String,
        teamID: String,
        keyID: String,
        adAccountID: String,
        privateKeyPEM: String
    ) throws
        -> Credentials
    {
        let searchAdsID = "^SEARCHADS\\.[A-Za-z0-9-]+$"
        guard clientID.range(of: searchAdsID, options: .regularExpression) != nil else {
            throw CLIError.credentials("client_id must look like SEARCHADS.<id>")
        }
        guard teamID.range(of: searchAdsID, options: .regularExpression) != nil else {
            throw CLIError.credentials("team_id must look like SEARCHADS.<id>")
        }
        guard UUID(uuidString: keyID) != nil else {
            throw CLIError.credentials("key_id must be a UUID")
        }
        guard adAccountID.range(of: "^[0-9]+$", options: .regularExpression) != nil else {
            throw CLIError.credentials("ad_account_id must be a number")
        }
        return Credentials(
            clientID: ClientID(rawValue: clientID),
            teamID: TeamID(rawValue: teamID),
            keyID: KeyID(rawValue: keyID),
            adAccountID: AdAccountID(rawValue: adAccountID),
            privateKeyPEM: privateKeyPEM
        )
    }
}
