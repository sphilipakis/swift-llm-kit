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

public struct OpenAIInfererParameters: Codable {
    public let model: String// = .gpt3_5Turbo
    public let frequencyPenalty: Float?// = nil
//    public let logitBias: [Int : Model.Bias]? = nil
    public let maxTokens: Int?// = nil
    public let n: Int?// = nil
    public let presencePenalty: Float?// = nil
//    public let responseFormat: Model.ResponseFormat? = nil
    public let seed: Int?// = nil
    public let stop: [String]?// = nil
    public let stream: Bool?// = false
    public let temperature: Float?// = nil
    public let top_p: Float?// = nil
//    public let tools: [Model.ToolDef]? = nil
//    public let toolChoice: Model.ToolChoice? = nil
    public let user: String?// = nil

    public init(
        model: String,
        frequencyPenalty: Float? = nil,
        //logitBias: [Int : Model.Bias]? = nil
        maxTokens: Int? = nil,
        n: Int? = nil,
        presencePenalty: Float? = nil,
        //responseFormat: Model.ResponseFormat? = nil
        seed: Int? = nil,
        stop: [String]? = nil,
        stream: Bool? = nil,
        temperature: Float? = nil,
        top_p: Float? = nil,
        //tools: [Model.ToolDef]? = nil
        //toolChoice: Model.ToolChoice? = nil
        user: String? = nil
    ) {
        self.model = model
        self.frequencyPenalty = frequencyPenalty
        self.maxTokens = maxTokens
        self.n = n
        self.presencePenalty = presencePenalty
        self.seed = seed
        self.stop = stop
        self.stream = stream
        self.temperature = temperature
        self.top_p = top_p
        self.user = user
    }
}



extension ChatLog  {
    func openAIMessages() -> [Model.MessageContent] {
        [.system(self.system)] + messages
    }
}
public extension Infering where Input == ChatLog, T == Model.MessageContent?, ERR == OpenAIClientErrorResponse {
    static func openAI(
        apiKey: String,
        parameters: OpenAIInfererParameters,
//        model: String = .gpt3_5Turbo,
//        frequencyPenalty: Float? = nil,
//        logitBias: [Int : Model.Bias]? = nil,
//        maxTokens: Int? = nil,
//        n: Int? = nil,
//        presencePenalty: Float? = nil,
//        responseFormat: Model.ResponseFormat? = nil,
//        seed: Int? = nil,
//        stop: [String]? = nil,
//        stream: Bool? = false,
//        temperature: Float? = nil,
//        top_p: Float? = nil,
//        tools: [Model.ToolDef]? = nil,
//        toolChoice: Model.ToolChoice? = nil,
//        user: String? = nil,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), Model.MessageContent?,OpenAIClientErrorResponse>.openAI(
            apiKey: apiKey,
            parameters: parameters
//            model: model,
//            frequencyPenalty: frequencyPenalty,
//            logitBias: logitBias,
//            maxTokens: maxTokens,
//            n: n,
//            presencePenalty: presencePenalty,
//            responseFormat: responseFormat,
//            seed: seed,
//            stop: stop,
//            stream: stream,
//            temperature: temperature,
//            top_p: top_p,
//            tools: tools,
//            toolChoice: toolChoice,
//            user: user
        ).map(idGenerator)
    }
}



public extension Infering where Input ==  (ChatLog, IDGenerator), T == Model.MessageContent?, ERR == OpenAIClientErrorResponse {
    static func openAI(
        apiKey: String,
        parameters: OpenAIInfererParameters
//        apiKey: String,
//        model: String = .gpt3_5Turbo,
//        frequencyPenalty: Float? = nil,
//        logitBias: [Int : Model.Bias]? = nil,
//        maxTokens: Int? = nil,
//        n: Int? = nil,
//        presencePenalty: Float? = nil,
//        responseFormat: Model.ResponseFormat? = nil,
//        seed: Int? = nil,
//        stop: [String]? = nil,
//        stream: Bool? = false,
//        temperature: Float? = nil,
//        top_p: Float? = nil,
//        tools: [Model.ToolDef]? = nil,
//        toolChoice: Model.ToolChoice? = nil,
//        user: String? = nil
    ) -> Self {
        return .init { (chatLog, idGenerator) in
            let inferer: Inferer? = try .init(id: "openAI", parameters: parameters)
            let client = OpenAIClient(apiKey: apiKey)
            let messages: [Model.MessageContent] = chatLog.openAIMessages()
            let payload: Model.ChatCompletionRequestPayload = .init(
                messages: messages,
                model: parameters.model,
                frequencyPenalty: parameters.frequencyPenalty,
                logitBias: nil,//parameters.logitBias,
                maxTokens: parameters.maxTokens,
                n: parameters.n,
                presencePenalty: parameters.presencePenalty,
                responseFormat: nil,//parameters.responseFormat,
                seed: parameters.seed,
                stop: parameters.stop,
                stream: parameters.stream,
                temperature: parameters.temperature,
                top_p: parameters.top_p,
                tools: chatLog.tools.count > 0 ? chatLog.tools : nil,
                toolChoice: nil,//parameters.toolChoice,
                user: parameters.user
            )
            let request : URLRequest = try client.createChatCompletionRequest(
                payload
            )
            let response : ClientResponse<Model.ChatCompletion, OpenAIClientErrorResponse> = try await client.runRequest(request)
            switch response {
            case .error(let openAIClientErrorResponse):
                print("[error] ", openAIClientErrorResponse.error)
                return .init(result: .error(openAIClientErrorResponse), inferer: inferer)
            case .payload(let p):
                let messageContent: Model.MessageContent? = p.choices.first.map {
                    Model.MessageContent.assistant($0.message.content, tool_calls: $0.message.toolCalls)
                }
                return .init(result: .infered(messageContent,finished: true), inferer: inferer)
            }
        }
    }

}


public extension Infering where Input == ChatLog, T == ChatLog, ERR == OpenAIClientErrorResponse {
    static func openAI(
        apiKey: String,
        parameters: OpenAIInfererParameters,
//        model: String = .gpt3_5Turbo,
//        frequencyPenalty: Float? = nil,
//        logitBias: [Int : Model.Bias]? = nil,
//        maxTokens: Int? = nil,
//        n: Int? = nil,
//        presencePenalty: Float? = nil,
//        responseFormat: Model.ResponseFormat? = nil,
//        seed: Int? = nil,
//        stop: [String]? = nil,
//        stream: Bool? = false,
//        temperature: Float? = nil,
//        top_p: Float? = nil,
//        tools: [Model.ToolDef]? = nil,
//        toolChoice: Model.ToolChoice? = nil,
//        user: String? = nil,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), ChatLog,OpenAIClientErrorResponse>.openAI(
            apiKey: apiKey,
            parameters: parameters
//            model: model,
//            frequencyPenalty: frequencyPenalty,
//            logitBias: logitBias,
//            maxTokens: maxTokens,
//            n: n,
//            presencePenalty: presencePenalty,
//            responseFormat: responseFormat,
//            seed: seed,
//            stop: stop,
//            stream: stream,
//            temperature: temperature,
//            top_p: top_p,
//            tools: tools,
//            toolChoice: toolChoice,
//            user: user
        ).map(idGenerator)
    }

}
public extension Infering where Input == (ChatLog, IDGenerator), T == ChatLog, ERR == OpenAIClientErrorResponse {
    
    static func openAI(
        apiKey: String,
        parameters: OpenAIInfererParameters
//        model: String = .gpt3_5Turbo,
//        frequencyPenalty: Float? = nil,
//        logitBias: [Int : Model.Bias]? = nil,
//        maxTokens: Int? = nil,
//        n: Int? = nil,
//        presencePenalty: Float? = nil,
//        responseFormat: Model.ResponseFormat? = nil,
//        seed: Int? = nil,
//        stop: [String]? = nil,
//        stream: Bool? = false,
//        temperature: Float? = nil,
//        top_p: Float? = nil,
//        tools: [Model.ToolDef]? = nil,
//        toolChoice: Model.ToolChoice? = nil,
//        user: String? = nil
    ) -> Self {
        Infering<Input,Model.MessageContent?, ERR>.openAI(
            apiKey: apiKey,
            parameters: parameters
//            model: model,
//            frequencyPenalty: frequencyPenalty,
//            logitBias: logitBias,
//            maxTokens: maxTokens,
//            n: n,
//            presencePenalty: presencePenalty,
//            responseFormat: responseFormat,
//            seed: seed,
//            stop: stop,
//            stream: stream,
//            temperature: temperature,
//            top_p: top_p,
//            tools: tools,
//            toolChoice: toolChoice,
//            user: user
        ).accumulating { (input:Input, message: Model.MessageContent?) in
            let (chatLog, idGenerator) = input
            return message.map {
                chatLog.appending($0, id: idGenerator.id())
            } ?? chatLog
        }
    }
}

public extension LLMKit where ERR == OpenAIClientErrorResponse {
    static func openAI(
        apiKey: String,
        parameters: OpenAIInfererParameters
//        model: String = .gpt3_5Turbo,
//        frequencyPenalty: Float? = nil,
//        logitBias: [Int : Model.Bias]? = nil,
//        maxTokens: Int? = nil,
//        n: Int? = nil,
//        presencePenalty: Float? = nil,
//        responseFormat: Model.ResponseFormat? = nil,
//        seed: Int? = nil,
//        stop: [String]? = nil,
//        stream: Bool? = false,
//        temperature: Float? = nil,
//        top_p: Float? = nil,
//        tools: [Model.ToolDef]? = nil,
//        toolChoice: Model.ToolChoice? = nil,
//        user: String? = nil
    ) -> Self {
        .infering(
            Infering.openAI(
                apiKey: apiKey,
                parameters: parameters
//                model: model,
//                frequencyPenalty: frequencyPenalty,
//                logitBias: logitBias,
//                maxTokens: maxTokens,
//                n: n,
//                presencePenalty: presencePenalty,
//                responseFormat: responseFormat,
//                seed: seed,
//                stop: stop,
//                stream: stream,
//                temperature: temperature,
//                top_p: top_p,
//                tools: tools,
//                toolChoice: toolChoice,
//                user: user
            )
        )
    }
    static func openAI2(
        apiKey: String,
        parameters: OpenAIInfererParameters
//        model: String = .gpt3_5Turbo,
//        frequencyPenalty: Float? = nil,
//        logitBias: [Int : Model.Bias]? = nil,
//        maxTokens: Int? = nil,
//        n: Int? = nil,
//        presencePenalty: Float? = nil,
//        responseFormat: Model.ResponseFormat? = nil,
//        seed: Int? = nil,
//        stop: [String]? = nil,
//        stream: Bool? = false,
//        temperature: Float? = nil,
//        top_p: Float? = nil,
//        tools: [Model.ToolDef]? = nil,
//        toolChoice: Model.ToolChoice? = nil,
//        user: String? = nil
    ) -> Self {
        .init { chain, idGenerator in
            let chatLog = chain.output
            let client = OpenAIClient(apiKey: apiKey)
            let messages: [Model.MessageContent] = chatLog.openAIMessages()
            let payload: Model.ChatCompletionRequestPayload = .init(
                messages: messages,
                model: parameters.model,
                frequencyPenalty: parameters.frequencyPenalty,
                logitBias: nil,//parameters.logitBias,
                maxTokens: parameters.maxTokens,
                n: parameters.n,
                presencePenalty: parameters.presencePenalty,
                responseFormat: nil,//parameters.responseFormat,
                seed: parameters.seed,
                stop: parameters.stop,
                stream: parameters.stream,
                temperature: parameters.temperature,
                top_p: parameters.top_p,
                tools: chatLog.tools.count > 0 ? chatLog.tools : nil,
                toolChoice: nil,//parameters.toolChoice,
                user: parameters.user
            )
            let request : URLRequest = try client.createChatCompletionRequest(
                payload
            )
            let response : ClientResponse<Model.ChatCompletion, OpenAIClientErrorResponse> = try await client.runRequest(request)
            switch response {
            case .error(let openAIClientErrorResponse):
                print("[error] ", openAIClientErrorResponse.error)
                return .error(openAIClientErrorResponse)
            case .payload(let p):
                let messageContent: Model.MessageContent? = p.choices.first.map {
                    Model.MessageContent.assistant($0.message.content, tool_calls: $0.message.toolCalls)
                }
                return .chain(chain.appending(
                    messageContent.map {
                        chatLog.appending(
                            $0,
                            id: idGenerator.id()
                        )
                    } ?? chatLog
                ))
            }
        }
    }
}

