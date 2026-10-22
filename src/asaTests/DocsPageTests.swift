//
//  DocsPageTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import asa

@Suite("DocsPage")
struct DocsPageTests {
    @Test("Endpoint topics are symbols without declaration fragments; data objects have fragments")
    func endpointPages() {
        #expect(DocsPage(DocsFixtures.campaignsEndpoints).endpointPages.sorted() == [
            "get-app-campaign-reports",
            "post-campaigns",
        ])
        #expect(DocsPage(DocsFixtures.campaignsDataObjects).endpointPages.isEmpty)
        #expect(DocsPage(DocsFixtures.campaignsDataObjects).topicPages == ["campaigncreate"])
    }

    @Test("The endpoint's method and path come from the URL tokens, with path parameters kept as templates")
    func endpoint() {
        #expect(DocsPage(DocsFixtures.postCampaigns).endpoint(page: "post-campaigns") == DocsEndpoint(
            method: "POST",
            path: "/v1/campaigns",
            title: "Create a Campaign",
            page: "post-campaigns"
        ))
        #expect(DocsPage(DocsFixtures.getCampaign).endpoint(page: "get-campaigns-_id_")?.path == "/v1/campaigns/{id}")
        #expect(DocsPage(DocsFixtures.campaignCreate).endpoint(page: "campaigncreate") == nil)
    }

    @Test("Parameters leave out the X-AP-Context header that asa sets")
    func parameters() {
        #expect(DocsPage(DocsFixtures.postCampaigns).parameters.isEmpty)
        let parameters = DocsPage(DocsFixtures.getCampaign).parameters
        #expect(parameters.map(\.name) == ["id"])
        #expect(parameters.first?.field["in"] as? String == "path")
        #expect(parameters.first?.field["required"] as? Bool == true)
    }

    @Test("Body type and responses are read with their type names")
    func bodyAndResponses() {
        let page = DocsPage(DocsFixtures.postCampaigns)
        #expect(page.bodyType?.name == "CampaignCreate")
        #expect(page.bodyType?.page == "campaigncreate")
        #expect(page.responses == ["200": "CampaignResponse", "400": "ErrorResponse"])
    }

    @Test("Request examples are the code listings under Request headings, in page order, without responses")
    func requestExamples() {
        #expect(DocsPage(DocsFixtures.postCampaigns).requestExamples == [
            "POST /v1/campaigns\n\n{\n \"name\": \"Search\"\n}",
            "{\"name\": \"Today\"}",
        ])
        #expect(DocsPage(DocsFixtures.getCampaign).requestExamples.isEmpty)
    }

    @Test("Descriptions are plain text with code in backticks and references as their titles")
    func descriptionText() throws {
        let name = try #require(DocsPage(DocsFixtures.campaignCreate).properties.first)
        #expect(name.field["description"] as? String == "The name. See Naming Rules, max `200`.")
        #expect(name.field["required"] as? Bool == true)
        #expect(name.typePage == nil)
    }

    @Test("Allowed values and enumeration values are read")
    func values() {
        let properties = DocsPage(DocsFixtures.campaignCreate).properties
        #expect(properties.first { $0.name == "billingEvent" }?.field["values"] as? [String] == ["TAPS", "IMPRESSIONS"])
        #expect(properties.first { $0.name == "status" }?.typePage == "campaignstatus")
        #expect(DocsPage(DocsFixtures.campaignStatus).possibleValues == ["ENABLED", "PAUSED"])
    }
}
