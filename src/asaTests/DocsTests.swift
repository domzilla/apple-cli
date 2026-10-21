//
//  DocsTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import AppleCLIKit
@testable import asa

@Suite("Docs")
struct DocsTests {
    /// Port 9 on localhost refuses connections, so a download fails without leaving the machine.
    static func docs() throws -> Docs {
        let directory = URL(fileURLWithPath: "/tmp/asa-test-docs-\(getpid())-\(UInt32.random(in: 0...UInt32.max))")
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent(Docs.pagesDirectoryName),
            withIntermediateDirectories: true
        )
        return Docs(cacheDirectory: directory, baseURL: URL(string: "http://127.0.0.1:9/docs")!)
    }

    /// Serves a root page linking one topic, which lists `post-campaigns` and `get-app-campaign-reports`; every
    /// page but those two and the root fails with `status`.
    static func docs(failingWith status: Int) throws -> Docs {
        var docs = try Self.docs()
        docs.load = { url in
            let root: [String: Any] = [
                "topicSections": [["identifiers": [DocsFixtures.prefix + "Campaigns-Endpoints"]]],
                "references": [
                    DocsFixtures.prefix + "Campaigns-Endpoints": DocsFixtures.reference(
                        "Campaigns-Endpoints",
                        url: "campaigns-endpoints",
                        title: "Campaigns Endpoints"
                    ),
                ],
            ]
            let pages = [
                "docs": root,
                "campaigns-endpoints": DocsFixtures.campaignsEndpoints,
                "post-campaigns": DocsFixtures.postCampaigns,
            ]
            let page = pages[url.deletingPathExtension().lastPathComponent]
            let response = HTTPURLResponse(
                url: url,
                statusCode: page == nil ? status : 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return try (page.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data(), response)
        }
        return docs
    }

    @Test(
        "Page names that could leave the documentation are rejected",
        arguments: ["../x", "a/../b", "A", "x y", "x?y"]
    )
    func rejectsPageName(_ name: String) async throws {
        let docs = try Self.docs()
        defer { try? FileManager.default.removeItem(at: docs.cacheDirectory) }
        await #expect {
            try await docs.page(name)
        } throws: { error in
            guard let error = error as? CLIError, case .usage = error else {
                return false
            }
            return true
        }
    }

    @Test("A fresh cached page is used without a download")
    func freshCache() async throws {
        let docs = try Self.docs()
        defer { try? FileManager.default.removeItem(at: docs.cacheDirectory) }
        try Data(#"{"metadata":{"title":"Cached"}}"#.utf8)
            .write(to: docs.cacheDirectory.appendingPathComponent(
                Docs.pagesDirectoryName + "/campaigncreate~status-data.dictionary.json"
            ))
        let page = try await docs.page("campaigncreate/status-data.dictionary")
        #expect(DocsPage(page).title == "Cached")
    }

    @Test("A stale cached page is used when the download fails, and no cache is an error")
    func staleCache() async throws {
        let docs = try Self.docs()
        defer { try? FileManager.default.removeItem(at: docs.cacheDirectory) }
        let url = docs.cacheDirectory.appendingPathComponent(Docs.pagesDirectoryName + "/post-campaigns.json")
        try Data(#"{"metadata":{"title":"Stale"}}"#.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-2 * Docs.checkInterval)],
            ofItemAtPath: url.path
        )
        #expect(try await DocsPage(docs.page("post-campaigns")).title == "Stale")
        await #expect(throws: (any Error).self) {
            try await docs.page("get-campaigns-_id_")
        }
    }

    @Test("A stale index is used when rebuilding it fails")
    func staleIndex() async throws {
        let docs = try Self.docs()
        defer { try? FileManager.default.removeItem(at: docs.cacheDirectory) }
        let endpoint = DocsEndpoint(method: "GET", path: "/v1/me", title: "Get Me Details", page: "get-me")
        let url = docs.cacheDirectory.appendingPathComponent(Docs.indexFileName)
        try JSONEncoder().encode([endpoint]).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-2 * Docs.checkInterval)],
            ofItemAtPath: url.path
        )
        #expect(try await docs.index() == [endpoint])
    }

    @Test("A page that fails with a server error keeps the stale index and writes none")
    func partialIndex() async throws {
        let docs = try Self.docs(failingWith: 500)
        defer { try? FileManager.default.removeItem(at: docs.cacheDirectory) }
        let endpoint = DocsEndpoint(method: "GET", path: "/v1/me", title: "Get Me Details", page: "get-me")
        let url = docs.cacheDirectory.appendingPathComponent(Docs.indexFileName)
        let stale = try JSONEncoder().encode([endpoint])
        try stale.write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-2 * Docs.checkInterval)],
            ofItemAtPath: url.path
        )
        #expect(try await docs.index() == [endpoint])
        #expect(try Data(contentsOf: url) == stale)
    }

    @Test("A missing page is left out of the index")
    func missingPage() async throws {
        let docs = try Self.docs(failingWith: 404)
        defer { try? FileManager.default.removeItem(at: docs.cacheDirectory) }
        let endpoint = DocsEndpoint(
            method: "POST",
            path: "/v1/campaigns",
            title: "Create a Campaign",
            page: "post-campaigns"
        )
        #expect(try await docs.index() == [endpoint])
        let url = docs.cacheDirectory.appendingPathComponent(Docs.indexFileName)
        #expect(try JSONDecoder().decode([DocsEndpoint].self, from: Data(contentsOf: url)) == [endpoint])
    }
}
