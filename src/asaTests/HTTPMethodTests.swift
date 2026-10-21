//
//  HTTPMethodTests.swift
//  asaTests
//
//  Created by Dominic Rodemer on 21/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Testing
@testable import asa

@Suite("HTTPMethod")
struct HTTPMethodTests {
    @Test(
        "Arguments are parsed ignoring case",
        arguments: [("get", HTTPMethod.get), ("Post", .post), ("pUt", .put), ("DELETE", .delete)]
    )
    func parsesArgument(_ argument: String, _ expected: HTTPMethod) {
        #expect(HTTPMethod(argument: argument) == expected)
    }

    @Test("Unsupported methods are rejected", arguments: ["PATCH", "patch", "HEAD", "OPTIONS", "", "GETX"])
    func rejectsArgument(_ argument: String) {
        #expect(HTTPMethod(argument: argument) == nil)
    }
}
