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

public struct IDGenerator {
    public var id: () -> String
    public init(id: @escaping () -> String) {
        self.id = id
    }
}

/// `CompletionChain` is a public struct that represents a sequence of chat logs.
///
/// It provides several methods to manipulate the chat logs, such as appending new messages or replacing the output.
/// a completion chain has at least one input chatlog and one output chatlog. They can both be the same.
public struct CompletionChain {
    /// An array of `ChatLog` objects representing the chat logs in the completion chain.
    public let chatLogs: [ChatLog]
    /// The first `ChatLog` in the `chatLogs` array.
    public var input: ChatLog {
        chatLogs.first!
    }
    /// The last `ChatLog` in the `chatLogs` array.
    public var output: ChatLog {
        chatLogs.last!
    }

    /// Initializes a new `CompletionChain` with the given chat logs.
    ///
    /// - Parameter chatLogs: The chat logs to initialize the completion chain with.
    /// - Throws: `CompletionChainError.emptyChatLog` if the `chatLogs` array is empty.
    public init(_ chatLogs: [ChatLog]) throws {
        guard chatLogs.count > 0 else { throw CompletionChainError.emptyChatLogs }
        self.chatLogs = chatLogs
    }
    public init(systemPrompt: String, idGen: @escaping () -> String) {
        self.chatLogs = [.init(id: idGen(), system: systemPrompt, messages: [])]
    }

    /// Returns a new `CompletionChain` with the given message appended to the output.
    ///
    /// - Parameter message: The message to append.
//    @available(*, deprecated, message: "Use appending(Item) instead")
    public func appending(_ message: Model.MessageContent, idGenerator: IDGenerator) -> Self {
        appending(output.appending(message, id: idGenerator.id()))
    }
    /// Returns a new `CompletionChain` with the given `ChatLog` appended.
    ///
    /// - Parameter chatLog: The `ChatLog` to append.
    public func appending(_ chatLog: ChatLog) -> Self {
        try! .init(chatLogs + [chatLog])
    }
    /// Returns a new `CompletionChain` with a message computed from the output appended.
    ///
    /// - Parameter computeMessage: A closure that takes a `ChatLog` and returns a `MessageContent`.
    public func appending(_ computeMessage: (ChatLog) -> Model.MessageContent, idGenerator: IDGenerator) -> Self {
        appending(computeMessage(output), idGenerator: idGenerator)
    }
    /// Returns a new `CompletionChain` with the output replaced by the given `ChatLog`.
    ///
    /// - Parameter chatLog: The `ChatLog` to replace the output with.
    public func replacingOutput(_ chatLog: ChatLog) -> Self {
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
public struct ChatLog: Identifiable {
    public let id: String
    public let system: String
    public let items: [Model.MessageContent]
    public var messages: [Model.MessageContent] {
        items
    }
    public var lastItem: Model.MessageContent {
        items.last ?? .system(system)
    }
    public var lastMessage: Model.MessageContent {
        messages.last ?? .system(system)
    }

    public let tools: [Model.ToolDef]

    /// Initializes a new `ChatLog` with the given system and messages.
    ///
    /// - Parameters:
    ///   - system: The system prompt to use in this chat log.
    ///   - messages: The messages to initialize the chat log with.
    public init(id: String, system: String, messages: [Model.MessageContent], tools: [Model.ToolDef] = []) {
        self.id = id
        self.system = system
        self.items = messages
        self.tools = tools
    }
    
//    public func appending(_ item: Model.MessageContent, id: String) -> Self {
//        .init(id: id, system: system, messages: items + [item], tools: tools)
//    }
    /// Returns a new `ChatLog` with the given message appended to the messages.
    ///
    /// - Parameter message: The message to append.
//    @available(*, deprecated, message: "Use appending(Item) instead")
    public func appending(_ message: Model.MessageContent, id: String) -> ChatLog {
        .init(id: id, system: system, messages: messages + [message], tools: tools)
    }
    public func withTools(_ tools: [Model.ToolDef], id: String) -> Self {
        .init(id: id, system: system, messages: items, tools: tools)
    }
}
