//
//  File.swift
//  
//
//  Created by stephane on 12/9/23.
//

import Foundation

@attached(member, names: named(toolSchema))
@attached(extension, conformances: ToolPayload)
public macro Tool() = #externalMacro(module: "LLMToolMacros", type: "ToolMacro")
