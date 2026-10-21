//
//  Docs.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppleCLIKit
import Foundation

/// Apple's documentation of the Apple Ads Platform API, read as DocC JSON. Apple publishes no OpenAPI spec for
/// it, so `asa spec` builds its endpoint index from these pages. Pages are cached and re-downloaded after 24h; a
/// failed download falls back to the cached copy.
struct Docs: Sendable {
    static let checkInterval: TimeInterval = 24 * 60 * 60
    static let indexFileName = "index.json"
    static let maxConcurrentDownloads = 8

    static let shared = Docs(
        cacheDirectory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("asa/docs"),
        baseURL: URL(string: "https://developer.apple.com/tutorials/data/documentation/apple-ads-platform-api")!
    )

    let cacheDirectory: URL
    let baseURL: URL
    var load: @Sendable (URL) async throws -> (Data, URLResponse) = { try await URLSession.uncached.data(from: $0) }

    // MARK: Public

    /// Every endpoint, from the endpoint pages linked by the documentation's topics.
    func index() async throws -> [DocsEndpoint] {
        let url = self.cacheDirectory.appendingPathComponent(Self.indexFileName)
        if
            self.isFresh(url), let endpoints = try? JSONDecoder().decode(
                [DocsEndpoint].self,
                from: Data(contentsOf: url)
            )
        {
            return endpoints
        }
        do {
            let endpoints = try await self.buildIndex()
            try self.createCacheDirectory()
            try JSONEncoder().encode(endpoints).write(to: url, options: .atomic)
            return endpoints
        } catch {
            guard let endpoints = try? JSONDecoder().decode([DocsEndpoint].self, from: Data(contentsOf: url)) else {
                throw error
            }
            return endpoints
        }
    }

    /// One page, such as `post-campaigns` or `campaigncreate/dailybudget-data.dictionary`.
    func page(_ name: String) async throws -> [String: Any] {
        try await Self.object(self.pageData(name))
    }

    // MARK: Private

    private func pageData(_ name: String) async throws -> Data {
        guard
            name.isEmpty || name.range(of: "^[a-z0-9_.()-]+(/[a-z0-9_.()-]+)*$", options: .regularExpression) != nil,
            !name.split(separator: "/").contains("..") else
        {
            throw CLIError.usage("invalid documentation page '\(name)'")
        }
        let fileName = name.isEmpty ? "root" : name.replacingOccurrences(of: "/", with: "~")
        let url = self.cacheDirectory.appendingPathComponent(fileName + ".json")
        if self.isFresh(url), let data = try? Data(contentsOf: url), (try? Self.object(data)) != nil {
            return data
        }
        do {
            let data = try await self.download(name)
            _ = try Self.object(data)
            try self.createCacheDirectory()
            try data.write(to: url, options: .atomic)
            return data
        } catch {
            guard let data = try? Data(contentsOf: url), (try? Self.object(data)) != nil else {
                throw error
            }
            return data
        }
    }

    private func isFresh(_ url: URL) -> Bool {
        guard let date = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(date) < Self.checkInterval
    }

    private func createCacheDirectory() throws {
        try FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    private func download(_ name: String) async throws -> Data {
        let url = name.isEmpty
            ? self.baseURL.appendingPathExtension("json")
            : self.baseURL.appendingPathComponent(name).appendingPathExtension("json")
        let (data, response) = try await self.load(url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw status == 404
                ? CLIError.usage("no documentation page '\(name)'; try `asa spec find <term>`")
                : CLIError.failure("downloading the documentation page '\(name)' failed with HTTP \(status)")
        }
        return data
    }

    private func buildIndex() async throws -> [DocsEndpoint] {
        let root = try await self.page("")
        let topics = DocsPage(root).topicPages
        let endpointPages = try await self.pages(topics).flatMap { DocsPage($0.json).endpointPages }
        let endpoints = try await self.pages(Array(Set(endpointPages)).sorted()).compactMap { page in
            DocsPage(page.json).endpoint(page: page.name)
        }
        guard !endpoints.isEmpty else {
            throw CLIError.failure("the documentation lists no endpoints")
        }
        return endpoints.sorted { ($0.path, $0.method) < ($1.path, $1.method) }
    }

    /// Downloads pages in parallel, a few at a time. Missing pages are left out, so one broken link doesn't break the
    /// index; any other failure throws, so `index()` keeps the cached index instead of caching a partial one.
    private func pages(_ names: [String]) async throws -> [(name: String, json: [String: Any])] {
        let pages = try await withThrowingTaskGroup(of: (String, Data)?.self) { group in
            var results = [(String, Data)]()
            var remaining = names.makeIterator()
            for _ in 0..<Self.maxConcurrentDownloads {
                if let name = remaining.next() {
                    group.addTask { try await self.existingPageData(name) }
                }
            }
            while let data = try await group.next() {
                if let data {
                    results.append(data)
                }
                if let name = remaining.next() {
                    group.addTask { try await self.existingPageData(name) }
                }
            }
            return results
        }
        return pages.compactMap { name, data in (try? Self.object(data)).map { (name, $0) } }
    }

    /// `nil` for a page that doesn't exist (404) or whose name is invalid.
    private func existingPageData(_ name: String) async throws -> (String, Data)? {
        do {
            return try await (name, self.pageData(name))
        } catch CLIError.usage {
            return nil
        }
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CLIError.failure("a documentation page is not a JSON object")
        }
        return object
    }
}
