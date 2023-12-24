//
//  File.swift
//  
//
//  Created by stephane on 12/7/23.
//

import Foundation

public extension LLMCompletion {
    var compacted: LLMCompletion {
        switch self {
        case .chain(let completionChain):
                .chain(completionChain.compacted)
        case .error(let eRR):
                .error(eRR)
        }
    }
}
public extension LLMKit {
    var compact: Self {
        .init { chain, idGenerator in
            try await self(chain: chain, idGenerator: idGenerator).compacted
        }
    }
}

public extension LLMKit {
    func map<NewOutputError>(_ transform: @escaping (ERR) -> NewOutputError ) -> LLMKit<NewOutputError> {
        mapError(transform)
//        .init { chain, idGenerator in
//            let newChain = try await complete(chain, idGenerator)
//            let transformed: CompletionChain<NewOutputError> = try .init(
//                newChain.chatLogs.map {
//                    .init(
//                        id: idGenerator.id(),
//                        system: $0.system,
//                        items: $0.items.map {
//                            switch $0 {
//                            case .error(let err):
//                                return .error(transform(err))
//                            case .message(let content):
//                                return .message(content)
//                            }
//                        }
//                    )
//                }
//            )
//            return transformed
//        }
    }
}

public enum Either<A,B> {
    case first(A)
    case second(B)
}
public extension Either where A == B {
    var first: A {
        switch self {
        case .first(let a):
            a
        case .second(let b):
            b
        }
    }
}
public extension LLMKit {
    func pipe<OtherOutputError>(to other: LLMKit<OtherOutputError>) -> LLMKit<Either<ERR, OtherOutputError>> {
        .init { chain, idGenerator in
            let r = try await self(chain: chain, idGenerator: idGenerator)
            switch r {
            case let .error(e):
                return .error(.first(e))
            case let .chain(c):
                let r = try await other(chain: c, idGenerator: idGenerator)
                switch r {
                case let .error(e):
                    return .error(.second(e))
                case let .chain(c):
                    return .chain(c)
                }
            }
        }
    }
}

public extension LLMKit {
    func fallback(to other: Self, isFailure: @escaping (LLMCompletion<ERR>) -> Bool) -> Self {
        .init { chain, idGenerator in
            do {
                let completion = try await self(chain: chain, idGenerator: idGenerator)
                if isFailure(completion) {
                    return try await other(chain: chain, idGenerator: idGenerator)
                } else {
                    return completion
                }
            } catch {
                return try await other(chain: chain, idGenerator: idGenerator)
            }
        }
    }
    func fallback(to other: Self ) -> Self {
        fallback(to: other, isFailure: { _ in false })
    }
}


public extension LLMKit {
    static func toolsModifier(_ tools: [Model.ToolDef]) -> Self {
        .init { chain, idGenerator in
            let newOutput = chain.output.withTools(tools, id: idGenerator.id())
            let newChain = chain.replacingOutput(newOutput)
            return .chain(newChain)
        }
    }
    
    
    func withTools(_ tools: [Model.ToolDef]) -> Self {
        self.withModifier(LLMKit.toolsModifier(tools))
    }
}

public extension LLMKit {
    struct ToolRequest {
        public let name: String
        public let arguments: String
        public let id: String
    }
    func withToolsEnvironment(_ toolCaller: @Sendable @escaping (ToolRequest) async throws -> String?) -> Self {
        .init { chain, idGenerator in
            let result = try await complete(chain,idGenerator)
            switch result {
            case let .error(e):
                return .error(e)
            case let .chain(c):
                guard case let .assistant(_,toolCalls) = c.output.messages.last else {
                    return result
                }
                
                guard let toolCalls else {
                    return result
                }
                var finalChain = c
                for toolCall in toolCalls {
                    guard toolCall.type == .function else { continue }
                    let id = toolCall.id
                    let arguments = toolCall.function.arguments
                    let name = toolCall.function.name
                    let response = try await toolCaller(.init(name: name, arguments: arguments, id: id))
                    finalChain = finalChain.appending(
                        .tool(response, toolCallID: id)
                        ,idGenerator: idGenerator
                    )
                    let r2 = try await complete(finalChain,idGenerator)
                    switch r2 {
                    case let .error(e):
                        return .error(e)
                    case let .chain(c):
                        finalChain = c
                    }
                }
                return .chain(finalChain)
            }



        }
    }
}
