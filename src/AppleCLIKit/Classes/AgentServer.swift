//
//  AgentServer.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// A tool's request handling inside the agent: it checks, signs and sends API requests.
public protocol AgentServer: Sendable {
    /// Non-secret details for `agent status`, as label and value, such as `("key_id", "ABCDE12345")`.
    var statusFields: [(label: String, value: String)] { get }

    /// Sends the API request and returns the response body.
    func perform(_ request: AgentRequest) async throws -> Data
}
