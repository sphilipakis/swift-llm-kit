//
//  File.swift
//  
//
//  Created by stephane on 12/19/23.
//

import Foundation
import LLMKit

public struct OllamaClientErrorResponse: Decodable {
    public let error: String
}
public struct OllamaClientResponse: Decodable {
    
    
    
    /*
     {
     "model":"mistral:latest",
     "created_at":"2023-12-19T22:03:34.939982Z",
     "message":{
        "role":"assistant",
        "content":"\nThere were several events that affected the stock and bond markets on Thanksgiving Day. The S\u0026P 500 was up nearly 2%, while municipal bonds improved by around 10-12 basis points across maturities. Treasury yields plunged around 20 basis points, leading to a drop in AAA municipal benchmark yields of around 10-11 basis points. The Fed's dovish sentiment led to higher stock prices and lower bond yields, with the Bank of England keeping its key rate unchanged.\n\nIn terms of specific events that affected the markets, the US announced that Israel agreed to pause fighting for four hour periods each day so that civilians can leave Gaza. This news likely helped to boost bond prices as it reduced the likelihood of further conflict in the region. Additionally, early reports suggested that Black Friday shoppers spent a record amount online in the US, which may have contributed to the bullish performance of stocks.\n\nOverall, while Thanksgiving Day may not typically be a major market-moving event, the positive news and sentiment surrounding the holiday likely helped to boost both stocks and bonds."
     },
     "done":true,
     "total_duration":5510448959,
     "load_duration":806959,"prompt_eval_count":1903,"prompt_eval_duration":2021477000,"eval_count":242,"eval_duration":3480652000}
     */
    
    public let model: String
    public let message: Message
//    public let done: Bool
    public struct Message: Decodable {
        public let role: Model.Role
        public let content: String
    }
}

extension Model {
    struct OllamaCompletionRequestPayload: Encodable {
        public let messages: [MessageContent]
        public let model: String
        public let stream: Bool?
        
        public init(
            messages: [MessageContent],
            model: String,
            stream: Bool?
        ) {
            self.messages = messages
            self.model = model
            self.stream = stream
        }
    }
}

public struct OllamaClient {
    let url: URL
    let session: URLSession
    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }
    
    func createRequest<Payload: Encodable>(method: String = "GET", path: String = "", payload: Payload) throws -> URLRequest {
        var req = createRequest(method: method, path: path)
        req.httpBody = try JSONEncoder().encode(payload)
        return req
    }
    func createRequest(method: String = "GET", path: String = "", beta: Bool = false) -> URLRequest {
        let url = self.url.appending(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }
    func createChatCompletionRequest(_ payload: Model.OllamaCompletionRequestPayload) throws -> URLRequest {
        try createRequest(
            method: "POST",
            path: "/api/chat",
            payload: payload
        )
    }
    public func runRequest<P: Decodable, ERR: Decodable>(_ req: URLRequest, session: URLSession? = nil) async throws -> ClientResponse<P, ERR> {
        let result = try await (session ?? self.session).data(for: req)
        print(String(data: result.0, encoding: .utf8)!)
        let decoder = JSONDecoder()
        return try decoder.decode(ClientResponse<P, ERR>.self, from: result.0)
    }
    
}
