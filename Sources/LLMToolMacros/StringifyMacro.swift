//
//  File.swift
//  
//
//  Created by stephane on 12/8/23.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ToolError: Error {
    var message: String
}

typealias EnumCase = (identifier: TokenSyntax, parameters: [(identifier: TokenSyntax?, type: TypeSyntax)])

extension DeclSyntax {
    var asStoredProperty: (TokenSyntax, TypeSyntax)? {
        get throws {
            guard let v = self.as(VariableDeclSyntax.self) else { return nil }
            guard v.bindings.count == 1 else { throw ToolError(message: "Multiple bindings not supported.") }
            let binding = v.bindings.first!
            guard binding.accessorBlock == nil else { return nil }
            guard let id = binding.pattern.as(IdentifierPatternSyntax.self) else { throw ToolError(message: "Only Identifier patterns supported.")
            }
            guard let type = binding.typeAnnotation?.type else { throw ToolError(message: "Only properties with explicit types supported.")}
            return (id.identifier, type)
        }
    }
}

public struct ToolMacro: MemberMacro, ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        let decl: DeclSyntax = "extension \(type.trimmed): ToolPayload {}"
        return [
            decl.as(ExtensionDeclSyntax.self)!
        ]
    }
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            try structExpansion(of: node, providingMembersOf: structDecl, in: context)
        } else {
            throw ToolError(message: "Only works on structs")
        }
    }
    public static func structExpansion(of node: AttributeSyntax, providingMembersOf declaration: StructDeclSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        let storedProperties = try declaration.memberBlock.members.compactMap { item in
            try item.decl.asStoredProperty
        }
        
        let propsMap = storedProperties.compactMap { prop in
            if let typeName = prop.1.as(IdentifierTypeSyntax.self) {
                return "\"\(prop.0)\": \(typeName).toolSchema"
            } else {
                return nil
            }
        }.joined(separator: ", ")

        return [
            """
            static var toolSchema: ToolSchema {
            .object([\(raw: propsMap)])
            }
            """,
        ]
    }
}

@main
struct LLMToolPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ToolMacro.self,
  ]
}
