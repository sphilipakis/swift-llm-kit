//
//  File.swift
//  
//
//  Created by stephane on 12/21/23.
//

import Foundation
import LLMKit

public struct MistralClientErrorResponse: Decodable {
    public let error: String
}

extension Model {
    struct ChatCompletionRequestPayload: Encodable {
        public let model: String
        public let messages: [MessageContent]
        public let temperature: Float?
        public let top_p: Float?
        public let maxTokens: Int?
        public let stream: Bool?
        public let safe_mode: Bool?
        public let random_seed: Int?

        public init(
            model: String,
            messages: [MessageContent],
            temperature: Float?,
            top_p: Float?,
            maxTokens: Int?,
            stream: Bool?,
            safe_mode: Bool?,
            random_seed: Int?
        ) {
            self.messages = messages
            self.model = model
            self.temperature = temperature
            self.top_p = top_p
            self.maxTokens = maxTokens
            self.stream = stream
            self.safe_mode = safe_mode
            self.random_seed = random_seed
        }
        
        enum CodingKeys: String, CodingKey {
            case messages
            case model
            case temperature
            case top_p
            case maxTokens = "max_token"
            case stream
            case safe_mode
            case random_seed
        }
    }
}

public struct MistralClient {
    
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
        let url = URL(string: "https://api.mistral.ai/v1\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
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
