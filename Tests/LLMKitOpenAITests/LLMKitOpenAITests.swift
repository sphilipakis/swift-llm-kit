//
//  LLMKitOpenAITests.swift
//  
//
//  Created by stephane on 12/7/23.
//

import XCTest
@testable import LLMKitOpenAI
import LLMKit

final class LLMKitOpenAITests: XCTestCase {
    func test_OpenAI_completionCall_wrongKey() async throws {
        let llm = LLMKit
            .openAI(apiKey: "wrongAPITest", model: .gpt3_5Turbo)
            .fallback(to: .constant("An error occured")) { chain in
                if case .error(_) = chain.output.lastItem {
                    return true
                } else {
                    return false
                }
            }
        let result = try await llm.debug(system: "this is an integration test", messages: [.user("hello")])
        dump(result)
    }
    func test_OpenAI_completionCall() async throws {
        let llm: LLMKit = .openAI(
            apiKey: Keys.openAI,
            model: .gpt3_5Turbo
        )
        let result = try await llm.debug(system: "you speak and answer in french", messages: [.user("hello")])
        dump(result)
    }
    
    func test_OpenAI_completionCall_withTools() async throws {
        let llm: LLMKit = .openAI(apiKey: Keys.openAI, model: .gpt4)

        let tools: [Model.ToolDef] = [
            GreetingTool.toolDef(description: "Call this function to say hello, the `callReason` parameter is mandatory and you should always use it specify why you need to call the function."),
        ].compactMap { $0 }

        let result = try await llm.withTools(tools)(
            system: "you respond to greetings by greeting back. then you can engage the conversation",
            messages: [.user("hello my name is Stephane")]
        )

        let lastMessage = result.output.messages.last!
        print(">>> initial answer: ", lastMessage)

        if case let .assistant(_, toolCalls) = lastMessage {
            if let toolCalls {
                for toolCall in toolCalls {
                    guard toolCall.type == .function else { return }
                    let id = toolCall.id
                    let arguments = toolCall.function.arguments
                    let name = toolCall.function.name
                    switch name {
                    case "GreetingTool":
                        let tool = GreetingTool()
                        if let payload = try GreetingTool.decode(arguments) {
                            if let response = try await tool.call(payload) {
                                let result2 = try await llm.complete(
                                    result
                                        .appending(
                                            .message(
                                                .tool(
                                                    response,
                                                    toolCallID: id
                                                )
                                            )
                                        )
                                )
                                dump(result2.output.messages)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    func test_decode() async throws {
        let json = """
        {"greeting":"Hello", "callReason":"Cause"}
        """
        let payload = try GreetingTool.decode(json)
        dump(payload)
    }
}

@Tool
struct GreetingToolPayload {
    let greeting: String
    let callReason: String
}

struct GreetingTool: Tool {
    func call(_ payload: Payload) async throws -> String? {
        return "Stephane received your greeting. he seems excited by something."
    }
    @Tool
    struct Payload {
        let greeting: String
        let callReason: String
    }
}
