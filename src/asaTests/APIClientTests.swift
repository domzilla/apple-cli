//
//  APIClientTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import AppleCLIKit
@testable import asa

@Suite("APIClient")
struct APIClientTests {
    static let account = Credentials.AdAccountID(rawValue: "42")

    /// Answers each request with the next status and its index as the body, and records the bearer tokens sent.
    actor Transport {
        private let statuses: [Int]
        private(set) var authorizations = [String?]()

        init(statuses: [Int]) {
            self.statuses = statuses
        }

        func respond(_ request: URLRequest) -> (Data, URLResponse) {
            let index = self.authorizations.count
            self.authorizations.append(request.value(forHTTPHeaderField: "Authorization"))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: self.statuses[index],
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("response-\(index)".utf8), response)
        }
    }

    static func client(_ transport: Transport, tokens: AccessTokenProviderTests.TokenSource) -> APIClient {
        var client = APIClient(adAccountID: self.account, tokens: AccessTokenProvider { try await tokens.next() })
        client.load = { await transport.respond($0) }
        return client
    }

    static func context(_ method: HTTPMethod, _ path: String) throws -> String? {
        try APIClient.context(method: method, path: RequestPath(path), adAccountID: self.account)
    }

    @Test(
        "Ad account endpoints carry X-AP-Context: adAccountId=<id>",
        arguments: [
            (HTTPMethod.get, "/v1/campaigns/1"),
            (.post, "/v1/campaigns/query"),
            (.put, "/v1/adgroups/7"),
            (.delete, "/v1/keywords/9"),
            (.get, "/v1/ad-accounts/42"),
            (.put, "/v1/ad-accounts/42"),
            (.post, "/v1/reports/apps/campaigns/query"),
            (.post, "/v1/shared-budgets/query"),
            (.get, "/v1/shared-budgets/5"),
            (.get, "/v1/me/extra"),
        ]
    )
    func adAccountContext(_ method: HTTPMethod, _ path: String) throws {
        #expect(try Self.context(method, path) == "adAccountId=42")
    }

    @Test(
        "Org-level endpoints and budget order writes go without X-AP-Context",
        arguments: [
            (HTTPMethod.get, "/v1/me"),
            (.get, "/v1/acls"),
            (.get, "/v1/orgs/27154130"),
            (.get, "/v1/advertiser-resources?resourceType=CONTENT_PROVIDER"),
            (.post, "/v1/ad-accounts"),
            (.post, "/v1/shared-budgets"),
            (.put, "/v1/shared-budgets/5"),
            (.delete, "/v1/shared-budgets/5"),
        ]
    )
    func orgContext(_ method: HTTPMethod, _ path: String) throws {
        #expect(try Self.context(method, path) == nil)
    }

    @Test("A 401 drops the token and retries once with a new one")
    func retriesUnauthorizedWithNewToken() async throws {
        let transport = Transport(statuses: [401, 200])
        let tokens = AccessTokenProviderTests.TokenSource()
        let data = try await Self.client(transport, tokens: tokens)
            .send(method: .get, path: RequestPath("/v1/campaigns"), body: nil)
        #expect(data == Data("response-1".utf8))
        #expect(await transport.authorizations == ["Bearer token-1", "Bearer token-2"])
        #expect(await tokens.fetchCount == 2)
    }

    @Test("A second 401 is not retried and fails with the API error")
    func failsOnRepeatedUnauthorized() async throws {
        let transport = Transport(statuses: [401, 401, 200])
        let tokens = AccessTokenProviderTests.TokenSource()
        await #expect {
            try await Self.client(transport, tokens: tokens)
                .send(method: .get, path: RequestPath("/v1/campaigns"), body: nil)
        } throws: { error in
            guard let error = error as? CLIError, case let .api(status, body) = error else {
                return false
            }
            return status == 401 && body == Data("response-1".utf8)
        }
        #expect(await transport.authorizations == ["Bearer token-1", "Bearer token-2"])
        #expect(await tokens.fetchCount == 2)
    }
}
