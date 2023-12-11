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
            GreetingTool.toolDef(description: "Call this function to say hello, this function will return some information about the state of the user. Note that the `callReason` parameter is mandatory and you should always use it specify why you need to call the function."),
        ].compactMap { $0 }

        
        let tooledLLM = llm.withTools(tools).withToolsEnvironment { toolRequest in
            switch toolRequest.name {
            case "GreetingTool":
                let tool = GreetingTool()
                if let payload = try GreetingTool.decode(toolRequest.arguments) {
                    return try await tool.call(payload)
                }
            default:
                break
            }
            return nil
        }
        
        let result = try await tooledLLM(
            system: "you respond to greetings by greeting back. then you can engage the conversation",
            messages: [.user("hello")]
        )

        result.output.messages.forEach { c in
            print(">>>>   ",c)
            print("----------")
        }
    }
    func test_decode() async throws {
        let json = """
        {"greeting":"Hello", "callReason":"Cause"}
        """
        let payload = try GreetingTool.decode(json)
        dump(payload)
    }
    
    func test_fetch() async throws {
        let llm: LLMKit = .openAI(apiKey: Keys.openAI, model: .gpt3_5Turbo_16k)
        let tools: [Model.ToolDef] = [
            FetchTool.toolDef(description: "Call this function to load the content of a web page. This function will return the html. you can limit the number of characters to return using the maxLen mandatory parameter. I recommend using a lenght that makes sure the content fits in your context window. Note that the `callReason` parameter is mandatory and you should always use it specify why you need to call the function.")
        ].compactMap { $0 }
        let tooledLLM = llm.withTools(tools).withToolsEnvironment { toolRequest in
            switch toolRequest.name {
            case "FetchTool":
                let tool = FetchTool()
                if let payload = try FetchTool.decode(toolRequest.arguments) {
                    return try await tool.call(payload)
                }
            default:
                break
            }
            return nil
        }
        
        let result = try await tooledLLM(
            system: "you can access the internet",
            messages: [.user("using cnn rss (don't use https, only http), tell me what's happening in the world")]
        )
        result.output.items.forEach { c in
            print(">>>>   ",c)
            print("----------")
        }

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
