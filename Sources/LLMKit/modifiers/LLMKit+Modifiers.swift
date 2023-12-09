//
//  File.swift
//  
//
//  Created by stephane on 12/7/23.
//

import Foundation

public extension LLMKit {
    var compact: Self {
        .init { chain in
            try await self(chain: chain).compacted
        }
    }
}

public extension LLMKit {
    func pipe(to other: LLMKit) -> LLMKit {
        .init { chain in
            let newChain = try await self(chain: chain)
            let otherChain = try await other(chain: newChain)
            return otherChain
        }
    }
}

public extension LLMKit {
    func fallback(to other: LLMKit) -> LLMKit {
        .init { chain in
            do {
                return try await self(chain: chain)
            } catch {
                return try await other(chain: chain)
            }
        }
    }
}


public extension LLMKit {
    static func toolsModifier(_ tools: [Model.ToolDef]) -> Self {
        .init { chain in
            let newOutput = chain.output.withTools(tools)
            let newChain = chain.replacingOutput(newOutput)
            return newChain
        }
    }
    
    
    func withTools(_ tools: [Model.ToolDef]) -> Self {
        self.withModifier(LLMKit.toolsModifier(tools))
    }
}
