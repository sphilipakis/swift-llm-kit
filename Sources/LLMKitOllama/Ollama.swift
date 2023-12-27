//
//  File.swift
//  
//
//  Created by stephane on 12/19/23.
//

import Foundation
import LLMKit

//struct OllamaCompletionChunk: Decodable {
//    let model: String?
//    let message: Model.MessageContent?
//    let done: Bool?
//}

public struct OllamaInfererParameters: Codable {
    public let url: URL
    public let model: String
    public init(
        url: URL = URL(string:"http://localhost:11434")!,
        model: String = "mistral:latest"
    ) {
        self.url = url
        self.model = model
    }
}
public extension StreamInfering where Input == (ChatLog, IDGenerator), T == Model.MessageContent?, ERR == OllamaClientErrorResponse {
    static func ollama(
        parameters: OllamaInfererParameters
    ) -> Self {
        let streamingSessionsActor = StreamingSessionsActor()
        let inferer: Inferer? = try? .init(id: "mistral", parameters: parameters)
        return .init { (chatLog, idGenerator) in
            let client = OllamaClient(url: parameters.url)
            let payload: Model.OllamaCompletionRequestPayload = .init(messages: [.system(chatLog.system)] + chatLog.messages, model: parameters.model, stream: true)
            let request: URLRequest = try client.createChatCompletionRequest(payload)
            let streamingSession = ChatStreamingSession<OllamaClientResponse, ERR>(urlRequest: request)
            await streamingSessionsActor.appendSession(streamingSession)
            var message: String = ""
            return .init { continuation in
                streamingSession.onProcessingError = { (session, error) in
                    print("[StreamInfering] streamingSession.onProcessingError", error)
                    continuation.finish(throwing: error)
                    Task {
                        await streamingSessionsActor.removeSession(session)
                    }
                }
                streamingSession.onReceiveContent = { (session, resultType) in
                    print("[StreamInfering] streamingSession,onReceiveContent", resultType)
                    message += resultType.message.content
                    continuation.yield(.init(result: .infered(.assistant(message, tool_calls: nil), finished: resultType.done), inferer: inferer))
                }
                streamingSession.onComplete = { (session, error) in
                    print("[ChatDriver] streamingSession.onComplete", error)
                    continuation.finish(throwing: error)
                    Task {
                        await streamingSessionsActor.removeSession(session)
                    }
                }
                streamingSession.resume()
            }//.eraseToThrowingStream()
            
            
//            return AsyncThrowingStream<Inference<, Error> { continuation in
//                streamingSession.onProcessingError = { (session,error) in
//                    print("[ChatDriver] streamingSession.onProcessingError", error)
//                    continuation.finish(throwing: error)
//                    Task {
//                        await streamingSessionsActor.removeSession(session)
//                    }
//                }
//                streamingSession.onReceiveContent = { (session, resultType) in
//                    print("[ChatDriver] streamingSession.onReceiveContent", resultType)
//                    tokenCount += 1
//                    if let choice = resultType.choices.first {
//                        let toolCall: Model.ToolCall? = choice.delta.toolCalls?.first
//                        let delta: ChatStreamDelta = .init(
//                            content: choice.delta.content,
//                            role: .assistant,
//                            toolCall: toolCall
//                        )
//                        continuation.yield(
//                            .delta(
//                                delta
//                            )
//                        )
//                    }
//                }
//                streamingSession.onComplete = { (session, error) in
//                    print("[ChatDriver] streamingSession.onComplete", error)
//                    continuation.finish(throwing: error)
//                    Task {
//                        await streamingSessionsActor.removeSession(session)
//                    }
//                }
//                streamingSession.resume()
//            }.eraseToThrowingStream()
            
//            let response: ClientResponse<OllamaClientResponse, OllamaClientErrorResponse> = try await client.runRequest(request)
//            switch response {
//            case .error(let openAIClientErrorResponse):
//                print("[error] ", openAIClientErrorResponse.error)
//                return .error(openAIClientErrorResponse)
//            case .payload(let p):
//                let messageContent: Model.MessageContent? = Model.MessageContent.assistant(p.message.content, tool_calls: nil)
//                return  .infered(messageContent)
//            }
        }
    }
}


public extension Infering where Input == ChatLog, T == Model.MessageContent?, ERR == OllamaClientErrorResponse {
    static func ollama(
        parameters: OllamaInfererParameters,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), T, ERR>.ollama(parameters: parameters).map(idGenerator)
    }
}
public extension Infering where Input == (ChatLog, IDGenerator), T == Model.MessageContent?, ERR == OllamaClientErrorResponse {
    static func ollama(
        parameters: OllamaInfererParameters
    ) -> Self {
        let inferer: Inferer? = try? .init(id: "mistral", parameters: parameters)
        return .init { (chatLog, idGenerator) in
            let client = OllamaClient(url: parameters.url)
            let payload: Model.OllamaCompletionRequestPayload = .init(messages: [.system(chatLog.system)] + chatLog.messages, model: parameters.model, stream: false)
            let request: URLRequest = try client.createChatCompletionRequest(payload)
            let response: ClientResponse<OllamaClientResponse, OllamaClientErrorResponse> = try await client.runRequest(request)
            switch response {
            case .error(let openAIClientErrorResponse):
                print("[error] ", openAIClientErrorResponse.error)
                return .init(result: .error(openAIClientErrorResponse), inferer: inferer)
            case .payload(let p):
                let messageContent: Model.MessageContent? = Model.MessageContent.assistant(p.message.content, tool_calls: nil)
                return  .init(result: .infered(messageContent, finished: true), inferer: inferer)
            }
        }
    }
}

public extension Infering where Input == ChatLog, T == ChatLog, ERR == OllamaClientErrorResponse {
    static func ollama(
        parameters: OllamaInfererParameters,
        idGenerator: IDGenerator
    ) -> Self {
        Infering<(ChatLog, IDGenerator), ChatLog, OllamaClientErrorResponse>.ollama(parameters: parameters).map(idGenerator)
    }
}
public extension Infering where Input == (ChatLog, IDGenerator), T == ChatLog, ERR == OllamaClientErrorResponse {
    static func ollama(
        parameters: OllamaInfererParameters
    ) -> Self {
        Infering<Input, Model.MessageContent?, ERR>.ollama(
            parameters: parameters
        ).accumulating { (input, message) in
            return message.map {
                input.0.appending($0, id: input.1.id())
            } ?? input.0
        }
//        .init { (chatLog, idGenerator) in
//            let client = OllamaClient(url: url)
//            let payload: Model.OllamaCompletionRequestPayload = .init(messages: [.system(chatLog.system)] + chatLog.messages, model: model, stream: false)
//            let request: URLRequest = try client.createChatCompletionRequest(payload)
//            let response: ClientResponse<OllamaClientResponse, OllamaClientErrorResponse> = try await client.runRequest(request)
//            switch response {
//            case .error(let openAIClientErrorResponse):
//                print("[error] ", openAIClientErrorResponse.error)
//                return .error(openAIClientErrorResponse)
//            case .payload(let p):
//                let messageContent: Model.MessageContent? = Model.MessageContent.assistant(p.message.content, tool_calls: nil)
//               
//                return  .infered(messageContent.map {
//                            chatLog.appending(
//                                $0,
//                                id: idGenerator.id()
//                            )
//                        } ?? chatLog
//                                 )
//            }
//        }
    }
}

public extension LLMKit where ERR == OllamaClientErrorResponse {
    static func ollama(
        parameters: OllamaInfererParameters
    ) -> Self {
        .infering(.ollama(parameters: parameters))
    }
//    static func ollama(url: URL, model: String) -> Self {
//        .init { chain, idGenerator in
//            let chatLog = chain.output
//            let client = OllamaClient(url: url)
//            let payload: Model.OllamaCompletionRequestPayload = .init(messages: [.system(chatLog.system)] + chatLog.messages, model: model, stream: false)
//            let request: URLRequest = try client.createChatCompletionRequest(payload)
//            let response: ClientResponse<Model.ChatCompletion, OllamaClientErrorResponse> = try await client.runRequest(request)
//            switch response {
//            case .error(let openAIClientErrorResponse):
//                print("[error] ", openAIClientErrorResponse.error)
//                return chain.appending(.error(openAIClientErrorResponse), idGenerator: idGenerator)
//            case .payload(let p):
//                let messageContent: Model.MessageContent? = p.choices.first.map {
//                    Model.MessageContent.assistant($0.message.content, tool_calls: $0.message.toolCalls)
//                }
//                return chain.appending(
//                    messageContent.map {
//                                chatLog.appending(
//                                    .message($0),
//                                    id: idGenerator.id()
//                                )
//                            } ?? chatLog
//                )
//            }
//        }
//    }
}
