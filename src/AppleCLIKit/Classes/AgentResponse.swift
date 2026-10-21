//
//  AgentResponse.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// The agent's answer to an `AgentRequest`.
public struct AgentResponse: Codable, Sendable {
    /// The exit code the command line exits with.
    public var exitCode: Int32
    /// A status or error message.
    public var message: String?
    /// The API response body.
    public var body: Data?

    /// A response with the given fields.
    public init(exitCode: Int32, message: String? = nil, body: Data? = nil) {
        self.exitCode = exitCode
        self.message = message
        self.body = body
    }

    /// A failed response with the error's exit code and message.
    public init(error: any Error) {
        let error = CLIError(error)
        self.init(exitCode: error.exitCode, message: error.description)
    }
}
