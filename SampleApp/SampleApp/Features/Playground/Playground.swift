//
//  File.swift
//  
//
//  Created by stephane on 12/21/23.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import LLMKit
import LLMKitOllama
import LLMKitOpenAI
import LLMKitMistral

@Reducer
public struct Presets {
    @ObservableState
    public struct State {
        var name: String = ""
    }
    public enum Action {
        case setName(String)
    }
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setName(n):
                state.name = n
                return .none
            }
        }
    }
}

@Reducer
struct Log {
    @Dependency(\.uuid) var uuid
    @Dependency(\.streamInferer) var streamInferer
//    @Dependency(\.inferer) var inferer
    @Dependency(\.idGenerator) var idGenerator

    enum Status {
        case infering
        case ready
    }
    @ObservableState
    struct State: Identifiable {
        let id: String
        var trashed: Bool = false
        var bubbles: IdentifiedArrayOf<ChatBubble.State>
        var inferedBubble: ChatBubble.State?
        var status: Status = .ready
    }
    enum Action {
        case bubble(IdentifiedActionOf<ChatBubble>)
        case inferedBubble(ChatBubble.Action)
        case receive(Model.MessageContent, finished: Bool)
        case send
        case addButtonClicked
    }
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .inferedBubble:
                return .none
            case .addButtonClicked:
                state.bubbles.append(.init(id: uuid().uuidString, message: "", source: .user, editMode: true))
                return .none
            case .bubble(.element(id: let id, action: .replayButtonClicked)):
                var untilBubble: IdentifiedArrayOf<ChatBubble.State> = .init(state.bubbles.prefix { b in
                    b.id != id
                })
                untilBubble.append(state.bubbles[id: id]!)
                state.bubbles = untilBubble
                return .send(.send)
                
            case .bubble(.element(id: let id, action: .deleteButtonClicked)):
                state.bubbles.remove(id: id)
                return .none
            case .bubble:
                return .none
            case .receive(let m, finished: let finished):
                state.status = finished ? .ready : .infering
                switch m {
                case let .assistant(.some(s), tool_calls: _):
                    if !finished {
                        state.inferedBubble = .init(id: uuid().uuidString, message: s, source: .assistant)
                        return .none
                    } else {
                        state.inferedBubble = nil
                        state.bubbles.append(.init(id: uuid().uuidString, message: s, source: .assistant))
                    }
                case let .user(.some(s)):
                    state.bubbles.append(.init(id: uuid().uuidString, message: s, source: .user))
                default:
                    break
                }
                return .send(.addButtonClicked, animation: .default)
            case .send:
                state.status = .infering
                let messages:[Model.MessageContent] =
                state.bubbles.elements.map {
                    switch $0.source {
                    case .assistant:
                        return .assistant($0.message, tool_calls: nil)
                    case .user:
                        return .user($0.message)
                    }
                }
                let chatLog = ChatLog(id: uuid().uuidString, system: "", messages: messages)
                return .run { send in
                    for try await r in try await streamInferer.infer((chatLog, idGenerator)) {
                        switch r {
                        case let .error(error):
                            print(error)
                        case let .infered(v, finished: finished):
                            if let v {
                                await send(.receive(v, finished: finished))
                            }
                        }
                    }
                }
            }
        }
        .forEach(\.bubbles, action: \.bubble) {
            ChatBubble()
        }
        .ifLet(\.inferedBubble, action: \.inferedBubble) {
            ChatBubble()
        }
    }
}


extension IDGenerator: TestDependencyKey {
    public static var testValue: IDGenerator {
        .init(id: XCTUnimplemented("\(Self.self).id"))
    }
    public static var previewValue: IDGenerator {
        .init {
            UUID().uuidString
        }
    }
}

extension DependencyValues {
    var idGenerator: IDGenerator {
        get { self[IDGenerator.self]}
        set { self[IDGenerator.self] = newValue}
    }
}

extension Infering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse>: TestDependencyKey {
    public static var testValue: Infering<(ChatLog, IDGenerator), Optional<Model.MessageContent>, ChatErrorResponse> {
        .init(infer: XCTUnimplemented("\(Self.self).infer"))
    }
    public static var previewValue: Infering<(ChatLog, IDGenerator), Optional<Model.MessageContent>, ChatErrorResponse> {
        Infering<(ChatLog, IDGenerator), Model.MessageContent?, OllamaClientErrorResponse>.ollama().mapError { err in
            ChatErrorResponse(message: err.error)
        }
    }
}
extension DependencyValues {
    var inferer: Infering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse> {
        get {
            self[Infering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse>.self]
        }
        set {
            self[Infering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse>.self] = newValue
        }
    }
}

extension StreamInfering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse>: TestDependencyKey {
    public static var testValue: StreamInfering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse> {
        .init(infer: XCTUnimplemented("\(Self.self).infer"))
    }
    public static var previewValue: StreamInfering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse> {
        StreamInfering<(ChatLog, IDGenerator), Model.MessageContent?, OllamaClientErrorResponse>.ollama().mapError { r in
                ChatErrorResponse(message: r.error)
        }
//        .inference(
//            Infering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse>.previewValue
//        )
    }
}
extension DependencyValues {
    var streamInferer: StreamInfering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse> {
        get {
            self[StreamInfering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse>.self]
        }
        set {
            self[StreamInfering<(ChatLog, IDGenerator), Model.MessageContent?, ChatErrorResponse>.self] = newValue
        }
    }
}

@Reducer
struct Playground {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.persistenceClient) var persistenceClient
    
    enum Status {
        case loading
        case saving
        case ready
    }
    @ObservableState
    struct State: Identifiable {
        public let id: String
        public let url: URL
        public var presets: Presets.State
        public var chats: Chats.State
        public var status: Status = .ready
    }
    enum Action {
        case presets(Presets.Action)
        case chats(Chats.Action)
        case start
        case setState(State)
        case setStatus(Status)
    }
    enum CancelID { case debounceSave }
    var body: some ReducerOf<Self> {
        Scope(state: \.presets, action: \.presets) {
            Presets()
        }
        Scope(state: \.chats, action: \.chats) {
            Chats()
        }
        Reduce { state, action in
            switch action {
            case .setStatus(let s):
                state.status = s
                return .none
            case .setState(let s):
                state.status = .ready
                state.chats = s.chats
                return .none
            case .start:
                state.status = .loading
                return .run {[url = state.url] send in
                    let s = try await persistenceClient.load(url)
                    await send(.setState(s))
                }
                
            case .chats:
                return .none
            case .presets:
                return .none
            }
        }

        Reduce { state, action in
            guard case .chats = action else {
                return .cancel(id:CancelID.debounceSave)
            }
            switch action {
            case .setStatus:
                return .none
            default:
                return .run { [state] send in
                    do {
                        try await withTaskCancellation(id: CancelID.debounceSave, cancelInFlight: true) {
                            try await self.clock.sleep(for: .seconds(0.750))
                            print("[SAVE]...")
                            await send(.setStatus(.saving))
                            try await self.persistenceClient.save(state, state.url)
                            print("[SAVED]...")
                            try await self.clock.sleep(for: .seconds(0.750))
                            await send(.setStatus(.ready),animation: .default)
                        }
                    } catch {
                        print("[SAVE CANCELED]")
                        await send(.setStatus(.ready),animation: .default)
                    }
                }
            }
        }
    }
}

public struct PresetsView: View {
    @Bindable
    var store: StoreOf<Presets>
    public var body: some View {
        HStack {
            ComboBox(
                items: ["aaa", "bbb", "ccc"],
                text: $store.name.sending(\.setName)
            )
            .frame(width: 200)

            Button(action: { }) { Text("Save") }
            Button(action: { }) { Text("View code") }
            Button(action: { }) { Text("Share") }
            Menu {
                Button(action: { }) {
                    Text("Delete")
                }
            } label: {
                Text("...")
            }
            .fixedSize()
        }
    }
}


struct LogView: View {
    let store: StoreOf<Log>
    var body: some View {
        VStack {
            ForEachStore(store.scope(state: \.bubbles, action: \.bubble)) { store in
                ChatBubbleView(store: store)
                    .padding(.horizontal)
            }
            IfLetStore(store.scope(state: \.inferedBubble, action: \.inferedBubble)) { store in
                ChatBubbleView(store: store)
                    .padding(.horizontal)
            }
            switch store.status {
            case .infering:
                HStack {
                    Text("Thinking...")
                    Spacer()
                }
                .padding()
            case .ready:
                HStack {
                    Button(action: { store.send(.addButtonClicked, animation: .default)}) {
                        Image(systemName: "plus.circle")
                        Text("Add message")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding()
            }
        }
    }
}

public struct PlaygroundView: View {
    let store: StoreOf<Playground>
    
    public var body: some View {
        VStack(spacing:0) {
            HStack {
                Text("Playground")
                    .font(.title)
                
                Spacer()
                PresetsView(store: store.scope(state: \.presets, action: \.presets))
            }
            .padding()
            Divider()
            HStack {
                ChatsView(store: store.scope(state: \.chats, action: \.chats))
                VStack(alignment: .leading) {
                    Text("Model")
                    Picker(selection: .constant(0)) {
                        Text("Mistral-tiny")
                            .id(0)
                        Text("Mistral-small")
                            .id(1)
                        Text("Mistral-medium")
                            .id(2)
                    } label: {
                        EmptyView()
                    }
                    
                    HStack{
                        Text("Temperature")
                        Spacer()
                        Text("0")
                    }
                    Slider(value: .constant(0))
                    HStack{
                        Text("Maximum length")
                        Spacer()
                        Text("256")
                    }
                    Slider(value: .constant(0))
                    HStack{
                        Text("Top P")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: .constant(1))
                    HStack{
                        Text("Frequency penalty")
                        Spacer()
                        Text("0")
                    }
                    Slider(value: .constant(0))
                    HStack{
                        Text("Presence penalty")
                        Spacer()
                        Text("0")
                    }
                    Slider(value: .constant(0))
                    Spacer()
                }
                .frame(width: 220)
            }
            Divider()
            HStack {
                switch store.status  {
                case .loading:
                    Image(systemName: "circle.fill")
                        .foregroundColor(.blue)
                case .saving:
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                case .ready:
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .frame(height: 24)
        }
        .task {
            store.send(.start)
        }
    }
}
#Preview {
    let initialState: Playground.State = .init(id: "0001", url: URL(string:"file:~/Desktop/Test0001")!,presets: .init(), chats: .init())
    let store: StoreOf<Playground> = .init(initialState: initialState) {
        Playground()
    }
    return PlaygroundView(store: store)
        .frame(width: 1024, height: 800)
}
