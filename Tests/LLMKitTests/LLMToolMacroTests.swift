//
//  LLMToolMacroTests.swift
//  
//
//  Created by stephane on 12/9/23.
//

import XCTest
import LLMKit
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import LLMToolMacros

final class LLMToolMacroTests: XCTestCase {

    func test_ToolMacro() async throws {
        assertMacroExpansion(
            """
            @Tool
            struct GreetingPayload {
                let greeting: String
                let callReason: String
            }
            """,
            expandedSource: """
            struct GreetingPayload {
                let greeting: String
                let callReason: String

                static var toolSchema: ToolSchema {
                    .object(["greeting": String.toolSchema, "callReason": String.toolSchema])
                }
            }

            extension GreetingPayload: ToolPayload {
            }
            """,
            macros: ["Tool": ToolMacro.self]
        )
    }
    
}
