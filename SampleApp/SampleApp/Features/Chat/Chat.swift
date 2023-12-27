//
//  File.swift
//
//
//  Created by stephane on 12/13/23.
//

import Foundation
import ComposableArchitecture
import LLMKit
import LLMKitOpenAI
import LLMKitOllama
import SwiftUI
import SimilaritySearchKitDistilbert
import SimilaritySearchKit





@Tool
struct GreetingToolPayload {
    let greeting: String
    let callReason: String
}

struct GreetingTool: Tool {
    func call(_ payload: Payload) async throws -> String? {
        return "Stephane received your greeting. he seems excited by something."
    }
    @Tool
    struct Payload {
        let greeting: String
        let callReason: String
    }
}

extension LLMKit {
    static func dispatcher(dispatch: @escaping (CompletionChain) -> Self ) -> Self {
        .init { chain, idGenerator in
            let llm = dispatch(chain)
            return try await llm.complete(chain, idGenerator)
        }
    }
}
extension Model.ToolCall {
    var body: String? {
        "\(self.id) \(self.function.name)(\(self.function.arguments))"
    }
}
extension Model.MessageContent {
    var body: String? {
        switch self {
        case .system(let string):
            string
        case .user(let string):
            string
        case .assistant(let string, let tool_calls):
            ([string ?? ""] + (tool_calls ?? []).map {
                $0.body
            }).compactMap { $0 }.joined(separator: ",")
        case .tool(let string, let toolCallID):
            string
        }
    }
}

public struct ChatErrorResponse {
    let message: String
}

extension LLMKit<ChatErrorResponse>: TestDependencyKey {
    public static var testValue: LLMKit< ChatErrorResponse> {
        .init(complete: XCTUnimplemented("\(Self.self).complete"))
    }
    public static var previewValue: LLMKit< ChatErrorResponse> {
        LLMKit<OllamaClientErrorResponse>.ollama(parameters:.init()).debug.mapError { r in
            ChatErrorResponse(message: r.error)
        }
    }
}

extension DependencyValues {
    var llm: LLMKit< ChatErrorResponse> {
        get {
            self[LLMKit< ChatErrorResponse>.self]
        }
        set {
            self[LLMKit< ChatErrorResponse>.self] = newValue
        }
    }
}


struct FunctionCaller {
    var call: (String, String, String) async throws -> String
    init(call: @Sendable @escaping (String, String, String) async throws -> String) {
        self.call = call
    }
}
extension FunctionCaller: TestDependencyKey {
    static var testValue: FunctionCaller {
        .init(call: XCTUnimplemented("\(Self.self).call"))
    }
    static var previewValue: FunctionCaller {
        .init { callID, name, arguments in
            return "call successful"
        }
    }
}

extension DependencyValues {
    var toolCaller: FunctionCaller {
        get { self[FunctionCaller.self] }
        set { self[FunctionCaller.self] = newValue }
    }
}
@Reducer
public struct ChatFeature {
    @Dependency(\.llm) var llm
    @Dependency(\.continuousClock) var clock
    @Dependency(\.toolCaller) var toolCaller
    @Dependency(\.uuid) var uuid
    
    public init() {
        
    }
    @ObservableState
    public struct State {
        var completionChain: CompletionChain
        var prompt: String = ""
        var toolCallsQueue: IdentifiedArrayOf<Model.ToolCall> = []
        public init() {
            self.completionChain = .init(systemPrompt: "", idGen: { "" })
        }
    }

    public enum Action {
        case send(String)
        case updateCompletionChain(CompletionChain)
        case setPrompt(String)
        
        case queueToolCalls([Model.ToolCall])
        
        case runInference
        
        case runTool(callID: String, name: String, arguments: String)
        case sendToolResult(callID: String, value: String)
    }
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setPrompt(prompt):
                state.prompt = prompt
                return .none
            case let .send(message):
                state.prompt = ""
                state.completionChain = state.completionChain.appending(.user(message), idGenerator: .init(id: { uuid().uuidString }))
                return .send(.runInference)
//                return .concatenate(
//                    .cancel(id: CancelID.completion),
//                    .run { [completionChain = state.completionChain] send in
//                        try await withTaskCancellation(id: CancelID.completion) {
//                            try await clock.sleep(for: .seconds(1))
//                            do {
//                                let r = try await self.llm.withTools([
//                                    GreetingTool.toolDef(description: "Call this function to say hello, this function will return some information about the state of the user. `greeting` parameter is mandatory. Note that the `callReason` parameter is mandatory and you should always use it specify why you need to call the function."),
//                                
//                                ].compactMap { $0 })
////                                .withToolsEnvironment { toolRequest in
////                                    print(toolRequest)
////                                    switch toolRequest.name {
////                                    case "GreetingTool" :
////                                        let tool = GreetingTool()
////                                        if let payload = try GreetingTool.decode(toolRequest.arguments) {
////                                            return try await tool.call(payload)
////                                        }
////                                    default:
////                                        break
////                                    }
////                                    return nil
////                                }
//                                .complete(completionChain)
//                                switch r.output.lastItem {
//                                case .message(.assistant(_, tool_calls: .some(let toolCalls))):
//                                    await send(.queueToolCalls(toolCalls))
//                                default:
//                                    break
//                                }
//                                print(r)
//                                await send(.updateCompletionChain(r), animation: .default)
//                            } catch {
//                                print("Error",error)
//                            }
//                        }
//                    }
//                )
                    
                    
            case let .updateCompletionChain(chain):
                state.completionChain = chain
                return .none
                
            case let .queueToolCalls(toolCalls):
                state.toolCallsQueue.append(contentsOf: toolCalls)
                return .none
            case let .runTool(callID: callID, name: name, arguments: arguments):
                return .run { send in
                    let r = try await toolCaller.call(callID, name, arguments)
                    await send(.sendToolResult(callID: callID, value: r))
                }
            case let .sendToolResult(callID: callID, value: value):
                state.completionChain = state.completionChain.appending(.tool(value, toolCallID: callID), idGenerator: .init { uuid().uuidString })
                return .send(.runInference)
            case .runInference:
                return .concatenate(
                    .cancel(id: CancelID.completion),
                    .run { [completionChain = state.completionChain] send in
                        try await withTaskCancellation(id: CancelID.completion) {
                            try await clock.sleep(for: .seconds(1))
                            do {
                                let r = try await self.llm.withTools([
                                    GreetingTool.toolDef(description: "Call this function to say hello, this function will return some information about the state of the user. `greeting` parameter is mandatory. Note that the `callReason` parameter is mandatory and you should always use it specify why you need to call the function."),
                                
                                ].compactMap { $0 })
//                                .withToolsEnvironment { toolRequest in
//                                    print(toolRequest)
//                                    switch toolRequest.name {
//                                    case "GreetingTool" :
//                                        let tool = GreetingTool()
//                                        if let payload = try GreetingTool.decode(toolRequest.arguments) {
//                                            return try await tool.call(payload)
//                                        }
//                                    default:
//                                        break
//                                    }
//                                    return nil
//                                }
                                    .complete(completionChain, .init { uuid().uuidString })
                                switch r {
                                case let .error(e):
                                    break
                                case let .chain(c):
                                    switch c.output.lastItem {
                                    case .assistant(_, tool_calls: .some(let toolCalls)):
                                        await send(.queueToolCalls(toolCalls))
                                    default:
                                        break
                                    }
                                    print(r)
                                    await send(.updateCompletionChain(c), animation: .default)

                                }
                            } catch {
                                print("Error",error)
                            }
                        }
                    }
                )
            }
            
        }
    }
    enum CancelID {
        case completion
    }
}

struct ChatView: View {
    @Bindable var store: StoreOf<ChatFeature>
    var body: some View {
        VStack {
            List {
                Text(store.completionChain.output.id)
                ForEach(0 ..< store.completionChain.output.items.count, id: \.self) { index in
                    let item = store.completionChain.output.items[index]
                    ChatBubbleView2<Void>(item: item) { callID, name, arguments in
                        store.send(.runTool(callID: callID, name: name, arguments: arguments))
                    }
                }
                ForEach(store.toolCallsQueue, id:\.id) { toolCall in
                    Text("Tool Call \(toolCall.function.name)")
                }
            }
//            TextField("Prompt", text: .init(get: { store.prompt }, set: { store.send(.setPrompt($0))}))
//                .onSubmit {
//                    store.send(.send(store.prompt), animation: .default)
//                }
            TextField("Prompt", text: $store.prompt.sending(\.setPrompt))
                .onSubmit {
                    store.send(.send(store.prompt), animation: .default)
                }
        }
    }
    
}

#Preview {
    let store: StoreOf<ChatFeature> = .init(initialState: .init()) {
        ChatFeature()
    }
    return ChatView(store: store)
        .frame(minHeight: 800)
}

extension Model.MessageContent {
    var source: String {
        switch self {
        case .system(let string):
            "System"
        case .user(let string):
            "User"
        case .assistant(let string, let tool_calls):
            "Assistant"
        case .tool(let string, let toolCallID):
            "Tool"
        }
    }
}

extension Model.MessageContent {
//    var body: String? {
//        switch self {
//        case .message(let messageContent):
//            messageContent.body
//        case .error(let eRR):
//            "Error \(eRR)"
//        }
//    }
//    var source: String {
//        switch self {
//        case .message(let messageContent):
//            messageContent.source
//        case .error(let eRR):
//            "Error"
//        }
//    }
}

struct ChatBubbleView2<ERR>: View {
    let item: Model.MessageContent
    let runTool: (String, String, String) -> Void
    @ViewBuilder func messageContentView(content: Model.MessageContent) -> some View {
        switch content {
        case .system(let string):
            Text(string ?? "")
        case .user(let string):
            Text(string ?? "")
        case .assistant(let string, let tool_calls):
            VStack(alignment: .leading) {
                if let string {
                    Text(string)
                }
                if let tool_calls {
                    VStack(alignment: .leading) {
                        ForEach(0..<tool_calls.count, id: \.self) { index in
                            let toolCall = tool_calls[index]
                            HStack{
                                Image(systemName: "function")
                                Text(toolCall.function.name)
                                    .padding(.horizontal,7)
                                    .background(Capsule().foregroundColor(.gray.opacity(0.5)))
                                Spacer()
                            }
                            .italic()
                            Text(toolCall.function.arguments)
                            Button(action: {
                                runTool(toolCall.id, toolCall.function.name, toolCall.function.arguments)
                            }) {
                                Text("Run")
                            }
                        }
                    }
                }
            }
        case .tool(let string, let toolCallID):
            VStack(alignment: .leading) {
                Text(string ?? "")
                Text(toolCallID)
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.source)
                .foregroundStyle(.secondary)
            HStack {
                messageContentView(content: item)
                Spacer()
            }
        }
        .padding()
    }
}

#Preview {
    
    VStack(alignment: .leading){
        ChatBubbleView2<Void>(item: .assistant("Hello, how can I help?", tool_calls: nil)) { _,_,_ in }
        ChatBubbleView2<Void>(item: .assistant("Response with function call", tool_calls: [
            .init(id: "12345", type: .function, function: .init(name: "fetch", arguments: "{...}" )),
        ])) { _,_,_ in }
        ChatBubbleView2<Void>(item: .tool("'function result'", toolCallID: "12345")) { _,_,_ in }
    }
}
