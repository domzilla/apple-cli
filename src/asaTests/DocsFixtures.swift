//
//  DocsFixtures.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
@testable import asa

/// Trimmed copies of Apple's DocC JSON pages.
enum DocsFixtures {
    static let prefix = "doc://com.apple.apple-ads-platform-api/documentation/Apple-Ads-Platform-API/"

    static func reference(_ name: String, url: String, title: String, fragments: Bool = false) -> [String: Any] {
        var reference: [String: Any] = [
            "identifier": prefix + name,
            "role": "symbol",
            "title": title,
            "url": "/documentation/apple-ads-platform-api/\(url)",
        ]
        if fragments {
            reference["fragments"] = [["kind": "text", "text": "object "]]
        }
        return reference
    }

    static var campaignsEndpoints: [String: Any] {
        [
            "metadata": ["title": "Campaigns Endpoints", "role": "collectionGroup"],
            "topicSections": [["identifiers": [prefix + "POST-campaigns", prefix + "Get-app-campaign-reports"]]],
            "references": [
                prefix + "POST-campaigns": reference(
                    "POST-campaigns",
                    url: "post-campaigns",
                    title: "Create a Campaign"
                ),
                prefix + "Get-app-campaign-reports": reference(
                    "Get-app-campaign-reports",
                    url: "get-app-campaign-reports",
                    title: "Campaigns Report"
                ),
            ],
        ]
    }

    static var campaignsDataObjects: [String: Any] {
        [
            "metadata": ["title": "Campaigns Data Objects", "role": "collectionGroup"],
            "topicSections": [["identifiers": [prefix + "CampaignCreate"]]],
            "references": [
                prefix + "CampaignCreate": reference(
                    "CampaignCreate",
                    url: "campaigncreate",
                    title: "CampaignCreate",
                    fragments: true
                ),
            ],
        ]
    }

    static var postCampaigns: [String: Any] {
        [
            "metadata": ["title": "Create a Campaign"],
            "abstract": [["type": "text", "text": "Create a new advertising campaign."]],
            "primaryContentSections": [
                [
                    "kind": "restEndpoint",
                    "tokens": [
                        ["kind": "method", "text": "POST"],
                        ["kind": "text", "text": " "],
                        ["kind": "baseURL", "text": "https://api.ads.apple.com/v1/"],
                        ["kind": "path", "text": "campaigns"],
                    ],
                ],
                [
                    "kind": "restParameters",
                    "source": "header",
                    "items": [["name": "X-Ap-Context", "required": true, "type": [["kind": "text", "text": "string"]]]],
                ],
                [
                    "kind": "restBody",
                    "mimeType": "application/json",
                    "bodyContentType": [[
                        "identifier": prefix + "CampaignCreate",
                        "kind": "typeIdentifier",
                        "text": "CampaignCreate",
                    ]],
                ],
                [
                    "kind": "restResponses",
                    "items": [
                        [
                            "status": 200,
                            "reason": "OK",
                            "type": [["identifier": prefix + "CampaignResponse", "text": "CampaignResponse"]],
                        ],
                        ["status": 400, "reason": "Bad Request", "type": [["text": "ErrorResponse"]]],
                    ],
                ],
                [
                    "kind": "content",
                    "content": [
                        ["type": "heading", "level": 2, "text": "Discussion"],
                        ["type": "codeListing", "syntax": "json", "code": ["{\"budgetAmount\": {}}"]],
                        ["type": "heading", "level": 2, "text": "Payload Examples"],
                        [
                            "type": "tabNavigator",
                            "tabs": [
                                [
                                    "title": "App Store Search",
                                    "content": [
                                        ["type": "heading", "level": 3, "text": "Request"],
                                        ["type": "paragraph", "inlineContent": [["type": "text", "text": "Search."]]],
                                        [
                                            "type": "codeListing",
                                            "syntax": "json",
                                            "code": ["POST /v1/campaigns", "", "{", " \"name\": \"Search\"", "}"],
                                        ],
                                        ["type": "heading", "level": 3, "text": "Response"],
                                        ["type": "codeListing", "syntax": "json", "code": ["{\"result\": {}}"]],
                                    ],
                                ],
                                [
                                    "title": "Today Tab",
                                    "content": [
                                        ["type": "heading", "level": 3, "text": "Request"],
                                        ["type": "codeListing", "syntax": "json", "code": ["{\"name\": \"Today\"}"]],
                                        ["type": "heading", "level": 3, "text": "Response"],
                                        ["type": "codeListing", "syntax": "json", "code": ["{\"result\": {}}"]],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            "references": [
                prefix + "CampaignCreate": reference("CampaignCreate", url: "campaigncreate", title: "CampaignCreate"),
            ],
        ]
    }

    static var applyDailyBudgetRecommendations: [String: Any] {
        [
            "metadata": ["title": "Apply Daily Budget Recommendations"],
            "primaryContentSections": [
                [
                    "kind": "restEndpoint",
                    "tokens": [
                        ["kind": "method", "text": "POST"],
                        ["kind": "baseURL", "text": "https://api.ads.apple.com/v1/"],
                        ["kind": "path", "text": "recommendations/daily-budgets/apply"],
                    ],
                ],
                [
                    "kind": "restBody",
                    "mimeType": "application/json",
                    "bodyContentType": [
                        ["kind": "text", "text": "["],
                        [
                            "identifier": prefix + "ApplyDailyCapRecommendation",
                            "kind": "typeIdentifier",
                            "text": "ApplyDailyCapRecommendation",
                        ],
                        ["kind": "text", "text": "]"],
                    ],
                ],
            ],
            "references": [
                prefix + "ApplyDailyCapRecommendation": reference(
                    "ApplyDailyCapRecommendation",
                    url: "applydailycaprecommendation",
                    title: "ApplyDailyCapRecommendation"
                ),
            ],
        ]
    }

    static var applyDailyCapRecommendation: [String: Any] {
        [
            "metadata": ["title": "ApplyDailyCapRecommendation"],
            "primaryContentSections": [[
                "kind": "properties",
                "items": [["name": "id", "required": true, "type": [["kind": "text", "text": "string"]]]],
            ]],
        ]
    }

    static var getCampaign: [String: Any] {
        [
            "metadata": ["title": "Get a Campaign"],
            "primaryContentSections": [
                [
                    "kind": "restEndpoint",
                    "tokens": [
                        ["kind": "method", "text": "GET"],
                        ["kind": "baseURL", "text": "https://api.ads.apple.com/v1/"],
                        ["kind": "path", "text": "campaigns/"],
                        ["kind": "parameter", "text": "{id}"],
                    ],
                ],
                [
                    "kind": "restParameters",
                    "source": "path",
                    "items": [["name": "id", "required": true, "type": [["kind": "text", "text": "string"]]]],
                ],
            ],
        ]
    }

    static var campaignCreate: [String: Any] {
        [
            "metadata": ["title": "CampaignCreate"],
            "primaryContentSections": [[
                "kind": "properties",
                "items": [
                    [
                        "name": "name",
                        "required": true,
                        "type": [["kind": "text", "text": "string"]],
                        "content": [[
                            "type": "paragraph",
                            "inlineContent": [
                                ["type": "text", "text": "The name. See "],
                                ["type": "reference", "identifier": prefix + "Naming"],
                                ["type": "text", "text": ", max "],
                                ["type": "codeVoice", "code": "200"],
                                ["type": "text", "text": "."],
                            ],
                        ]],
                    ],
                    [
                        "name": "status",
                        "type": [[
                            "identifier": prefix + "CampaignStatus",
                            "kind": "typeIdentifier",
                            "text": "CampaignStatus",
                        ]],
                    ],
                    [
                        "name": "billingEvent",
                        "required": true,
                        "type": [["kind": "text", "text": "string"]],
                        "attributes": [["kind": "allowedValues", "values": ["TAPS", "IMPRESSIONS"]]],
                    ],
                    [
                        "name": "parent",
                        "type": [[
                            "identifier": prefix + "CampaignCreate",
                            "kind": "typeIdentifier",
                            "text": "CampaignCreate",
                        ]],
                    ],
                ],
            ]],
            "references": [
                prefix + "CampaignStatus": reference("CampaignStatus", url: "campaignstatus", title: "CampaignStatus"),
                prefix + "CampaignCreate": reference("CampaignCreate", url: "campaigncreate", title: "CampaignCreate"),
                prefix + "Naming": reference("Naming", url: "naming", title: "Naming Rules"),
            ],
        ]
    }

    static var campaignStatus: [String: Any] {
        [
            "metadata": ["title": "CampaignStatus"],
            "abstract": [["type": "text", "text": "Run state."]],
            "primaryContentSections": [[
                "kind": "possibleValues",
                "values": [["name": "ENABLED"], ["name": "PAUSED"]],
            ]],
        ]
    }

    static var pages: [String: [String: Any]] {
        [
            "post-campaigns": postCampaigns,
            "get-campaigns-_id_": getCampaign,
            "campaigncreate": campaignCreate,
            "campaignstatus": campaignStatus,
            "apply-daily-budget-recommendations": applyDailyBudgetRecommendations,
            "applydailycaprecommendation": applyDailyCapRecommendation,
        ]
    }

    static func loadPage(_ name: String) async throws -> [String: Any] {
        guard let page = self.pages[name] else {
            throw URLError(.fileDoesNotExist)
        }
        return page
    }
}
