//
//  ServerTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import AppleCLIKit
@testable import asa

/// Every case here fails before a token is requested, so nothing reaches the network.
@Suite("Server")
struct ServerTests {
    @Test(
        "Invalid requests are usage errors",
        arguments: [
            AgentRequest(command: .request, path: "/v1/me"),
            AgentRequest(command: .request, method: "PATCH", path: "/v1/campaigns/1"),
            AgentRequest(command: .request, method: "GET"),
            AgentRequest(command: .request, method: "GET", path: "/v1/campaigns/query", isPaginated: true),
            AgentRequest(command: .request, method: "POST", path: "/v1/campaigns", isPaginated: true),
            AgentRequest(command: .request, method: "GET", path: "/v1/me", body: Data("{}".utf8)),
        ]
    )
    func rejectsRequest(_ request: AgentRequest) async {
        await #expect {
            try await Server(credentials: Fixtures.credentials()).perform(request)
        } throws: { error in
            guard let error = error as? CLIError, case .usage = error else {
                return false
            }
            return true
        }
    }

    @Test("Requests can only go to the Apple Ads API host")
    func rejectsOtherHosts() async {
        let request = AgentRequest(command: .request, method: "GET", path: "https://example.com/v1/me")
        await #expect {
            try await Server(credentials: Fixtures.credentials()).perform(request)
        } throws: { error in
            guard let error = error as? CLIError, case .invalidPath = error else {
                return false
            }
            return true
        }
    }

    @Test("Status shows the IDs but never the private key")
    func statusFields() {
        let server = Server(credentials: Fixtures.credentials())
        #expect(server.statusFields.map(\.label) == ["client_id", "team_id", "key_id", "ad_account_id"])
        #expect(server.statusFields.map(\.value) == [Fixtures.clientID, Fixtures.teamID, Fixtures.keyID, "123456789"])
        #expect(!server.statusFields.contains { $0.value.contains("PRIVATE KEY") })
    }
}
