//
//  File.swift
//  
//
//  Created by stephane on 12/7/23.
//

import Foundation

public enum CompletionChainError: Error {
    case emptyChatLogs
}

/// `CompletionChain` is a public struct that represents a sequence of chat logs.
///
/// It provides several methods to manipulate the chat logs, such as appending new messages or replacing the output.
/// a completion chain has at least one input chatlog and one output chatlog. They can both be the same.
public struct CompletionChain<ERR> {
    /// An array of `ChatLog` objects representing the chat logs in the completion chain.
    public let chatLogs: [ChatLog<ERR>]
    /// The first `ChatLog` in the `chatLogs` array.
    public var input: ChatLog<ERR> {
        chatLogs.first!
    }
    /// The last `ChatLog` in the `chatLogs` array.
    public var output: ChatLog<ERR> {
        chatLogs.last!
    }

    /// Initializes a new `CompletionChain` with the given chat logs.
    ///
    /// - Parameter chatLogs: The chat logs to initialize the completion chain with.
    /// - Throws: `CompletionChainError.emptyChatLog` if the `chatLogs` array is empty.
    public init(_ chatLogs: [ChatLog<ERR>]) throws {
        guard chatLogs.count > 0 else { throw CompletionChainError.emptyChatLogs }
        self.chatLogs = chatLogs
    }
    public init(systemPrompt: String) {
        self.chatLogs = [.init(system: systemPrompt, messages: [])]
    }

    /// Returns a new `CompletionChain` with the given message appended to the output.
    ///
    /// - Parameter message: The message to append.
    @available(*, deprecated, message: "Use appending(Item) instead")
    public func appending(_ message: Model.MessageContent) -> Self {
        appending(output.appending(message))
    }
    /// Returns a new `CompletionChain` with the given message appended to the output.
    ///
    /// - Parameter item: The item to append.
    public func appending(_ item: ChatLog<ERR>.Item) -> Self {
        appending(output.appending(item))
    }
    /// Returns a new `CompletionChain` with the given `ChatLog` appended.
    ///
    /// - Parameter chatLog: The `ChatLog` to append.
    public func appending(_ chatLog: ChatLog<ERR>) -> Self {
        try! .init(chatLogs + [chatLog])
    }
    /// Returns a new `CompletionChain` with a message computed from the output appended.
    ///
    /// - Parameter computeMessage: A closure that takes a `ChatLog` and returns a `MessageContent`.
    public func appending(_ computeMessage: (ChatLog<ERR>) -> Model.MessageContent) -> Self {
        appending(computeMessage(output))
    }
    /// Returns a new `CompletionChain` with the output replaced by the given `ChatLog`.
    ///
    /// - Parameter chatLog: The `ChatLog` to replace the output with.
    public func replacingOutput(_ chatLog: ChatLog<ERR>) -> Self {
        try! .init(chatLogs.dropLast() + [chatLog])
    }
    /// Returns a new `CompletionChain` that only includes the input and output if there are more than two chat logs.
    public var compacted: Self {
        guard chatLogs.count > 2 else { return self }
        return try! .init([input, output])
    }
}

/// `ChatLog` is a public struct that represents a chat log in a system.
///
/// It provides several methods to manipulate the messages in the chat log, such as appending new messages.
public struct ChatLog<ERR> {
    public enum Item {
        case message(Model.MessageContent)
        case error(ERR)
    }
    public let system: String
    public let items: [Item]
    public var messages: [Model.MessageContent] {
        items.compactMap { item in
            switch item {
            case .message(let messageContent):
                messageContent
            case .error:
                nil
            }
        }
    }
    public var lastItem: Item {
        items.last ?? .message(.system(system))
    }
    public var lastMessage: Model.MessageContent {
        messages.last ?? .system(system)
    }

    public let tools: [Model.ToolDef]

    /// Initializes a new `ChatLog` with the given system and messages.
    ///
    /// - Parameters:
    ///   - system: The system prompt to use in this chat log.
    ///   - items: The array of items in the chat log
    ///   - tools: The tools available in the chat log
    public init(system: String, items: [Item], tools: [Model.ToolDef] = []) {
        self.system = system
        self.items = items
        self.tools = tools
    }
    /// Initializes a new `ChatLog` with the given system and messages.
    ///
    /// - Parameters:
    ///   - system: The system prompt to use in this chat log.
    ///   - messages: The messages to initialize the chat log with.
    public init(system: String, messages: [Model.MessageContent], tools: [Model.ToolDef] = []) {
        self.system = system
        self.items = messages.map { .message($0) }
        self.tools = tools
    }
    
    public func appending(_ item: Item) -> Self {
        .init(system: system, items: items + [item], tools: tools)
    }
    /// Returns a new `ChatLog` with the given message appended to the messages.
    ///
    /// - Parameter message: The message to append.
    @available(*, deprecated, message: "Use appending(Item) instead")
    public func appending(_ message: Model.MessageContent) -> ChatLog {
        .init(system: system, messages: messages + [message], tools: tools)
    }
    public func withTools(_ tools: [Model.ToolDef]) -> Self {
        .init(system: system, items: items, tools: tools)
    }
}
