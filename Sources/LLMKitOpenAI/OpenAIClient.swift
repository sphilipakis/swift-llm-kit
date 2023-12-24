//
//  File.swift
//  
//
//  Created by stephane on 12/9/23.
//

import Foundation
import LLMKit

public struct OpenAIClientErrorResponse: Decodable {
    public let error: Body
    public struct Body: Decodable {
        public let message: String
        public let type: String
        public let param: String?
        public let code: String?
    }
}
//
//public enum OpenAIClientResponse<P: Decodable, ERR: Decodable>: Decodable {
//    case error(ERR)
//    case payload(P)
//    enum CodingKeys: CodingKey {
//        case error
//        case payload
//    }
//    
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        do {
//            let err = try container.decode(ERR.self)
//            self = .error(err)
//        } catch {
//            do {
//                let p = try container.decode(P.self)
//                self = .payload(p)
//            } catch {
//                throw DecodingError.typeMismatch(OpenAIClientResponse<P, ERR>.self, DecodingError.Context.init(codingPath: container.codingPath,debugDescription: "Wrong type", underlyingError: nil))
//            }
//        }
//    }
//}

extension Model {
    public typealias Bias = Int // -100 .. 100
    
    public enum ToolChoice: Encodable {
        case none
        case auto
        case function(name: String)
        
        enum FunctionCodingKeys: CodingKey {
            case type
            case function
        }
        struct FunctionPayload: Encodable {
            let type: String
            let function: FunctionName
            struct FunctionName: Encodable {
                let name: String
            }
        }
            
        public func encode(to encoder: Encoder) throws {
            switch self {
            case .none:
                var container = encoder.singleValueContainer()
                try container.encode("none")
            case .auto:
                var container = encoder.singleValueContainer()
                try container.encode("auto")
            case .function(let name):
                var container = encoder.container(keyedBy: FunctionCodingKeys.self)
                try container.encode(FunctionPayload(type: "function", function: .init(name: name)), forKey: .function)
            }
        }

    }
    
    /// https://platform.openai.com/docs/api-reference/chat/create
    struct ChatCompletionRequestPayload: Encodable {
        public let messages: [MessageContent]
        public let model: String
        public let frequencyPenalty: Float?
        public let logitBias: [Int: Bias]?
        public let maxTokens: Int?
        public let n: Int?
        public let presencePenalty: Float?
        public let responseFormat: ResponseFormat?
        public let seed: Int?
        public let stop: [String]?
        public let stream: Bool?
        public let temperature: Float?
        public let top_p: Float?
        public let tools:[ToolDef]?
        public let toolChoice: ToolChoice?
        public let user: String?

        public init(
            messages: [MessageContent],
            model: String,
            frequencyPenalty: Float?,
            logitBias: [Int : Bias]?,
            maxTokens: Int?,
            n: Int?,
            presencePenalty: Float?,
            responseFormat: ResponseFormat?,
            seed: Int?,
            stop: [String]?,
            stream: Bool?,
            temperature: Float?,
            top_p: Float?,
            tools: [ToolDef]?,
            toolChoice: ToolChoice?,
            user: String?
        ) {
            self.messages = messages
            self.model = model
            self.frequencyPenalty = frequencyPenalty
            self.logitBias = logitBias
            self.maxTokens = maxTokens
            self.n = n
            self.presencePenalty = presencePenalty
            self.responseFormat = responseFormat
            self.seed = seed
            self.stop = stop
            self.stream = stream
            self.temperature = temperature
            self.top_p = top_p
            self.tools = tools
            self.toolChoice = toolChoice
            self.user = user
        }
        
        enum CodingKeys: String, CodingKey {
            case messages
            case model
            case frequencyPenalty = "frequency_penalty"
            case logitBias = "logit_bias"
            case maxTokens = "max_token"
            case n
            case presencePenalty = "presence_penalty"
            case responseFormat = "response_format"
            case seed
            case stop
            case stream
            case temperature
            case top_p
            case tools
            case toolChoice = "tool_choice"
            case user
        }
    }
}


public struct OpenAIClient {
    
    let apiKey: String
    let session: URLSession
    
    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    func createRequest<Payload:Encodable>(method: String = "GET", path: String = "", payload: Payload) throws -> URLRequest {
        var req = createRequest(method: method, path: path)
        req.httpBody = try JSONEncoder().encode(payload)
        return req
    }
    func createRequest(method: String = "GET", path: String = "", beta: Bool = false) -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        if (beta) {
            req.addValue("assistants=v1", forHTTPHeaderField: "OpenAI-Beta")
        }
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return req
    }
    
    func createChatCompletionRequest(_ payload: Model.ChatCompletionRequestPayload) throws -> URLRequest {
        try createRequest(
            method: "POST",
            path: "/chat/completions",
            payload: payload
        )
    }
    
    public func runRequest<P: Decodable, ERR: Decodable>(_ req: URLRequest, session: URLSession? = nil) async throws -> ClientResponse<P, ERR> {
        let result = try await (session ?? self.session).data(for: req)
        let decoder = JSONDecoder()
        return try decoder.decode(ClientResponse<P, ERR>.self, from: result.0)
    }
}
