

public struct LLMKit { 
    public let complete: (CompletionChain) async throws -> CompletionChain
    public init(complete: @Sendable @escaping (CompletionChain) async throws -> CompletionChain) {
        self.complete = complete
    }

    public func callAsFunction(chain: CompletionChain, message: String? = nil) async throws -> CompletionChain {
        return try await complete(message.map { chain.appending(.user($0))} ?? chain )
    }
    public func callAsFunction(system: String, messages: [Model.MessageContent]) async throws -> CompletionChain {
        try await self(chain: .init([.init(system: system, messages: messages)]))
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
    static var echo: LLMKit {
        .init { chain in
            let echoResponse: Model.MessageContent = .assistant(chain.output.lastMessage.content, tool_calls: nil)
            return chain.appending(echoResponse)
        }
    }
}

// debug
public extension LLMKit {
    var debug: LLMKit {
        .init { chatLog in
            print(chatLog)
            return try await complete(chatLog)
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
        .init { chatLog in
            await tracker.track()
            return try await complete(chatLog)
        }
    }
}

public extension LLMKit {
    public enum ModifierMode {
        case replace
        case append
    }
    static func systemPromptModifier(_ systemPromptModifier: @escaping (String) -> String, mode: ModifierMode = .replace) -> Self {
        .init { chain in
            let chatLog = chain.output
            let newSystemPrompt = systemPromptModifier(chatLog.system)
            switch mode {
            case .replace:
                return chain.replacingOutput(.init(system: newSystemPrompt, messages: chatLog.messages))
            case .append:
                return chain.appending(.init(system: newSystemPrompt, messages: chatLog.messages))
            }
        }
    }
    func withSystemPromptModifier(_ systemPromptModifier: @escaping (String) -> String, mode: ModifierMode = .replace) -> Self {
        .systemPromptModifier(systemPromptModifier, mode: mode).pipe(to: self)
    }
    func withModifier(_ modifier: Self) -> Self {
        modifier.pipe(to: self)
    }
}
