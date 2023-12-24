//
//  File.swift
//  
//
//  Created by stephane on 12/19/23.
//

import Foundation

public enum ClientResponse<P: Decodable, ERR: Decodable>: Decodable {
    case error(ERR)
    case payload(P)
    enum CodingKeys: CodingKey {
        case error
        case payload
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let err = try container.decode(ERR.self)
            self = .error(err)
        } catch {
            do {
                let p = try container.decode(P.self)
                self = .payload(p)
            } catch {
                throw DecodingError.typeMismatch(Self.self, DecodingError.Context.init(codingPath: container.codingPath,debugDescription: "Wrong type", underlyingError: nil))
            }
        }
    }
}
