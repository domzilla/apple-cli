//
//  Server.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

struct Server: AgentServer {
    let credentials: Credentials

    var statusFields: [(label: String, value: String)] {
        [
            ("key_id", self.credentials.keyID.rawValue),
            ("issuer_id", self.credentials.issuerID.rawValue),
            ("vendor_number", self.credentials.vendorNumber ?? "<missing>"),
        ]
    }

    /// Runs the blocklist and spec gate before anything is signed.
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
        if request.isPaginated, method != .get {
            throw CLIError.usage("--paginate only works with GET")
        }
        if request.body != nil, method == .get {
            throw CLIError.usage("GET requests take no --body")
        }

        let path = try RequestPath(rawPath)
        var body = request.body
        if method.isWrite {
            if let reason = Blocklist.violation(method: method, path: path, body: body) {
                throw CLIError.blocked(reason)
            }
            body = try body.map(Blocklist.canonicalBody)
            try await Spec.shared.ensureWritesAllowed()
        }

        let client = APIClient(credentials: self.credentials)
        return request.isPaginated
            ? try await client.sendPaginated(path: path)
            : try await client.send(method: method, path: path, body: body)
    }
}
