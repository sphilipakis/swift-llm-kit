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
    func map<NewOutputError>(_ transform: @escaping (OutputError) -> NewOutputError ) -> LLMKit<InputError, NewOutputError> {
        .init { chain in
            let newChain = try await complete(chain)
            let transformed: CompletionChain<NewOutputError> = try .init(
                newChain.chatLogs.map {
                    .init(
                        system: $0.system,
                        items: $0.items.map {
                            switch $0 {
                            case .error(let err):
                                return .error(transform(err))
                            case .message(let content):
                                return .message(content)
                            }
                        }
                    )
                }
            )
            return transformed
        }
    }
}


public extension LLMKit {
    func pipe<OtherOutputError>(to other: LLMKit<OutputError,OtherOutputError>) -> LLMKit<InputError,OtherOutputError> {
        .init { chain in
            let newChain = try await self(chain: chain)
            let otherChain = try await other(chain: newChain)
            return otherChain
        }
    }
}

public extension LLMKit {
    func fallback(to other: Self, isFailure: @escaping (CompletionChain<OutputError>) -> Bool) -> Self {
        .init { chain in
            do {
                let completion = try await self(chain: chain)
                if isFailure(completion) {
                    return try await other(chain: chain)
                } else {
                    return completion
                }
            } catch {
                return try await other(chain: chain)
            }
        }
    }
    func fallback(to other: Self ) -> Self {
        fallback(to: other, isFailure: { _ in false })
    }
}


public extension LLMKit where InputError == OutputError {
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

public extension LLMKit where InputError == OutputError {
    struct ToolRequest {
        public let name: String
        public let arguments: String
        public let id: String
    }
    func withToolsEnvironment(_ toolCaller: @Sendable @escaping (ToolRequest) async throws -> String?) -> Self {
        .init { chain in
            let result = try await complete(chain)
            guard case let .assistant(_,toolCalls) = result.output.messages.last else {
                return result
            }
            
            guard let toolCalls else {
                return result
            }
            var finalResult = result
            for toolCall in toolCalls {
                guard toolCall.type == .function else { continue }
                let id = toolCall.id
                let arguments = toolCall.function.arguments
                let name = toolCall.function.name
                let response = try await toolCaller(.init(name: name, arguments: arguments, id: id))
                finalResult = finalResult.appending(
                    .message(
                        .tool(response, toolCallID: id)
                    )
                )
                finalResult = try await complete(finalResult)
            }
            return finalResult
        }
    }
}
