//
//  OnePasswordTests.swift
//  AppleCLIKitTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import AppleCLIKit

@Suite("OnePassword")
struct OnePasswordTests {
    @Test(
        "Only plain 1Password item references are accepted",
        arguments: ["op://ASC/Item", "op://Vault/Item With Spaces - Admin"]
    )
    func acceptsItemReference(_ reference: String) throws {
        #expect(try OnePassword.validatedItemReference(reference) == reference)
    }

    @Test(
        "Field references, missing parts and other schemes are rejected",
        arguments: ["op://ASC/Item/key_id", "op://ASC", "ASC/Item", "op:///Item", "file://ASC/Item"]
    )
    func rejectsItemReference(_ reference: String) {
        #expect(throws: CLIError.self) {
            try OnePassword.validatedItemReference(reference)
        }
    }
}
