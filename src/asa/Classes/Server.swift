//
//  Server.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

struct Server: AgentServer {
    /// What `agent start` hands the agent: the credentials and the token it fetched to check them.
    struct Startup: Codable {
        let credentials: Credentials
        let accessToken: AccessToken
    }

    let credentials: Credentials
    let tokens: AccessTokenProvider

    init(credentials: Credentials, accessToken: AccessToken? = nil) {
        self.credentials = credentials
        self.tokens = AccessTokenProvider(token: accessToken) {
            try await AccessToken.fetch(for: credentials)
        }
    }

    var statusFields: [(label: String, value: String)] {
        [
            ("client_id", self.credentials.clientID.rawValue),
            ("team_id", self.credentials.teamID.rawValue),
            ("key_id", self.credentials.keyID.rawValue),
            ("ad_account_id", self.credentials.adAccountID.rawValue),
        ]
    }

    /// Checks the method, path, `--paginate` and `--body` before a token is used or anything is sent.
    func perform(_ request: AgentRequest) async throws -> Data {
        guard let rawMethod = request.method else {
            throw CLIError.usage("missing method")
        }
        guard let method = HTTPMethod(argument: rawMethod) else {
            throw CLIError.usage("unsupported method '\(rawMethod)'")
        }
        guard let rawPath = request.path else {
            throw CLIError.usage("missing path")
        }
        let path = try RequestPath(rawPath)
        if request.isPaginated, method != .post || path.segments.last != "query" {
            throw CLIError.usage("--paginate only works with POST .../query")
        }
        if request.body != nil, method == .get {
            throw CLIError.usage("GET requests take no --body")
        }

        let client = APIClient(adAccountID: self.credentials.adAccountID, tokens: self.tokens)
        return request.isPaginated
            ? try await client.sendPaginated(path: path, body: request.body)
            : try await client.send(method: method, path: path, body: request.body)
    }
}
