//
//  File.swift
//  
//
//  Created by stephane on 12/24/23.
//

import Foundation


public actor StreamingSessionsActor {
    var streamingSessions: [NSObject] = []
    public func appendSession(_ session: NSObject) {
        streamingSessions.append(session)
    }
    public func removeSession(_ session: NSObject) {
        streamingSessions.removeAll(where: { $0 == session })
    }
    public init(streamingSessions: [NSObject] = []) {
        self.streamingSessions = streamingSessions
    }
}



fileprivate struct APIErrorResponse<ERR>: Error {
    fileprivate let error: ERR
}


public final class ChatStreamingSession<P: Decodable, ERR: Decodable>: NSObject, Identifiable, URLSessionDelegate, URLSessionDataDelegate {
    
    enum StreamingError: Error {
        case unknownContent
        case emptyContent
    }
    
    @Published var message: Model.MessageContent?
    
    public var onReceiveContent: ((ChatStreamingSession, P) -> Void)?
    public var onProcessingError: ((ChatStreamingSession, Error) -> Void)?
    public var onComplete: ((ChatStreamingSession, Error?) -> Void)?
    
    private let streamingCompletionMarker = "[DONE]"
    private let urlRequest: URLRequest
    private lazy var urlSession: URLSession = {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return session
    }()
    
    public init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
    }
    
    public func resume() {
        self.urlSession
            .dataTask(with: self.urlRequest)
            .resume()
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(self, error)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let stringContent = String(data: data, encoding: .utf8) else {
            onProcessingError?(self, StreamingError.unknownContent)
            return
        }
        print("[StreamSession] ", stringContent)
        let jsonObjects = stringContent
            .components(separatedBy: "data:")
            .filter { $0.isEmpty == false }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard jsonObjects.isEmpty == false, jsonObjects.first != streamingCompletionMarker else {
            return
        }
        jsonObjects.forEach { jsonContent  in
            guard jsonContent != streamingCompletionMarker else {
                return
            }
            guard let jsonData = jsonContent.data(using: .utf8) else {
                onProcessingError?(self, StreamingError.unknownContent)
                return
            }

            let decoder = JSONDecoder()
            do {
                let r = try decoder.decode(ClientResponse<P, ERR>.self, from: jsonData)
                switch r {
                case .payload(let payload):
                    onReceiveContent?(self,payload)
                case .error(let err):
                    onProcessingError?(self, APIErrorResponse(error: err))
                }
            } catch {
                onProcessingError?(self, error)
            }
            
//            
//            do {
//                let decoder = JSONDecoder()
//                let object = try decoder.decode(ResultType.self, from: jsonData)
//                onReceiveContent?(self, object)
//            } catch( let apiError) {
//                do {
//                    let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: jsonData)
//                    onProcessingError?(self, decoded)
//                } catch {
//                    onProcessingError?(self, apiError)
//                }
//            }
        }
    }
}
