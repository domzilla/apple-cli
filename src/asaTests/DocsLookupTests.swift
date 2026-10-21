//
//  DocsLookupTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import AppleCLIKit
@testable import asa

@Suite("DocsLookup")
struct DocsLookupTests {
    struct PageRequested: Error, Equatable {
        let name: String
    }

    static let endpoints = [
        DocsEndpoint(method: "POST", path: "/v1/campaigns", title: "Create a Campaign", page: "post-campaigns"),
        DocsEndpoint(
            method: "POST",
            path: "/v1/campaigns/query",
            title: "Query Campaigns",
            page: "post-campaigns-query"
        ),
        DocsEndpoint(method: "GET", path: "/v1/campaigns/{id}", title: "Get a Campaign", page: "get-campaigns-_id_"),
        DocsEndpoint(method: "POST", path: "/v1/campaigns/{id}", title: "Fictional", page: "post-campaigns-_id_"),
        DocsEndpoint(method: "POST", path: "/v1/keywords/bulk-create", title: "Bulk Create Keywords", page: "x"),
    ]

    static var lookup: DocsLookup {
        DocsLookup(endpoints: endpoints, loadPage: DocsFixtures.loadPage)
    }

    static func json(_ string: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any])
    }

    @Test("Every term must match the method, path or title, ignoring case")
    func find() {
        #expect(Self.lookup.find(["campaign", "query"]) == ["POST /v1/campaigns/query  Query Campaigns"])
        #expect(Self.lookup.find(["BULK"]) == ["POST /v1/keywords/bulk-create  Bulk Create Keywords"])
        #expect(Self.lookup.find(["get", "campaign"]) == ["GET /v1/campaigns/{id}  Get a Campaign"])
        #expect(Self.lookup.find(["nothing"]).isEmpty)
    }

    @Test("A concrete path finds its template, and a literal segment wins over a parameter")
    func templateMatching() async throws {
        let get = try await Self.json(Self.lookup.show(method: "get", path: "/v1/campaigns/123"))
        #expect(get["operation"] as? String == "GET /v1/campaigns/{id}")
        let parameters = try #require(get["parameters"] as? [[String: Any]])
        #expect(parameters.map { $0["name"] as? String } == ["id"])

        let recording = DocsLookup(endpoints: Self.endpoints) { throw PageRequested(name: $0) }
        await #expect(throws: PageRequested(name: "post-campaigns-query")) {
            try await recording.show(method: "POST", path: "/v1/campaigns/query")
        }
    }

    @Test("Show resolves the body's fields, nested types and enum values, and stops at recursive types")
    func showBody() async throws {
        let result = try await Self.json(Self.lookup.show(method: "POST", path: "/v1/campaigns"))
        #expect(result["operation"] as? String == "POST /v1/campaigns")
        #expect(result["title"] as? String == "Create a Campaign")
        #expect(result["summary"] as? String == "Create a new advertising campaign.")
        #expect(result["parameters"] == nil)
        #expect(result["responses"] as? [String: String] == ["200": "CampaignResponse", "400": "ErrorResponse"])

        let body = try #require(result["requestBody"] as? [String: Any])
        #expect(body["type"] as? String == "CampaignCreate")
        let properties = try #require(body["properties"] as? [String: [String: Any]])
        #expect(properties.keys.sorted() == ["billingEvent", "name", "parent", "status"])
        #expect(properties["status"]?["values"] as? [String] == ["ENABLED", "PAUSED"])
        #expect(properties["status"]?["type"] as? String == "CampaignStatus")
        #expect(properties["parent"]?["type"] as? String == "CampaignCreate")
        #expect(properties["parent"]?["properties"] == nil)
    }

    @Test("A method or path that isn't documented is a usage error")
    func showUnknown() async {
        await #expect {
            try await Self.lookup.show(method: "PATCH", path: "/v1/campaigns/1")
        } throws: { error in
            guard let error = error as? CLIError, case .usage = error else {
                return false
            }
            return true
        }
    }

    @Test("Objects are shown by name, and nested type names map to their page")
    func showObject() async throws {
        let status = try await Self.json(Self.lookup.show(object: "CampaignStatus"))
        #expect(status["object"] as? String == "CampaignStatus")
        #expect(status["values"] as? [String] == ["ENABLED", "PAUSED"])
        #expect(DocsLookup.pageName(object: "CampaignCreate") == "campaigncreate")
        #expect(DocsLookup
            .pageName(object: "CampaignCreate.DailyBudget") == "campaigncreate/dailybudget-data.dictionary")
    }

    @Test("An object shown by name doesn't expand a property that refers back to itself")
    func showRecursiveObject() async throws {
        let result = try await Self.json(Self.lookup.show(object: "CampaignCreate"))
        let properties = try #require(result["properties"] as? [String: [String: Any]])
        #expect(properties["parent"]?["type"] as? String == "CampaignCreate")
        #expect(properties["parent"]?["properties"] == nil)
    }
}
