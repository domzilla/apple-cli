//
//  ASC.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

@main
enum ASC {
    static let usage = """
    asc – App Store Connect API client with a built-in blocklist.

    USAGE
      asc --version
      asc agent start --credentials <\(OnePassword.referencePlaceholder)> [--ttl <duration>]
      asc agent status
      asc agent stop
      asc <GET|POST|PATCH|DELETE> <path> [options]
      asc spec status [--check]
      asc spec find <term>...
      asc spec show <METHOD> <path>

    AGENT
      Requests go through a background agent that holds the API key in memory. Starting it reads the key from
      1Password (one approval). It stops after --ttl (default \(Int(Agent.defaultTTL / 60))m; e.g. 90s, 45m, 2h) or on `asc agent stop`.
      The 1Password item needs key_id, issuer_id, the attachment AuthKey_<key_id>.p8 and optionally vendor_number.

    REQUEST OPTIONS
      --body <file|->      JSON request body from a file or stdin (POST/PATCH/DELETE)
      --paginate           GET only: follow links.next and merge all pages
      --out <file>         Write the response to a file instead of stdout

    <path> is /v1/... with an optional query, or a full https://api.appstoreconnect.apple.com URL.
    Gzip responses (sales and finance reports) are decompressed.

    EXIT CODES
      0 ok · \(CLIError.failure("").exitCode) API or other error · \(CLIError.usage("").exitCode) usage · \
    \(CLIError.blocked("").exitCode) blocked · \(CLIError.specGate("").exitCode) writes disabled (spec changed) · \
    \(CLIError.credentials("").exitCode) credentials
      \(CLIError.agent("").exitCode) agent not running or failed
    """

    static let agent = Agent(name: "asc")

    static func main() async {
        await CLI.main(tool: "asc", run: self.run)
    }

    // MARK: Private

    private static func run(_ arguments: [String]) async throws {
        guard let command = arguments.first else {
            throw CLIError.usage(self.usage)
        }
        switch command {
        case "-h", "--help", "help":
            CLI.write(self.usage + "\n")
        case "-v", "--version":
            CLI.write("asc \(CLI.version)\n")
        case "agent":
            try await CLI.runAgent(
                self.agent,
                Array(arguments.dropFirst()),
                load: { reference in
                    let credentials = try Credentials.load(from: reference)
                    _ = try JWT.token(for: credentials)
                    return credentials
                },
                makeServer: { Server(credentials: $0) }
            )
        case "spec":
            try await self.runSpec(Array(arguments.dropFirst()))
        default:
            guard let method = HTTPMethod(argument: command) else {
                throw CLIError.usage("unknown command '\(command)'\n\n\(self.usage)")
            }
            try CLI.runRequest(self.agent, method: method.rawValue, Array(arguments.dropFirst()))
        }
    }

    private static func runSpec(_ arguments: [String]) async throws {
        switch arguments.first {
        case "status":
            let status = try await Spec.shared.status(shouldForceCheck: arguments.dropFirst().contains("--check"))
            CLI.write("""
            reviewed: \(Spec.reviewedVersion) \(Spec.reviewedSHA256)
            latest:   \(status.version) \(status.sha256)
            checked:  \(ISO8601DateFormatter().string(from: status.checkedAt))
            writes:   \(Spec.shared.isReviewed(status) ? "allowed" : "DISABLED until the new spec is reviewed")

            """)
        case "find":
            let terms = Array(arguments.dropFirst())
            guard !terms.isEmpty else {
                throw CLIError.usage("usage: asc spec find <term>...")
            }
            let lines = try await SpecLookup(document: Spec.shared.document()).find(terms)
            CLI.write(lines.isEmpty ? "no matches\n" : lines.joined(separator: "\n") + "\n")
        case "show":
            guard arguments.count == 3 else {
                throw CLIError.usage("usage: asc spec show <METHOD> <path>")
            }
            let lookup = try await SpecLookup(document: Spec.shared.document())
            try CLI.write(lookup.show(method: arguments[1], path: arguments[2]) + "\n")
        default:
            throw CLIError.usage("usage: asc spec status|find|show")
        }
    }
}
