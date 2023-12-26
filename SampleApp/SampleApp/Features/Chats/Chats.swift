//
//  Chats.swift
//  SampleApp
//
//  Created by stephane on 12/23/23.
//

import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct Chats {
    @Dependency(\.uuid) var uuid
    @Dependency(\.inferer) var inferer
    @Dependency(\.idGenerator) var idGenerator
    @ObservableState
    public struct State {
        var logs: IdentifiedArrayOf<Log.State> = []
        var selectedStoreID: String?
    }
    enum Action {
        case start
        case logs(IdentifiedActionOf<Log>)
        case send
        case selectLog(String)
        case addLog
        case deleteLog(String)
    }
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .deleteLog(let id):
                state.logs[id:id]?.trashed = true
                return .none
            case .addLog:
                state.logs.append(
                    .init(id: uuid().uuidString, bubbles: .init(uniqueElements: [.init(id: uuid().uuidString,message: "", source: .user, editMode: true)]))
                )
                state.selectedStoreID = state.logs.ids.first
                return .none

            case .selectLog(let id):
                state.selectedStoreID = id
                return .none
            case .start:
                if state.logs.isEmpty {
                    state.logs = .init(uniqueElements: [
                        .init(id: uuid().uuidString, bubbles: .init(uniqueElements: [.init(id: uuid().uuidString,message: "", source: .user, editMode: true)]))
                    ])
                }
                state.selectedStoreID = state.logs.ids.first
                return .none
            case .send:
                guard let id = state.selectedStoreID, let log = state.logs[id: id] else { return .none}
                return .send(.logs(.element(id: log.id, action: .send)))
            case .logs:
                return .none
            }
        }
        .forEach(\.logs, action: \.logs) {
            Log()
        }
    }
}
struct ChatsView: View {
//    @Bindable
    var store: StoreOf<Chats>
    @State var hoverLogID: [String: Bool] = [:]
    var body: some View {
        HStack(alignment: .top, spacing: 0){
            VStack(alignment: .leading) {
                List {
                    ForEachStore(store.scope(state: \.logs, action: \.logs)) { logStore in
                        if !logStore.trashed {
                            Button(action: { store.send(.selectLog(logStore.id))}) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(logStore.bubbles.first?.message ?? "Log")
                                            .lineLimit(1)
                                        Text(logStore.id)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                    }
                                    Spacer()
                                    if hoverLogID[logStore.id] == true {
                                        Button(action: { store.send(.deleteLog(logStore.id), animation: .default)}) {
                                            Image(systemName: "xmark")
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .onHover(perform: { hovering in
                                hoverLogID[logStore.id] = hovering
                            })
                        }
                    }
                }
                Spacer()
                Button(action: { 
                    store.send(.addLog)
                }) {
                    Text("Add Log")
                }
                .buttonStyle(.plain)
            }
            .frame(width: 180)
            HStack {
                VStack(alignment: .leading) {
                    Text("SYSTEM")
                    TextEditor(text: .constant(""))
                        .textEditorStyle(.plain)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                    .stroke()
                )
                .frame(width: 320)
                VStack(spacing:0) {
                    ScrollView{
                        ForEachStore(store.scope(state: \.logs, action: \.logs)) { logStore in
                            if store.selectedStoreID == logStore.id {
                                LogView(store: logStore)
                            }
                        }
                    }
                    Spacer()
        //            TextEditor(text: $store.message.sending(\.setMessage))
                    Button(action: { store.send(.send)}) {
                        Text("Send")
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .task {
            store.send(.start)
        }
    }
}

#Preview {
    let store: StoreOf<Chats> = .init(initialState: .init()) {
        Chats()
    }
    return ChatsView(store: store)
        .frame(width: 1024, height: 800)
}
