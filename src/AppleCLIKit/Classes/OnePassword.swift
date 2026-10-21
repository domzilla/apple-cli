//
//  OnePassword.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Security

/// The 1Password CLI. Resolved from fixed locations and verified to be signed by AgileBits, so a planted `op` earlier
/// in PATH can't intercept the key.
public struct OnePassword {
    /// Shown in usage texts and errors.
    public static let referencePlaceholder = "op://Vault/Item"

    private static let candidatePaths = ["/opt/homebrew/bin/op", "/usr/local/bin/op"]
    private static let requirement = #"anchor apple generic and certificate leaf[subject.OU] = "2BUA8C4S2C""#
    private static let timeout: TimeInterval = 60

    private let executableURL: URL

    /// Locates `op` and verifies its signature.
    public init() throws {
        for path in Self.candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            guard Self.isSignedByAgileBits(url) else {
                throw CLIError.credentials("\(path) is not signed by 1Password (AgileBits); refusing to use it")
            }
            self.executableURL = url
            return
        }
        throw CLIError.credentials("1Password CLI not found at \(Self.candidatePaths.joined(separator: " or "))")
    }

    // MARK: Public

    /// Reads one field or attachment, such as `op://Vault/Item/key_id`.
    public func read(_ reference: String) throws -> String {
        let result = try ProcessRunner.run(
            self.executableURL,
            arguments: ["read", "--no-newline", reference],
            timeout: Self.timeout
        )
        if result.isTimedOut {
            throw CLIError.credentials(
                "1Password didn't answer within \(Int(Self.timeout))s. The 1Password app must be open and unlocked, "
                    + "and the access prompt approved."
            )
        }
        if let message = result.failureMessage {
            throw CLIError.credentials("op read \(reference) failed: \(message)")
        }
        return String(decoding: result.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Accepts only `op://Vault/Item`, so a field reference can't be passed where an item is expected.
    public static func validatedItemReference(_ reference: String) throws -> String {
        let pattern = "^op://[^/]+/[^/]+$"
        guard reference.range(of: pattern, options: .regularExpression) != nil else {
            throw CLIError.credentials(
                "expected a 1Password item reference like \(self.referencePlaceholder), got '\(reference)'"
            )
        }
        return reference
    }

    // MARK: Private

    private static func isSignedByAgileBits(_ url: URL) -> Bool {
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        guard
            SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
            SecRequirementCreateWithString(self.requirement as CFString, [], &requirement) == errSecSuccess,
            let staticCode,
            let requirement else
        {
            return false
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
    }
}
