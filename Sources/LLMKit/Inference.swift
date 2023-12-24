//
//  File.swift
//  
//
//  Created by stephane on 12/24/23.
//

import Foundation

public enum Inference<T,ERR> {
    case infered(T)
    case error(ERR)
}

public struct Infering<Input,T, ERR> {
    public let infer: (Input) async throws -> Inference<T,ERR>
    public init(infer: @Sendable @escaping (Input) async throws -> Inference<T,ERR>) {
        self.infer = infer
    }
}

public extension Infering  {
    func map<A,B>(_ b: B) -> Infering<A,T, ERR> where Input == (A,B){
        .init { a in
            try await self.infer((a,b))
        }
    }
}
public extension Infering where T == Model.MessageContent? {
    func accumulating(accumulator: @escaping (Input, T) -> ChatLog) -> Infering<Input, ChatLog, ERR> {
        .init { input in
            let inference = try await self.infer(input)
            switch inference {
            case .error(let error):
                return .error(error)
            case .infered(let message):
                return .infered(accumulator(input, message))
            }
        }
    }
}
public extension Infering {
    func mapError<NewError>(_ transform: @escaping (ERR) -> NewError ) -> Infering<Input, T, NewError> {
        .init { input in
            let r = try await self.infer(input)
            switch r {
            case let .infered(c):
                return .infered(c)
            case let .error(e):
                return .error(transform(e))
            }
        }
    }
}

