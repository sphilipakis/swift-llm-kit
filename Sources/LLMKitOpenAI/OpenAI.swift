//
//  File.swift
//  
//
//  Created by stephane on 12/5/23.
//

import Foundation
import LLMKit

public extension String {
    static let gpt3_5Turbo = "gpt-3.5-turbo"
    static let gpt3_5Turbo0613 = "gpt-3.5-turbo-0613"
    static let gpt3_5Turbo_16k_0613 = "gpt-3.5-turbo-16k-0613"
    static let gpt4 = "gpt-4"
    static let gpt3_5Turbo_16k = "gpt-3.5-turbo-16k"
    static let gpt4_32k = "gpt-4-32k"
}




extension ChatLog  {
    func openAIMessages() -> [Model.MessageContent] {
        [.system(self.system)] + messages
    }
}




public extension LLMKit where InputError == OutputError , OutputError == OpenAIClientErrorResponse {
    
    static func openAI(
        apiKey: String,
        model: String = .gpt3_5Turbo,
        frequencyPenalty: Float? = nil,
        logitBias: [Int : Model.Bias]? = nil,
        maxTokens: Int? = nil,
        n: Int? = nil,
        presencePenalty: Float? = nil,
        responseFormat: Model.ResponseFormat? = nil,
        seed: Int? = nil,
        stop: [String]? = nil,
        stream: Bool? = false,
        temperature: Float? = nil,
        top_p: Float? = nil,
        tools: [Model.ToolDef]? = nil,
        toolChoice: Model.ToolChoice? = nil,
        user: String? = nil
    ) -> Self {
        .init { chain in
            let chatLog = chain.output
            let client = OpenAIClient(apiKey: apiKey)
            let messages: [Model.MessageContent] = chatLog.openAIMessages()
            let payload: Model.ChatCompletionRequestPayload = .init(
                messages: messages,
                model: model,
                frequencyPenalty: frequencyPenalty,
                logitBias: logitBias,
                maxTokens: maxTokens,
                n: n,
                presencePenalty: presencePenalty,
                responseFormat: responseFormat,
                seed: seed,
                stop: stop,
                stream: stream,
                temperature: temperature,
                top_p: top_p,
                tools: chatLog.tools.count > 0 ? chatLog.tools : nil,
                toolChoice: toolChoice,
                user: user
            )
            let request : URLRequest = try client.createChatCompletionRequest(
                payload
            )
            let response : OpenAIClientResponse<Model.ChatCompletion, OpenAIClientErrorResponse> = try await client.runRequest(request)
            switch response {
            case .error(let openAIClientErrorResponse):
                print("[error] ", openAIClientErrorResponse.error)
                return chain.appending(.error(openAIClientErrorResponse))
            case .payload(let p):
                let messageContent: Model.MessageContent? = p.choices.first.map {
                    Model.MessageContent.assistant($0.message.content, tool_calls: $0.message.toolCalls)
                }
                return chain.appending(messageContent.map { chatLog.appending(.message($0))} ?? chatLog)
            }
        }
    }
}

