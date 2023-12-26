//
//  File.swift
//  
//
//  Created by stephane on 12/21/23.
//

import Foundation
import LLMKit

public extension String {
    static let mistral_tiny = "mistral-tiny"
    static let mistral_small = "mistral-small"
    static let mistral_medium = "mistral-medium"
}
extension ChatLog  {
    func mistralMessages() -> [Model.MessageContent] {
        [.system(self.system)] + messages
    }
}
public extension Infering where Input == ChatLog, T == Model.MessageContent?, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        model: String = .mistral_tiny,
        maxTokens: Int? = nil,
        n: Int? = nil,
        random_seed: Int? = nil,
        stream: Bool? = false,
        temperature: Float? = nil,
        top_p: Float? = nil,
        safe_mode: Bool? = nil,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), T, ERR>.mistral(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            n: n,
            random_seed: random_seed,
            stream: stream,
            temperature: temperature,
            top_p: top_p,
            safe_mode: safe_mode
        )
        .map(idGenerator)
    }
}
public extension Infering where Input == (ChatLog, IDGenerator), T == Model.MessageContent?, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        model: String = .mistral_tiny,
        maxTokens: Int? = nil,
        n: Int? = nil,
        random_seed: Int? = nil,
        stream: Bool? = false,
        temperature: Float? = nil,
        top_p: Float? = nil,
        safe_mode: Bool? = nil
    ) -> Self {
        .init { chatLog, idGenerator in
            let client = MistralClient(apiKey: apiKey)
            let messages: [Model.MessageContent] = chatLog.mistralMessages()
            let payload: Model.ChatCompletionRequestPayload = .init(
                model: model,
                messages: messages,
                temperature: temperature,
                top_p: top_p,
                maxTokens: maxTokens,
                stream: stream,
                safe_mode: safe_mode,
                random_seed: random_seed
            )
            let request : URLRequest = try client.createChatCompletionRequest(
                payload
            )
            let response : ClientResponse<Model.ChatCompletion, MistralClientErrorResponse> = try await client.runRequest(request)
            switch response {
            case .error(let openAIClientErrorResponse):
                print("[error] ", openAIClientErrorResponse.error)
                return .error(openAIClientErrorResponse)
            case .payload(let p):
                let messageContent: Model.MessageContent? = p.choices.first.map {
                    Model.MessageContent.assistant($0.message.content, tool_calls: $0.message.toolCalls)
                }
                return .infered(messageContent, finished: true)
            }
        }
    }
}
public extension Infering where Input == ChatLog, T == ChatLog, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        model: String = .mistral_tiny,
        maxTokens: Int? = nil,
        n: Int? = nil,
        random_seed: Int? = nil,
        stream: Bool? = false,
        temperature: Float? = nil,
        top_p: Float? = nil,
        safe_mode: Bool? = nil,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), ChatLog, MistralClientErrorResponse>.mistral(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            n: n,
            random_seed: random_seed,
            stream: stream,
            temperature: temperature,
            top_p: top_p,
            safe_mode: safe_mode
        ).map(idGenerator)
    }
}
public extension Infering where Input == (ChatLog, IDGenerator), T == ChatLog, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        model: String = .mistral_tiny,
        maxTokens: Int? = nil,
        n: Int? = nil,
        random_seed: Int? = nil,
        stream: Bool? = false,
        temperature: Float? = nil,
        top_p: Float? = nil,
        safe_mode: Bool? = nil
    ) -> Self {
        Infering<Input, Model.MessageContent?, ERR>.mistral(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            n: n,
            stream: stream,
            temperature: temperature,
            top_p: top_p,
            safe_mode: safe_mode
        ).accumulating { (input, message) in
            let (chatLog, idGenerator) = input
            return message.map {
                chatLog.appending($0, id: idGenerator.id())
            } ?? chatLog
        }
    }
}

public extension LLMKit where ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        model: String = .mistral_tiny,
        maxTokens: Int? = nil,
        n: Int? = nil,
        random_seed: Int? = nil,
        stream: Bool? = false,
        temperature: Float? = nil,
        top_p: Float? = nil,
        safe_mode: Bool? = nil
    ) -> Self {
        .infering(
            Infering.mistral(
                apiKey: apiKey,
                model: model,
                maxTokens: maxTokens,
                n: n,
                random_seed: random_seed,
                stream: stream,
                temperature: temperature,
                top_p: top_p,
                safe_mode: safe_mode
            )
        )
    }
}
