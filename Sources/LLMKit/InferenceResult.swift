//
//  File.swift
//  
//
//  Created by stephane on 12/24/23.
//

import Foundation
import ConcurrencyExtras

public struct Inferer {
    public let id: String
    public let parameters: String // JSON String
    public init(id: String, parameters: String) {
        self.id = id
        self.parameters = parameters
    }
    public init?<T: Codable>(id: String, parameters: T) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(parameters)
        guard let parameters = String(data: data, encoding: .utf8) else { return nil }
        self.id = id
        self.parameters = parameters
    }
}
public struct Inference<T,ERR> {
    public let result: InferenceResult<T,ERR>
    public let inferer: Inferer?
    public init(result: InferenceResult<T, ERR>, inferer: Inferer?) {
        self.result = result
        self.inferer = inferer
    }
    func mapingError<NewError>(_ transform: @escaping (ERR)->NewError) -> Inference<T, NewError> {
        switch result {
        case .error(let error):
            return .init(result: .error(transform(error)), inferer: inferer)
        case .infered(let message, finished: let finished):
            return .init(result: .infered(message, finished: finished), inferer: inferer)
        }
    }
    func mapingResult<T2>(_ transform: @escaping (T) -> T2) -> Inference<T2, ERR> {
        switch result {
        case .error(let error):
            return .init(result: .error(error), inferer: inferer)
        case .infered(let message, finished: let finished):
            return .init(result: .infered(transform(message), finished: finished), inferer: inferer)
        }
    }
}
public enum InferenceResult<T,ERR> {
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
                switch inference.result {
                case let .infered(c, finished: f):
                    return .init(result: .infered(c, finished: f), inferer: inference.inferer)
                case let .error(e):
                    return .init(result: .error(transform(e)), inferer: inference.inferer)
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
            return inference.mapingResult { message in
                accumulator(input, message)
            }
//            switch inference.result {
//            case .error(let error):
//                return .init(result: .error(error), inferer: inference.inferer)
//            case .infered(let message, finished: let finished):
//                return .init(result: .infered(accumulator(input, message), finished: finished), inferer: inference.inferer)
//            }
        }
    }
}
public extension Infering {
    func mapError<NewError>(_ transform: @escaping (ERR) -> NewError ) -> Infering<Input, T, NewError> {
        .init { input in
            let r = try await self.infer(input)
            return r.mapingError(transform)
//            switch r {
//            case let .infered(c, finished: finished):
//                return .infered(c, finished: finished)
//            case let .error(e):
//                return .error(transform(e))
//            }
        }
    }
}

