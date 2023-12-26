//
//  File.swift
//  
//
//  Created by stephane on 12/24/23.
//

import Foundation
import ConcurrencyExtras

public enum Inference<T,ERR> {
    case infered(T, finished: Bool)
    case error(ERR)
}

public struct StreamInfering<Input, T, ERR> {
    public let infer: (Input) async throws -> AsyncThrowingStream<Inference<T,ERR>,Error>
    public init(infer: @Sendable @escaping (Input) async throws -> AsyncThrowingStream<Inference<T,ERR>,Error>) {
        self.infer = infer
    }
}
public extension StreamInfering {
    func mapError<NewError>(_ transform: @escaping (ERR) -> NewError ) -> StreamInfering<Input, T, NewError> {
        .init { input in
            let r = try await self.infer(input)
            return r.map { inference in
                switch inference {
                case let .infered(c, finished: f):
                    return .infered(c, finished: f)
                case let .error(e):
                    return .error(transform(e))
                }
            }.eraseToThrowingStream()
//            switch r {
//            case let .infered(c):
//                return .infered(c)
//            case let .error(e):
//                return .error()
//            }
        }
    }
}


public struct Infering<Input,T, ERR> {
    public let infer: (Input) async throws -> Inference<T,ERR>
    public init(infer: @Sendable @escaping (Input) async throws -> Inference<T,ERR>) {
        self.infer = infer
    }
}

public extension StreamInfering {
    static func inference(_ infering: Infering<Input, T, ERR>) -> Self {
        .init { input in
            .init { continuation in
                Task {
                    do {
                        let r = try await infering.infer(input)
                        continuation.yield(r)
                        continuation.finish()
                    } catch {
                        print("[error]", error)
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
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
            case .infered(let message, finished: let finished):
                return .infered(accumulator(input, message), finished: finished)
            }
        }
    }
}
public extension Infering {
    func mapError<NewError>(_ transform: @escaping (ERR) -> NewError ) -> Infering<Input, T, NewError> {
        .init { input in
            let r = try await self.infer(input)
            switch r {
            case let .infered(c, finished: finished):
                return .infered(c, finished: finished)
            case let .error(e):
                return .error(transform(e))
            }
        }
    }
}

