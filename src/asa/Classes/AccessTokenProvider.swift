//
//  AccessTokenProvider.swift
//  asa
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// Caches the access token and fetches a new one shortly before it expires. Concurrent requests share one fetch.
actor AccessTokenProvider {
    static let refreshMargin: TimeInterval = 60

    private let credentials: Credentials
    private var cached: AccessToken?
    private var pending: Task<AccessToken, any Error>?

    init(credentials: Credentials) {
        self.credentials = credentials
    }

    // MARK: Public

    func token() async throws -> String {
        if let cached = self.cached, cached.expiresAt.timeIntervalSinceNow > Self.refreshMargin {
            return cached.value
        }
        if let pending = self.pending {
            return try await pending.value.value
        }
        let task = Task { [credentials] in
            try await AccessToken.fetch(for: credentials)
        }
        self.pending = task
        defer { self.pending = nil }
        let token = try await task.value
        self.cached = token
        return token.value
    }

    /// Drops the cached token after the API rejected it.
    func invalidate() {
        self.cached = nil
    }
}
