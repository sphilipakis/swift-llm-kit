



public enum LLMCompletion<ERR> {
    case chain(CompletionChain)
    case error(ERR)
}
public struct LLMKit<ERR> {
    public let complete: (CompletionChain, IDGenerator) async throws -> LLMCompletion<ERR>
    public init(complete: @Sendable @escaping (CompletionChain, IDGenerator) async throws -> LLMCompletion<ERR>) {
        self.complete = complete
    }

    public func callAsFunction(
        chain: CompletionChain,
        message: String? = nil,
        idGenerator: IDGenerator
    ) async throws -> LLMCompletion<ERR> {
        try await complete(message.map { chain.appending(.user($0),idGenerator: idGenerator)} ?? chain, idGenerator)
    }
    public func callAsFunction(
        system: String,
        messages: [Model.MessageContent],
        idGenerator: IDGenerator
    ) async throws -> LLMCompletion<ERR> {
        try await self(chain: .init([.init(id: idGenerator.id(), system: system, messages: messages)]), idGenerator: idGenerator)
    }
}

public extension LLMKit {
    func mapError<NewError>(_ transform: @escaping (ERR) -> NewError ) -> LLMKit<NewError> {
        .init { chain, idGenerator in
            let r = try await self.complete(chain, idGenerator)
            switch r {
            case let .chain(c):
                return .chain(c)
            case let .error(e):
                return .error(transform(e))
            }
        }
    }
}

public extension LLMKit {
    static func constant(_ message: String) -> Self {
        .init { chain, idGenerator in
            .chain(chain.appending(.assistant(message, tool_calls: nil), idGenerator: idGenerator))
        }
    }
}

public extension LLMKit {
    static func infering(_ infering: Infering<(ChatLog, IDGenerator), ChatLog, ERR>) -> Self {
        .init { chain, idGenerator in
            let r = try await infering.infer((chain.output, idGenerator))
            switch r {
            case let .error(e):
                return .error(e)
            case let .infered(newChatLog, finished: finished):
                return .chain(chain.appending(newChatLog))
            }
        }
    }
}


// echo
extension Model.MessageContent {
    var content: String? {
        switch self {
        case .assistant(let str, tool_calls: _):
            return str
        case .user(let str):
            return str
        case .system(let str):
            return str
        case .tool(let str, toolCallID: _):
            return str
        }
    }
}

public extension LLMKit {
    static var echo: Self {
        .init { chain, idGenerator in
            let echoResponse: Model.MessageContent = .assistant(chain.output.lastMessage.content, tool_calls: nil)
            return .chain(chain.appending(echoResponse, idGenerator: idGenerator))
        }
    }
}

// debug
public extension LLMKit {
    var debug: Self {
        .init { chain, idGenerator in
            print(chain)
            return try await complete(chain, idGenerator)
        }
    }
}
public extension LLMKit {
    actor Tracker<T> {
        private var _value:T
        var value: T {
            get async {
                _value
            }
        }
        let _track: (@escaping (T) -> Void, T) -> Void
        init(_ initialValue: T, track: @Sendable @escaping (@escaping (T) -> Void, T) -> Void) {
            _value = initialValue
            _track = track
        }
        func track() async {
            await _track({ self._value = $0 }, value)
        }
    }
    func tracked<T>(_ tracker: Tracker<T> ) -> Self {
        .init { chain, idGenerator in
            await tracker.track()
            return try await complete(chain, idGenerator)
        }
    }
}

public extension LLMKit {
    enum ModifierMode {
        case replace
        case append
    }
    static func systemPromptModifier(_ systemPromptModifier: @escaping (String) -> String, mode: ModifierMode = .replace) -> Self {
        .init { chain, idGenerator in
            let chatLog = chain.output
            let newSystemPrompt = systemPromptModifier(chatLog.system)
            switch mode {
            case .replace:
                return .chain(chain.replacingOutput(.init(id: chatLog.id, system: newSystemPrompt, messages: chatLog.messages)))
            case .append:
                return .chain(chain.appending(.init(id: idGenerator.id(),system: newSystemPrompt, messages: chatLog.messages)))
            }
        }
    }
    func withSystemPromptModifier(_ systemPromptModifier: @escaping (String) -> String, mode: ModifierMode = .replace) -> Self {
        .systemPromptModifier(systemPromptModifier, mode: mode).pipe(to: self).map(\.first)
    }
    func withModifier(_ modifier: Self) -> Self {
        modifier.pipe(to: self).map(\.first)
    }
}
