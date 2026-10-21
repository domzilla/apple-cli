//
//  URLSession+Uncached.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

extension URLSession {
    /// Ephemeral and without a URL cache: API responses (sales data, user lists, ad spend) must never be written to
    /// disk.
    public static let uncached: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()
}
