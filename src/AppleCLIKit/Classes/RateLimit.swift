//
//  RateLimit.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// The 429 retry policy shared by `asc` and `asa`.
public enum RateLimit {
    /// How often a request is retried after a 429 before the error is passed on.
    public static let maxRetries = 5
    /// Upper bound for the exponential backoff used when the server names no wait.
    public static let maxBackoff: TimeInterval = 16
    /// Upper bound for a wait the server names, so a bogus header can't stall a command.
    public static let maxServerWait: TimeInterval = 300

    // MARK: Public

    /// Waits `delay(for:attempt:)` and returns `true` if `response` is a 429 and retries are left. `attempt` counts
    /// the retries of one request and starts at 0.
    public static func waitBeforeRetry(_ response: HTTPURLResponse, attempt: inout Int) async throws -> Bool {
        guard response.statusCode == 429, attempt < self.maxRetries else {
            return false
        }
        attempt += 1
        try await Task.sleep(for: .seconds(self.delay(for: response, attempt: attempt)))
        return true
    }

    /// `Retry-After`, else `RateLimit-Reset` (bounded at `maxServerWait`), else `2^attempt` seconds capped at
    /// `maxBackoff`.
    public static func delay(for response: HTTPURLResponse, attempt: Int) -> TimeInterval {
        let header = response.value(forHTTPHeaderField: "Retry-After")
            ?? response.value(forHTTPHeaderField: "RateLimit-Reset")
        if let delay = header.flatMap(TimeInterval.init) {
            return min(max(delay, 0), self.maxServerWait)
        }
        return min(pow(2, Double(attempt)), self.maxBackoff)
    }
}
