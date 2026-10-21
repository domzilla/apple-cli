//
//  QueryPages.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

/// Walks the pages of a `POST .../query` request by advancing `pagination.offset` until `totalCount` is reached, and
/// merges the rows. Entity queries return rows in `result`, reports in `result.rows`.
struct QueryPages {
    private var body: [String: Any]
    private var offset: Int
    private var totalCount: Int?
    private var firstPage: [String: Any]?
    private var rows = [Any]()
    private let startOffset: Int

    init(body: Data?) throws {
        let object = try body.flatMap { $0.isEmpty ? nil : try JSONSerialization.jsonObject(with: $0) } ?? [:]
        guard let body = object as? [String: Any] else {
            throw CLIError.usage("--paginate needs a JSON object body")
        }
        self.body = body
        self.startOffset = (body["pagination"] as? [String: Any])?["offset"] as? Int ?? 0
        self.offset = self.startOffset
    }

    // MARK: Public

    /// The body for the next page, or `nil` when all rows are in.
    func nextBody() throws -> Data? {
        if let totalCount = self.totalCount, self.offset >= totalCount {
            return nil
        }
        var body = self.body
        var pagination = body["pagination"] as? [String: Any] ?? [:]
        pagination["offset"] = self.offset
        body["pagination"] = pagination
        return try JSONSerialization.data(withJSONObject: body)
    }

    mutating func add(_ page: Data) throws {
        guard let document = try JSONSerialization.jsonObject(with: page) as? [String: Any] else {
            throw CLIError.failure("expected a JSON object from the query")
        }
        guard let pageRows = Self.rows(in: document) else {
            throw CLIError.failure("the query response has no result rows to paginate")
        }
        guard let totalCount = (document["pagination"] as? [String: Any])?["totalCount"] as? Int else {
            throw CLIError.usage(
                "--paginate needs pagination.totalCount in the response; "
                    + "add \"fetchTotalCount\": true to the body's pagination"
            )
        }
        if self.firstPage == nil {
            self.firstPage = document
        }
        self.rows += pageRows
        self.totalCount = totalCount
        // An empty page ends the walk even if totalCount promised more, so a shrinking result can't loop forever.
        self.offset = pageRows.isEmpty ? totalCount : self.offset + pageRows.count
    }

    /// The first page with every page's rows and pagination covering all of them.
    func merged() throws -> Data {
        guard var document = self.firstPage else {
            throw CLIError.failure("no pages were fetched")
        }
        if var result = document["result"] as? [String: Any] {
            result["rows"] = self.rows
            document["result"] = result
        } else {
            document["result"] = self.rows
        }
        document["pagination"] = [
            "offset": self.startOffset,
            "pageSize": self.rows.count,
            "totalCount": self.totalCount ?? self.rows.count,
        ]
        return try JSONSerialization.data(
            withJSONObject: document,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    // MARK: Private

    private static func rows(in document: [String: Any]) -> [Any]? {
        if let rows = document["result"] as? [Any] {
            return rows
        }
        return (document["result"] as? [String: Any])?["rows"] as? [Any]
    }
}
