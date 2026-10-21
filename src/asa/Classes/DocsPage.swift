//
//  DocsPage.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// Reads the parts of a DocC JSON page that `asa spec` needs.
struct DocsPage {
    let json: [String: Any]

    init(_ json: [String: Any]) {
        self.json = json
    }

    // MARK: Public

    var title: String {
        (self.json["metadata"] as? [String: Any])?["title"] as? String ?? ""
    }

    var abstract: String {
        self.text(self.json["abstract"])
    }

    /// The page names of the topics this page links to.
    var topicPages: [String] {
        self.topicIdentifiers.compactMap(self.pageName)
    }

    /// The topics that are endpoints: symbols without declaration fragments, which data objects have.
    var endpointPages: [String] {
        self.topicIdentifiers
            .filter { self.references[$0]?["role"] as? String == "symbol" && self.references[$0]?["fragments"] == nil }
            .compactMap(self.pageName)
    }

    /// The endpoint this page (named `page`) documents, or `nil` if it isn't an endpoint page.
    func endpoint(page: String) -> DocsEndpoint? {
        guard
            let section = self.sections.first(where: { $0["kind"] as? String == "restEndpoint" }),
            let tokens = section["tokens"] as? [[String: Any]],
            let method = tokens.first(where: { $0["kind"] as? String == "method" })?["text"] as? String,
            let baseURL = tokens.first(where: { $0["kind"] as? String == "baseURL" })?["text"] as? String,
            let base = URL(string: baseURL) else
        {
            return nil
        }
        let path = tokens.filter { ["path", "parameter"].contains($0["kind"] as? String) }
            .compactMap { $0["text"] as? String }
            .joined()
        return DocsEndpoint(
            method: method,
            path: base.path + (base.path.hasSuffix("/") ? "" : "/") + path,
            title: self.title,
            page: page
        )
    }

    /// Path and query parameters, without the `X-AP-Context` header that `asa` sets.
    var parameters: [(name: String, field: [String: Any], typePage: String?)] {
        self.sections.filter { $0["kind"] as? String == "restParameters" }.flatMap { section in
            let source = section["source"] as? String ?? ""
            return self.fields(section["items"])
                .filter { $0.name.lowercased() != "x-ap-context" }
                .map { ($0.name, $0.field.merging(["in": source]) { $1 }, $0.typePage) }
        }
    }

    /// The type of the JSON body, such as `CampaignCreate`, and its page.
    var bodyType: (name: String, page: String?)? {
        guard
            let section = self.sections.first(where: { $0["kind"] as? String == "restBody" }),
            let tokens = section["bodyContentType"] as? [[String: Any]],
            let token = tokens.first(where: { $0["identifier"] != nil }) ?? tokens.first else
        {
            return nil
        }
        return (token["text"] as? String ?? "", (token["identifier"] as? String).flatMap(self.pageName))
    }

    /// Status code to response type, such as `"200": "CampaignResponse"`.
    var responses: [String: String] {
        let items = self.sections.first { $0["kind"] as? String == "restResponses" }?["items"] as? [[String: Any]]
        var responses = [String: String]()
        for item in items ?? [] {
            let status = (item["status"] as? Int).map(String.init) ?? "?"
            let type = self.typeName(item["type"])
            responses[status] = type.isEmpty ? item["reason"] as? String ?? "" : type
        }
        return responses
    }

    /// The fields of an object page: name to type, `required`, description, allowed values, and the page of the
    /// field's type for resolving it.
    var properties: [(name: String, field: [String: Any], typePage: String?)] {
        self.fields(self.sections.first { $0["kind"] as? String == "properties" }?["items"])
    }

    /// The values of an enumeration page.
    var possibleValues: [String] {
        let values = self.sections.first { $0["kind"] as? String == "possibleValues" }?["values"] as? [[String: Any]]
        return (values ?? []).compactMap { $0["name"] as? String }
    }

    /// `post-campaigns` from `/documentation/apple-ads-platform-api/post-campaigns`.
    static func pageName(url: String) -> String {
        let prefix = "/documentation/apple-ads-platform-api/"
        return url.hasPrefix(prefix) ? String(url.dropFirst(prefix.count)) : url
    }

    // MARK: Private

    private var sections: [[String: Any]] {
        self.json["primaryContentSections"] as? [[String: Any]] ?? []
    }

    private var references: [String: [String: Any]] {
        self.json["references"] as? [String: [String: Any]] ?? [:]
    }

    private var topicIdentifiers: [String] {
        let sections = self.json["topicSections"] as? [[String: Any]] ?? []
        return sections.flatMap { $0["identifiers"] as? [String] ?? [] }
    }

    private func pageName(_ identifier: String) -> String? {
        guard
            let url = self.references[identifier]?["url"] as? String,
            url.hasPrefix("/documentation/apple-ads-platform-api/") else
        {
            return nil
        }
        return Self.pageName(url: url)
    }

    private func fields(_ items: Any?) -> [(name: String, field: [String: Any], typePage: String?)] {
        (items as? [[String: Any]] ?? []).map { item in
            let typePage = (item["type"] as? [[String: Any]])?
                .compactMap { $0["identifier"] as? String }.first
                .flatMap(self.pageName)
            return (item["name"] as? String ?? "", self.property(item), typePage)
        }
    }

    private func property(_ item: [String: Any]) -> [String: Any] {
        var field: [String: Any] = ["type": self.typeName(item["type"])]
        if item["required"] as? Bool == true {
            field["required"] = true
        }
        let description = self.text(item["content"])
        if !description.isEmpty {
            field["description"] = description
        }
        let values = (item["attributes"] as? [[String: Any]] ?? []).flatMap { $0["values"] as? [String] ?? [] }
        if !values.isEmpty {
            field["values"] = values
        }
        return field
    }

    private func typeName(_ tokens: Any?) -> String {
        (tokens as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
    }

    /// Flattens DocC inline content to plain text, with code in backticks and links as their titles.
    private func text(_ node: Any?) -> String {
        if let items = node as? [[String: Any]] {
            let separator = items.first?["type"] as? String == "paragraph" ? " " : ""
            return items.map { self.text($0) }.joined(separator: separator)
        }
        guard let item = node as? [String: Any] else {
            return ""
        }
        switch item["type"] as? String {
        case "text":
            return item["text"] as? String ?? ""
        case "codeVoice":
            return "`\(item["code"] as? String ?? "")`"
        case "reference":
            let identifier = item["identifier"] as? String ?? ""
            return self.references[identifier]?["title"] as? String
                ?? String(identifier.split(separator: "/").last ?? "")
        default:
            return self.text(item["inlineContent"] ?? item["content"])
        }
    }
}
