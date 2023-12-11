//
//  File.swift
//  
//
//  Created by stephane on 12/9/23.
//

import Foundation

public struct FetchTool: Tool {
    @Tool
    public struct Payload {
        let url: String
        let maxLen: Int?
        let callReason: String
        init(url: String, maxLen: Int?, callReason: String) {
            self.url = url
            self.maxLen = maxLen
            self.callReason = callReason
        }
    }
    
    public func call(_ payload: Payload) async throws -> String? {
        guard let url = URL(string: payload.url) else {
            return "`\(payload.url)` is not a URL"
        }
        var request: URLRequest = .init(url: url)
        request.setValue("UTF-8", forHTTPHeaderField: "Accept-Charset")

        let (data, URLResponse) = try await URLSession.shared.data(for: request)
        return decodeResponseData(data, response: URLResponse).map { String($0.prefix(payload.maxLen ?? $0.count))}
    }
    
    func decodeResponseData(_ data: Data, response: URLResponse) -> String? {
        var encoding: String.Encoding?

        if let mimeType = response.mimeType,
           let textEncodingName = (response as? HTTPURLResponse)?.textEncodingName {
            let encodingName = CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encodingName))
        }
        
        if let encoding = encoding, let decodedString = String(data: data, encoding: encoding) {
            return decodedString
        } else if let utf8String = String(data: data, encoding: .utf8) {
            return utf8String
        }
        
        // Optionally try other encodings...
        // Example: ISO Latin 1
        if let isoLatin1String = String(data: data, encoding: .isoLatin1) {
            return isoLatin1String
        }

        return nil
    }
    
    public init() { }
}
