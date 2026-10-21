//
//  CLIError.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// The errors of both tools. Each case maps to an exit code.
public enum CLIError: Error, CustomStringConvertible {
    /// Wrong arguments; the message explains the correct usage.
    case usage(String)
    /// A path that isn't a strict API path.
    case invalidPath(String)
    /// A request the blocklist refuses.
    case blocked(String)
    /// Writes are disabled until a changed API spec is reviewed.
    case specGate(String)
    /// The key couldn't be read from 1Password or is invalid.
    case credentials(String)
    /// The background agent failed.
    case agent(String)
    /// No agent is running for the tool with this name.
    case agentNotRunning(tool: String)
    /// The API answered with a non-2xx status.
    case api(status: Int, body: Data)
    /// Any other error.
    case failure(String)

    /// Wraps errors from outside the tools as `.failure`, so every error has an exit code.
    public init(_ error: any Error) {
        self = error as? CLIError ?? .failure("\(error)")
    }

    /// Distinct exit codes let agents tell a refused request apart from an API error.
    public var exitCode: Int32 {
        switch self {
        case .usage, .invalidPath:
            2
        case .blocked:
            3
        case .specGate:
            4
        case .credentials:
            5
        case .agent, .agentNotRunning:
            6
        case .api, .failure:
            1
        }
    }

    /// The message printed after the tool's name.
    public var description: String {
        switch self {
        case let .usage(message):
            message
        case let .invalidPath(message):
            "Invalid path: \(message)"
        case let .blocked(reason):
            "BLOCKED: \(reason). This operation is prohibited and was not sent."
        case let .specGate(message):
            "Writes disabled: \(message)"
        case let .credentials(message):
            "Credentials: \(message)"
        case let .agent(message):
            "Agent: \(message)"
        case let .agentNotRunning(tool):
            "Agent: no agent running; start one with "
                + "`\(tool) agent start --credentials <\(OnePassword.referencePlaceholder)>`"
        case let .api(status, body):
            "HTTP \(status)\n\(String(decoding: body, as: UTF8.self))"
        case let .failure(message):
            message
        }
    }
}
