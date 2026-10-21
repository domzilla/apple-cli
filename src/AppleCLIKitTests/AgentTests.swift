//
//  AgentTests.swift
//  AppleCLIKitTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation
import Testing
@testable import AppleCLIKit

@Suite("Agent")
struct AgentTests {
    @Test(
        "TTLs accept seconds, minutes and hours",
        arguments: [("90s", 90.0), ("30m", 1800.0), ("2h", 7200.0), ("1s", 1.0)]
    )
    func parsesTTL(_ input: String, _ expected: TimeInterval) throws {
        #expect(try Agent.parseTTL(input) == expected)
    }

    @Test("Malformed or non-positive TTLs are rejected", arguments: ["", "30", "m", "0m", "-5m", "1.5h", "2d", "1h30m"])
    func rejectsTTL(_ input: String) {
        #expect(throws: CLIError.self) {
            try Agent.parseTTL(input)
        }
    }

    @Test("Messages larger than a pipe buffer survive a socket round trip, and the socket is private")
    func socketRoundTrip() throws {
        let directory = URL(fileURLWithPath: "/tmp/asc-test-\(getpid())-\(UInt32.random(in: 0...UInt32.max))")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("s.sock").path

        let listener = try UnixSocket.listen(at: path)
        defer { close(listener) }
        let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)

        let echo = Thread {
            let connection = accept(listener, nil, nil)
            guard connection >= 0 else {
                return
            }
            if UnixSocket.isSameUser(connection), let data = try? UnixSocket.readAll(connection) {
                try? UnixSocket.writeAll(connection, Data(data.reversed()))
            }
            close(connection)
        }
        echo.start()

        let message = Data((0..<1_000_000).map { UInt8($0 % 251) })
        let client = try UnixSocket.connect(to: path)
        defer { close(client) }
        try UnixSocket.writeAll(client, message)
        shutdown(client, SHUT_WR)
        #expect(try UnixSocket.readAll(client) == Data(message.reversed()))
    }

    @Test("Sending without a running agent names the tool's start command, with exit code 6")
    func sendWithoutAgent() throws {
        let directory = URL(fileURLWithPath: "/tmp/asc-test-missing-\(getpid())")
        let error = #expect(throws: CLIError.self) {
            try Agent(name: "asa", directory: directory).send(AgentRequest(command: .status))
        }
        guard case .agentNotRunning(tool: "asa") = try #require(error) else {
            Issue.record("expected .agentNotRunning(tool: asa), got \(String(describing: error))")
            return
        }
        #expect(error?.exitCode == 6)
        #expect(error?.description.contains("`asa agent start --credentials <op://Vault/Item>`") == true)
    }

    @Test("The default socket lives in the tool's own cache folder")
    func socketPathPerTool() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].path
        #expect(Agent(name: "asc").socketPath == caches + "/asc/agent.sock")
        #expect(Agent(name: "asa").socketPath == caches + "/asa/agent.sock")
    }

    @Test("Status lists the credentials reference, the server's fields and the expiry, aligned")
    func statusFormat() {
        struct Fields: AgentServer {
            var statusFields: [(label: String, value: String)] {
                [("key_id", "K1"), ("ad_account_id", "42")]
            }

            func perform(_: AgentRequest) async throws -> Data {
                Data()
            }
        }
        let connection = AgentConnection(
            agent: Agent(name: "asa"),
            server: Fields(),
            reference: "op://Ads/Key",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let lines = connection.status.split(separator: "\n")
        #expect(lines.count == 5)
        #expect(lines[0] == "agent running (pid \(getpid()))")
        #expect(lines[1] == "credentials:   op://Ads/Key")
        #expect(lines[2] == "key_id:        K1")
        #expect(lines[3] == "ad_account_id: 42")
        #expect(lines[4].hasPrefix("expires:       2033-05-18T03:33:20Z (in "))
    }

    @Test("Responses take exit code and message from CLIError")
    func responseFromCLIError() {
        let response = AgentResponse(error: CLIError.blocked("no"))
        #expect(response.exitCode == 3)
        #expect(response.message == "BLOCKED: no. This operation is prohibited and was not sent.")
        #expect(response.body == nil)
    }

    @Test("Errors from outside the tools map to exit code 1 with their own text")
    func responseFromForeignError() {
        struct ForeignError: Error, CustomStringConvertible {
            var description: String {
                "disk on fire"
            }
        }
        let response = AgentResponse(error: ForeignError())
        #expect(response.exitCode == 1)
        #expect(response.message == "disk on fire")
    }
}
