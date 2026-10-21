//
//  RequestPath.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// A validated API path plus query. The path is kept strict (no percent-encoding, no dot segments) so the
/// blocklist sees exactly the resource the server will act on, and requests can only go to the tool's API host.
public struct RequestPath: Equatable, Sendable {
    /// The API host every request goes to.
    public let host: String
    /// The path, such as `/v1/apps`.
    public let path: String
    /// The decoded query parameters.
    public let queryItems: [URLQueryItem]

    /// Accepts `/v1/apps?limit=200` or a full `https://<host>/...` URL, such as a pagination link.
    public init(_ raw: String, host: String) throws {
        var remainder = Substring(raw)
        let prefix = "https://\(host)/"
        if raw.hasPrefix("https://") || raw.hasPrefix("http://") {
            guard raw.hasPrefix(prefix) else {
                throw CLIError.invalidPath("only https://\(host) is allowed")
            }
            remainder = raw.dropFirst(prefix.count - 1)
        }
        guard !remainder.contains("#") else {
            throw CLIError.invalidPath("fragments are not allowed")
        }

        let parts = remainder.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(parts[0])
        guard path.range(of: "^/v[0-9]+(/[A-Za-z0-9_.-]+)+$", options: .regularExpression) != nil else {
            throw CLIError.invalidPath("'\(path)' must look like /v1/resource[/id...] using only A-Z, a-z, 0-9, _ . -")
        }
        guard !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw CLIError.invalidPath("dot segments are not allowed")
        }
        self.host = host
        self.path = path
        self.queryItems = parts.count > 1 ? try Self.queryItems(String(parts[1])) : []
    }

    // MARK: Public

    /// The path split at `/`, such as `["v1", "apps"]`.
    public var segments: [Substring] {
        self.path.split(separator: "/")
    }

    /// The full request URL.
    public var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = self.host
        components.path = self.path
        if !self.queryItems.isEmpty {
            components.percentEncodedQueryItems = self.queryItems.map {
                URLQueryItem(name: Self.encode($0.name), value: $0.value.map(Self.encode))
            }
        }
        return components.url!
    }

    // MARK: Private

    /// Stricter than URLComponents' default, which leaves `+` unencoded.
    private static func encode(_ string: String) -> String {
        let unreserved =
            CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: unreserved)!
    }

    private static func queryItems(_ query: String) throws -> [URLQueryItem] {
        try query.split(separator: "&").map { pair in
            let nameValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let name = String(nameValue[0]).removingPercentEncoding, !name.isEmpty else {
                throw CLIError.invalidPath("malformed query parameter '\(pair)'")
            }
            var value: String?
            if nameValue.count > 1 {
                guard let decoded = String(nameValue[1]).removingPercentEncoding else {
                    throw CLIError.invalidPath("malformed query value in '\(pair)'")
                }
                value = decoded
            }
            return URLQueryItem(name: name, value: value)
        }
    }
}
