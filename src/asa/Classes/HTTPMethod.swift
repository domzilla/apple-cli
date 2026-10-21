//
//  HTTPMethod.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// The methods the Apple Ads Platform API uses. Updates are PUT; lists and reports are POST to `.../query`.
enum HTTPMethod: String, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"

    init?(argument: String) {
        self.init(rawValue: argument.uppercased())
    }
}
