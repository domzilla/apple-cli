//
//  CLI.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// The command-line side both tools share: error handling, `agent` subcommands and API requests.
public enum CLI {
    // MARK: Public

    /// The version from the Info.plist embedded in the binary.
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    /// Runs the tool and exits with the error's exit code on failure.
    public static func main(tool: String, run: ([String]) async throws -> Void) async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            let error = CLIError(error)
            self.writeError("\(tool): \(error)")
            exit(error.exitCode)
        }
    }

    /// `agent start|status|stop|serve`. `load` reads and checks the credentials before the agent starts.
    public static func runAgent<Credentials: Codable>(
        _ agent: Agent,
        _ arguments: [String],
        load: (String) async throws -> Credentials,
        makeServer: (Credentials) -> any AgentServer
    ) async throws {
        switch arguments.first {
        case "start":
            var reference: String?
            var ttl = Agent.defaultTTL
            var iterator = arguments.dropFirst().makeIterator()
            while let argument = iterator.next() {
                switch argument {
                case "--credentials":
                    reference = try self.value(after: argument, &iterator)
                case "--ttl":
                    ttl = try Agent.parseTTL(self.value(after: argument, &iterator))
                default:
                    throw CLIError.usage("unexpected argument '\(argument)'")
                }
            }
            guard let reference else {
                throw CLIError.usage("missing --credentials <\(OnePassword.referencePlaceholder)>")
            }
            try await self.write(agent.start(reference: reference, ttl: ttl, load: load) + "\n")
        case "status":
            let response = try agent.send(AgentRequest(command: .status))
            guard response.exitCode == 0 else {
                self.writeError("\(agent.name): \(response.message ?? "failed")")
                exit(response.exitCode)
            }
            self.write((response.message ?? "") + "\n")
        case "stop":
            // Stopping an agent that already expired is not an error.
            let response = try? agent.send(AgentRequest(command: .stop))
            self.write((response?.message ?? "no agent running") + "\n")
        case "serve":
            try await agent.serve(Credentials.self, makeServer: makeServer)
        default:
            throw CLIError.usage("usage: \(agent.name) agent start|status|stop")
        }
    }

    /// `<METHOD> <path> [--body <file|->] [--paginate] [--out <file>]`, sent through the agent.
    public static func runRequest(_ agent: Agent, method: String, _ arguments: [String]) throws {
        var path: String?
        var bodySource: String?
        var outPath: String?
        var isPaginated = false

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--body":
                bodySource = try self.value(after: argument, &iterator)
            case "--out":
                outPath = try self.value(after: argument, &iterator)
            case "--paginate":
                isPaginated = true
            default:
                guard path == nil, !argument.hasPrefix("--") else {
                    throw CLIError.usage("unexpected argument '\(argument)'")
                }
                path = argument
            }
        }
        guard let path else {
            throw CLIError.usage("missing <path>")
        }

        let request = try AgentRequest(
            command: .request,
            method: method,
            path: path,
            body: bodySource.map(self.readBody),
            isPaginated: isPaginated
        )
        let response = try agent.send(request)
        guard response.exitCode == 0 else {
            self.writeError("\(agent.name): \(response.message ?? "failed")")
            exit(response.exitCode)
        }

        let body = response.body ?? Data()
        if let outPath {
            try body.write(to: URL(fileURLWithPath: outPath), options: .atomic)
            self.writeError("\(agent.name): wrote \(body.count) bytes to \(outPath)")
        } else {
            FileHandle.standardOutput.write(body)
        }
    }

    /// The value following `option`, or a usage error.
    public static func value(after option: String, _ iterator: inout some IteratorProtocol<String>) throws -> String {
        guard let value = iterator.next() else {
            throw CLIError.usage("\(option) needs a value")
        }
        return value
    }

    /// Writes to stdout.
    public static func write(_ string: String) {
        FileHandle.standardOutput.write(Data(string.utf8))
    }

    /// Writes a line to stderr.
    public static func writeError(_ string: String) {
        FileHandle.standardError.write(Data((string + "\n").utf8))
    }

    // MARK: Private

    private static func readBody(_ source: String) throws -> Data {
        if source == "-" {
            return FileHandle.standardInput.readDataToEndOfFile()
        }
        // FileHandle also reads pipes such as `--body <(...)`, which Data(contentsOf:) refuses.
        guard let handle = FileHandle(forReadingAtPath: source) else {
            throw CLIError.usage("can't read --body \(source)")
        }
        defer { try? handle.close() }
        return try handle.readToEnd() ?? Data()
    }
}
