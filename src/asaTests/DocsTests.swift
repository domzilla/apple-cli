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
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return Docs(cacheDirectory: directory, baseURL: URL(string: "http://127.0.0.1:9/docs")!)
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
            .write(to: docs.cacheDirectory.appendingPathComponent("campaigncreate~status-data.dictionary.json"))
        let page = try await docs.page("campaigncreate/status-data.dictionary")
        #expect(DocsPage(page).title == "Cached")
    }

    @Test("A stale cached page is used when the download fails, and no cache is an error")
    func staleCache() async throws {
        let docs = try Self.docs()
        defer { try? FileManager.default.removeItem(at: docs.cacheDirectory) }
        let url = docs.cacheDirectory.appendingPathComponent("post-campaigns.json")
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
}
