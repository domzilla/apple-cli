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
            switch request.command {
            case .status:
                response = AgentResponse(exitCode: 0, message: self.status)
            case .stop:
                isStopping = true
                response = AgentResponse(exitCode: 0, message: "agent stopped")
            case .request:
                do {
                    response = try await AgentResponse(exitCode: 0, body: self.server.perform(request))
                } catch {
                    response = AgentResponse(error: error)
                }
            }
        } catch {
            response = AgentResponse(error: CLIError.agent("invalid request: \(error)"))
        }

        try? UnixSocket.writeAll(fd, JSONEncoder().encode(response))
        if isStopping {
            self.agent.shutDown()
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
