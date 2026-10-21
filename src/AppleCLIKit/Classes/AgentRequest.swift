//
//  AgentRequest.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// A message from the command line to the agent.
public struct AgentRequest: Codable, Sendable {
    /// What the agent should do.
    public enum Command: String, Codable, Sendable {
        case request
        case status
        case stop
    }

    /// What the agent should do.
    public var command: Command
    /// The HTTP method as typed, such as `GET`. Each tool decides which methods it supports.
    public var method: String?
    /// The raw path, validated by the agent.
    public var path: String?
    /// The request body.
    public var body: Data?
    /// Whether to follow pagination and merge all pages.
    public var isPaginated = false

    /// A request with the given fields.
    public init(
        command: Command,
        method: String? = nil,
        path: String? = nil,
        body: Data? = nil,
        isPaginated: Bool = false
    ) {
        self.command = command
        self.method = method
        self.path = path
        self.body = body
        self.isPaginated = isPaginated
    }
}
