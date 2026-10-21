//
//  DocsEndpoint.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// One API endpoint as the documentation describes it.
struct DocsEndpoint: Codable, Equatable {
    let method: String
    /// The path template, such as `/v1/campaigns/{id}`.
    let path: String
    let title: String
    /// The documentation page, such as `get-campaigns-_id_`.
    let page: String
}
