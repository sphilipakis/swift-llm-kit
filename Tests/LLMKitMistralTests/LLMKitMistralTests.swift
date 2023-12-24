//
//  LLMKitMistralTests.swift
//  
//
//  Created by stephane on 12/21/23.
//

import XCTest
@testable import LLMKitMistral
import LLMKit

final class LLMKitMistralTests: XCTestCase {
    
    func test_mistral_completionCall_wrongKey() async throws {
        let llm = LLMKit<MistralClientErrorResponse>.mistral(apiKey: "wrongAPITest", model: .mistral_tiny)
            .fallback(to: .constant("An error occured")) { completion in
                switch completion {
                case .chain(let completionChain):
                    return false
                case .error(let eRR):
                    return true
                }
            }
        let result = try await llm.debug(system: "this is an integration test", messages: [.user("hello")], idGenerator: .init(id: { UUID().uuidString}))
        dump(result)
    }
    func test_OpenAI_completionCall() async throws {
        let llm: LLMKit = LLMKit<MistralClientErrorResponse>.mistral(
            apiKey: Keys.mistral,
            model: .mistral_tiny
        )
        let result = try await llm.debug(system: "you speak and answer in french, when asked something in english, you only answer in french", messages: [.user("hello")], idGenerator: .init(id: { UUID().uuidString}))
        dump(result)
    }
    
}
