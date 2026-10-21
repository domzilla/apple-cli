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

    static func context(_ method: HTTPMethod, _ path: String) throws -> String? {
        try APIClient.context(method: method, path: RequestPath(path, host: APIClient.host), adAccountID: self.account)
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
}
