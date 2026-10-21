//
//  DocsLookup.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

/// `asa spec find` and `asa spec show`, on the endpoint index and pages of `Docs`.
struct DocsLookup {
    static let maxDepth = 6

    let endpoints: [DocsEndpoint]
    let loadPage: (String) async throws -> [String: Any]

    // MARK: Public

    /// One line per endpoint whose method, path or title contains every term.
    func find(_ terms: [String]) -> [String] {
        self.endpoints.filter { endpoint in
            let haystack = "\(endpoint.method) \(endpoint.path) \(endpoint.title)".lowercased()
            return terms.allSatisfy { haystack.contains($0.lowercased()) }
        }
        .map { "\($0.method) \($0.path)  \($0.title)" }
    }

    /// Parameters, the request body with its fields resolved, and the response types of one endpoint. `path` may be
    /// the template (`/v1/campaigns/{id}`) or a concrete path (`/v1/campaigns/123`).
    func show(method argument: String, path: String) async throws -> String {
        guard let endpoint = self.endpoint(method: argument.uppercased(), path: path) else {
            throw CLIError.usage("no \(argument.uppercased()) \(path) in the documentation; try `asa spec find <term>`")
        }
        let page = try await DocsPage(self.loadPage(endpoint.page))

        var result: [String: Any] = [
            "operation": "\(endpoint.method) \(endpoint.path)",
            "title": endpoint.title,
            "summary": page.abstract,
        ]
        var parameters = [[String: Any]]()
        for parameter in page.parameters {
            var field = parameter.field.merging(["name": parameter.name]) { $1 }
            if let typePage = parameter.typePage {
                try await field.merge(self.resolve(typePage, depth: 1, seen: [])) { current, _ in current }
            }
            parameters.append(field)
        }
        if !parameters.isEmpty {
            result["parameters"] = parameters
        }
        if let body = page.bodyType {
            var requestBody: [String: Any] = ["type": body.name]
            if let bodyPage = body.page {
                try await requestBody.merge(self.resolve(bodyPage, depth: 0, seen: [])) { $1 }
            }
            result["requestBody"] = requestBody
        }
        if !page.responses.isEmpty {
            result["responses"] = page.responses
        }
        return try Self.json(result)
    }

    /// The fields or values of a data object, such as `CampaignCreate` or `CampaignStatus`.
    func show(object name: String) async throws -> String {
        let pageName = Self.pageName(object: name)
        let page = try await DocsPage(self.loadPage(pageName))
        var result: [String: Any] = ["object": page.title, "summary": page.abstract]
        try await result.merge(self.resolve(page: page, depth: 0, seen: [pageName])) { $1 }
        return try Self.json(result)
    }

    /// `campaigncreate` for `CampaignCreate`, `campaigncreate/dailybudget-data.dictionary` for
    /// `CampaignCreate.DailyBudget`.
    static func pageName(object name: String) -> String {
        let parts = name.lowercased().split(separator: ".", maxSplits: 1)
        return parts.count == 2 ? "\(parts[0])/\(parts[1])-data.dictionary" : name.lowercased()
    }

    // MARK: Private

    private func endpoint(method: String, path: String) -> DocsEndpoint? {
        let segments = path.split(separator: "?")[0].split(separator: "/")
        let candidates = self.endpoints.filter { $0.method == method }
        if let exact = candidates.first(where: { $0.path == path }) {
            return exact
        }
        // Prefer literal segments over parameters, so /v1/campaigns/query isn't read as /v1/campaigns/{id}.
        return candidates.filter { endpoint in
            let template = endpoint.path.split(separator: "/")
            return template.count == segments.count && zip(template, segments).allSatisfy {
                $0 == $1 || ($0.hasPrefix("{") && $0.hasSuffix("}"))
            }
        }
        .min { $0.path.filter { $0 == "{" }.count < $1.path.filter { $0 == "{" }.count }
    }

    private func resolve(_ pageName: String, depth: Int, seen: Set<String>) async throws -> [String: Any] {
        guard depth < Self.maxDepth, !seen.contains(pageName), let json = try? await self.loadPage(pageName) else {
            return [:]
        }
        return try await self.resolve(page: DocsPage(json), depth: depth, seen: seen.union([pageName]))
    }

    /// Inlines the fields of nested object types up to a depth limit; recursive types stay as their name.
    private func resolve(page: DocsPage, depth: Int, seen: Set<String>) async throws -> [String: Any] {
        if !page.possibleValues.isEmpty {
            return ["values": page.possibleValues]
        }
        var properties = [String: Any]()
        for property in page.properties {
            var field = property.field
            if let typePage = property.typePage {
                try await field.merge(self.resolve(typePage, depth: depth + 1, seen: seen)) { current, _ in current }
            }
            properties[property.name] = field
        }
        return properties.isEmpty ? [:] : ["properties": properties]
    }

    private static func json(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self)
    }
}
