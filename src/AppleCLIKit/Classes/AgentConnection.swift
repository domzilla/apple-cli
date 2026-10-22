//
//  AgentConnection.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation

/// Answers one connection to the agent: status and stop itself, requests through the tool's `AgentServer`.
struct AgentConnection: Sendable {
    let agent: Agent
    let server: any AgentServer
    let reference: String
    let expiresAt: Date

    // MARK: Public

    func handle(_ fd: Int32) async {
        defer { close(fd) }
        let response: AgentResponse
        var isStopping = false
        do {
            let request = try JSONDecoder().decode(AgentRequest.self, from: UnixSocket.readAll(fd))
            (response, isStopping) = await self.respond(to: request)
        } catch {
            response = AgentResponse(error: CLIError.agent("invalid request: \(error)"))
        }

        try? UnixSocket.writeAll(fd, JSONEncoder().encode(response))
        if isStopping {
            self.agent.shutDown()
        }
    }

    /// Past `expiresAt` the agent refuses everything but `stop` and shuts down, because the sleep in `Agent.serve`
    /// can fire seconds late.
    func respond(to request: AgentRequest) async -> (response: AgentResponse, isStopping: Bool) {
        if Date() >= self.expiresAt, request.command != .stop {
            return (AgentResponse(error: CLIError.agentNotRunning(tool: self.agent.name)), true)
        }
        switch request.command {
        case .status:
            return (AgentResponse(exitCode: 0, message: self.status), false)
        case .stop:
            return (AgentResponse(exitCode: 0, message: "agent stopped"), true)
        case .request:
            do {
                return try await (AgentResponse(exitCode: 0, body: self.server.perform(request)), false)
            } catch {
                return (AgentResponse(error: error), false)
            }
        }
    }

    var status: String {
        let minutes = Int(self.expiresAt.timeIntervalSinceNow / 60)
        let fields = [("credentials", self.reference)] + self.server.statusFields
            + [("expires", "\(ISO8601DateFormatter().string(from: self.expiresAt)) (in \(minutes) min)")]
        let lines = fields.map { label, value in
            let label = "\(label):"
            return label + String(repeating: " ", count: max(1, 15 - label.count)) + value
        }
        return (["agent running (pid \(getpid()))"] + lines).joined(separator: "\n")
    }
}
