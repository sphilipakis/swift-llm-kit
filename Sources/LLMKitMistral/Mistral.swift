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

public struct MistralInfererParameters: Codable {
    public let model: String// = .mistral_tiny,
    public let maxTokens: Int?// = nil,
    public let n: Int?// = nil,
    public let random_seed: Int?// = nil,
    public let stream: Bool?// = false,
    public let temperature: Float?// = nil,
    public let top_p: Float?// = nil,
    public let safe_mode: Bool?// = nil,
    public init(
        model: String = .mistral_tiny,
        maxTokens: Int? = nil,
        n: Int? = nil,
        random_seed: Int? = nil,
        stream: Bool? = nil,
        temperature: Float? = nil,
        top_p: Float? = nil,
        safe_mode: Bool? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.n = n
        self.random_seed = random_seed
        self.stream = stream
        self.temperature = temperature
        self.top_p = top_p
        self.safe_mode = safe_mode
    }
}

public extension Infering where Input == ChatLog, T == Model.MessageContent?, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        parameters: MistralInfererParameters,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), T, ERR>.mistral(
            apiKey: apiKey,
            parameters: parameters
        )
        .map(idGenerator)
    }
}
public extension Infering where Input == (ChatLog, IDGenerator), T == Model.MessageContent?, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        parameters: MistralInfererParameters
    ) -> Self {
        let inferer: Inferer? = try? .init(id: "mistral", parameters: parameters)
        return .init { chatLog, idGenerator in
            
            let client = MistralClient(apiKey: apiKey)
            let messages: [Model.MessageContent] = chatLog.mistralMessages()
            let payload: Model.ChatCompletionRequestPayload = .init(
                model: parameters.model,
                messages: messages,
                temperature: parameters.temperature,
                top_p: parameters.top_p,
                maxTokens: parameters.maxTokens,
                stream: parameters.stream,
                safe_mode: parameters.safe_mode,
                random_seed: parameters.random_seed
            )
            let request : URLRequest = try client.createChatCompletionRequest(
                payload
            )
            let response : ClientResponse<Model.ChatCompletion, MistralClientErrorResponse> = try await client.runRequest(request)
            switch response {
            case .error(let openAIClientErrorResponse):
                print("[error] ", openAIClientErrorResponse.error)
                return Inference(result: .error(openAIClientErrorResponse), inferer: inferer)
            case .payload(let p):
                let messageContent: Model.MessageContent? = p.choices.first.map {
                    Model.MessageContent.assistant($0.message.content, tool_calls: $0.message.toolCalls)
                }
                return Inference(result: .infered(messageContent, finished: true), inferer: inferer)
            }
        }
    }
}
public extension Infering where Input == ChatLog, T == ChatLog, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        parameters: MistralInfererParameters,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), ChatLog, MistralClientErrorResponse>.mistral(
            apiKey: apiKey,
            parameters: parameters
        ).map(idGenerator)
    }
}
public extension Infering where Input == (ChatLog, IDGenerator), T == ChatLog, ERR == MistralClientErrorResponse {
    static func mistral(
        apiKey: String,
        parameters: MistralInfererParameters
    ) -> Self {
        Infering<Input, Model.MessageContent?, ERR>.mistral(
            apiKey: apiKey,
            parameters: parameters
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
        parameters: MistralInfererParameters
    ) -> Self {
        .infering(
            Infering.mistral(
                apiKey: apiKey,
                parameters: parameters
            )
        )
    }
}
