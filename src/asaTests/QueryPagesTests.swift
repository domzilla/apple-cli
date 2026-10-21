//
//  QueryPagesTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation
import Testing
@testable import asa

@Suite("QueryPages")
struct QueryPagesTests {
    static let entityPath = "/v1/campaigns/find"
    static let reportPath = "/v1/reports/campaigns"

    static func page(_ ids: [Int], offset: Int, totalCount: Int?) -> Data {
        var pagination: [String: Any] = ["offset": offset, "pageSize": ids.count]
        pagination["totalCount"] = totalCount
        let document: [String: Any] = ["result": ids.map { ["id": $0] }, "pagination": pagination]
        return try! JSONSerialization.data(withJSONObject: document)
    }

    static func offset(of body: Data?) throws -> Int? {
        let body = try Fixtures.json(#require(body))
        return (body["pagination"] as? [String: Any])?["offset"] as? Int
    }

    @Test("Entity pages ask for totalCount, are requested by offset until it and merged in order")
    func walksEntityPages() throws {
        let body = Data(
            #"{"filters":[{"field":"status","operator":"EQUALS","value":"ENABLED"}],"pagination":{"pageSize":2}}"#
                .utf8
        )
        var pages = try QueryPages(path: Self.entityPath, body: body)

        let firstBody = try pages.nextBody()
        let first = try Fixtures.json(#require(firstBody))
        #expect((first["pagination"] as? [String: Any])?["offset"] as? Int == 0)
        #expect((first["pagination"] as? [String: Any])?["pageSize"] as? Int == 2)
        #expect((first["pagination"] as? [String: Any])?["fetchTotalCount"] as? Bool == true)
        #expect((first["filters"] as? [Any])?.count == 1)
        try pages.add(Self.page([1, 2], offset: 0, totalCount: 5))

        #expect(try Self.offset(of: pages.nextBody()) == 2)
        try pages.add(Self.page([3, 4], offset: 2, totalCount: 5))
        #expect(try Self.offset(of: pages.nextBody()) == 4)
        try pages.add(Self.page([5], offset: 4, totalCount: 5))
        #expect(try pages.nextBody() == nil)

        let merged = try Fixtures.json(pages.merged())
        let ids = (merged["result"] as? [[String: Any]])?.compactMap { $0["id"] as? Int }
        #expect(ids == [1, 2, 3, 4, 5])
        let pagination = try #require(merged["pagination"] as? [String: Any])
        #expect(pagination["offset"] as? Int == 0)
        #expect(pagination["pageSize"] as? Int == 5)
        #expect(pagination["totalCount"] as? Int == 5)
    }

    @Test("Report rows in result.rows are merged and the first page's grand total is kept")
    func mergesReportRows() throws {
        func report(_ rows: [String], offset: Int) -> Data {
            let document: [String: Any] = [
                "result": [
                    "rows": rows.map { ["metadata": ["campaignName": $0]] },
                    "summary": ["grandTotal": ["impressions": 900]],
                ],
                "pagination": ["offset": offset, "pageSize": rows.count, "totalCount": 3],
            ]
            return try! JSONSerialization.data(withJSONObject: document)
        }
        var pages = try QueryPages(path: Self.reportPath, body: Data(#"{"pagination":{"offset":0,"pageSize":2}}"#.utf8))
        _ = try pages.nextBody()
        try pages.add(report(["A", "B"], offset: 0))
        _ = try pages.nextBody()
        try pages.add(report(["C"], offset: 2))
        #expect(try pages.nextBody() == nil)

        let result = try #require(Fixtures.json(pages.merged())["result"] as? [String: Any])
        let names = (result["rows"] as? [[String: Any]])?.compactMap {
            ($0["metadata"] as? [String: Any])?["campaignName"] as? String
        }
        #expect(names == ["A", "B", "C"])
        #expect(((result["summary"] as? [String: Any])?["grandTotal"] as? [String: Any])?["impressions"] as? Int == 900)
    }

    @Test("A body without pagination, or none at all, starts at offset 0")
    func defaultsOffset() throws {
        #expect(try Self.offset(of: QueryPages(path: Self.entityPath, body: nil).nextBody()) == 0)
        #expect(try Self.offset(of: QueryPages(path: Self.entityPath, body: Data()).nextBody()) == 0)
        #expect(try Self
            .offset(of: QueryPages(path: Self.entityPath, body: Data(#"{"filters":[]}"#.utf8)).nextBody()) == 0)
    }

    @Test("A starting offset is respected and reported in the merged pagination")
    func startOffset() throws {
        var pages = try QueryPages(
            path: Self.entityPath,
            body: Data(#"{"pagination":{"offset":10,"pageSize":2}}"#.utf8)
        )
        #expect(try Self.offset(of: pages.nextBody()) == 10)
        try pages.add(Self.page([11, 12], offset: 10, totalCount: 12))
        #expect(try pages.nextBody() == nil)
        let pagination = try #require(Fixtures.json(pages.merged())["pagination"] as? [String: Any])
        #expect(pagination["offset"] as? Int == 10)
        #expect(pagination["pageSize"] as? Int == 2)
    }

    @Test("An empty page ends the walk even if totalCount promised more")
    func emptyPageEnds() throws {
        var pages = try QueryPages(path: Self.entityPath, body: nil)
        _ = try pages.nextBody()
        try pages.add(Self.page([1], offset: 0, totalCount: 10))
        _ = try pages.nextBody()
        try pages.add(Self.page([], offset: 1, totalCount: 10))
        #expect(try pages.nextBody() == nil)
        #expect(try (Fixtures.json(pages.merged())["result"] as? [Any])?.count == 1)
    }

    @Test("A report body doesn't get fetchTotalCount")
    func reportOmitsFetchTotalCount() throws {
        let body = Data(#"{"pagination":{"offset":0,"pageSize":2}}"#.utf8)
        let nextBody = try QueryPages(path: Self.reportPath, body: body).nextBody()
        let next = try Fixtures.json(#require(nextBody))
        #expect((next["pagination"] as? [String: Any])?["fetchTotalCount"] == nil)
    }

    @Test("A response without totalCount is an error")
    func requiresTotalCount() throws {
        var pages = try QueryPages(path: Self.entityPath, body: nil)
        #expect(throws: CLIError.self) {
            try pages.add(Self.page([1], offset: 0, totalCount: nil))
        }
    }

    @Test("A body that isn't a JSON object is a usage error", arguments: ["[]", "\"x\"", "{"])
    func rejectsBody(_ body: String) {
        #expect {
            try QueryPages(path: Self.entityPath, body: Data(body.utf8))
        } throws: { error in
            guard let error = error as? CLIError, case .usage = error else {
                return false
            }
            return true
        }
    }

    @Test("A response without result rows is an error")
    func rejectsResponseWithoutRows() throws {
        var pages = try QueryPages(path: Self.entityPath, body: nil)
        #expect(throws: CLIError.self) {
            try pages.add(Data(#"{"result":{"id":1},"pagination":{"totalCount":1}}"#.utf8))
        }
    }
}
