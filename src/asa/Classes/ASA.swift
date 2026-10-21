//
//  ASA.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

@main
enum ASA {
    static let usage = """
    asa – Apple Ads Platform API client.

    USAGE
      asa --version
      asa agent start --credentials <\(OnePassword.referencePlaceholder)> [--ttl <duration>]
      asa agent status
      asa agent stop
      asa <GET|POST|PUT|DELETE> <path> [options]

    AGENT
      Requests go through a background agent that holds the API key in memory. Starting it reads the key from
      1Password (one approval) and requests an access token. It stops after --ttl (default \
    \(Int(Agent.defaultTTL / 60))m; e.g. 90s, 45m, 2h)
      or on `asa agent stop`. The 1Password item needs client_id, team_id, key_id, ad_account_id and the attachment
      private-key.pem. Every request is scoped to that ad account (X-AP-Context) except org-level endpoints.

    REQUEST OPTIONS
      --body <file|->      JSON request body from a file or stdin (POST/PUT/DELETE)
      --paginate           POST .../query only: walk pagination.offset to totalCount and merge all rows
      --out <file>         Write the response to a file instead of stdout

    <path> is /v1/... with an optional query, or a full https://\(APIClient.host) URL.

    EXIT CODES
      0 ok · \(CLIError.failure("").exitCode) API or other error · \(CLIError.usage("").exitCode) usage · \
    \(CLIError.credentials("").exitCode) credentials · \(CLIError.agent("").exitCode) agent not running or failed
    """

    static let agent = Agent(name: "asa")

    static func main() async {
        await CLI.main(tool: "asa", run: self.run)
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
            CLI.write("asa \(CLI.version)\n")
        case "agent":
            try await CLI.runAgent(
                self.agent,
                Array(arguments.dropFirst()),
                load: { reference in
                    let credentials = try Credentials.load(from: reference)
                    _ = try await AccessToken.fetch(for: credentials)
                    return credentials
                },
                makeServer: { Server(credentials: $0) }
            )
        default:
            guard let method = HTTPMethod(argument: command) else {
                throw CLIError.usage("unknown command '\(command)'\n\n\(self.usage)")
            }
            try CLI.runRequest(self.agent, method: method.rawValue, Array(arguments.dropFirst()))
        }
    }
}
