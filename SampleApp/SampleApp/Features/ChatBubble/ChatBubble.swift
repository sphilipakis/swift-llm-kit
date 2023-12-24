//
//  ChatBubble.swift
//  SampleApp
//
//  Created by stephane on 12/22/23.
//

import Foundation
import ComposableArchitecture
import LLMKit
import SwiftUI
import MarkdownUI

@Reducer
struct ChatBubble {

    enum Source {
        case user
        case assistant
        var toggled: Self {
            switch self {
            case .user:
                    .assistant
            case .assistant:
                    .user
            }
        }
    }
    @ObservableState
    struct State: Identifiable {
        let id: String
        var message: String = ""
        var source: Source = .user
        var editMode: Bool = false
        var inputPrompt: String {
            switch source {
            case .user:
                "Enter a user message here..."
            case .assistant:
                "Enter an assistant message here..."
            }
        }
    }
    enum Action {
        case deleteButtonClicked
        case replayButtonClicked
        case toggleSourceClicked
        case toggleEditModeClicked
        case setMessage(String)
    }
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setMessage(m):
                state.message = m
                return .none
            case .deleteButtonClicked:
                return .none
            case .replayButtonClicked:
                return .none
            case .toggleSourceClicked:
                state.source = state.source.toggled
                return .none
            case .toggleEditModeClicked:
                state.editMode.toggle()
                return .none
            }
        }
    }
}
struct TextEditorView: View {
    
    @Binding var string: String
    @State var textEditorHeight : CGFloat = 20
    
    var body: some View {
        
        ZStack(alignment: .leading) {
            Text(string)
                .font(.system(.body))
                .foregroundColor(.clear)
//                .padding(14)
                .background(GeometryReader {
                    Color.clear.preference(
                        key: ViewHeightKey.self,
                        value: $0.frame(in: .local).size.height
                    )
                })
            
            TextEditor(text: $string)
                .font(.system(.body))
                .frame(height: max(30,textEditorHeight))
//                .cornerRadius(10.0)
//                            .shadow(radius: 1.0)
        }
        .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
        
    }
    
}


struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value + nextValue()
    }
}

struct ChatBubbleView: View {
    @Bindable
    var store: StoreOf<ChatBubble>
    @State var isHovering: Bool = false
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: { store.send(.toggleSourceClicked)}) {
                    switch store.source {
                    case .user:
                        Text("USER")
                    case .assistant:
                        Text("ASSISTANT")
                    }
                }
                Spacer()
                HStack {
                    Button(action: { store.send(.deleteButtonClicked, animation: .default)}) {
                        Image(systemName: "minus.circle")
                            .padding(5)
                            .contentShape(Rectangle())
                            .opacity(isHovering && !store.editMode ? 1.0 : 0.0)
                    }
                    .buttonStyle(.plain)
                    Button(action: { store.send(.replayButtonClicked, animation: .default)}) {
                        Image(systemName: "play")
                            .padding(5)
                            .contentShape(Rectangle())
                            .opacity(isHovering || store.editMode  ? 1.0 : 0.0)
                    }
                    .buttonStyle(.plain)
                    Button(action: { store.send(.toggleEditModeClicked)}) {
                        Image(systemName: store.editMode ? "checkmark":"pencil")
                            .padding(5)
                            .contentShape(Rectangle())
                            .opacity(isHovering || store.editMode ? 1.0 : 0.0)
                    }
                    .buttonStyle(.plain)

                }
            }
            HStack(alignment: .top) {
                if store.editMode {
                    ZStack(alignment: .topLeading) {
                        Text(store.message.isEmpty ? store.inputPrompt : store.message)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .opacity(store.message.isEmpty ? 1 : 0)
                            .offset(x: 5)
                        
                        TextEditorView(string: $store.message.sending(\.setMessage))
                            .textEditorStyle(PlainTextEditorStyle())
                            .font(.body)
                            .padding(0)
                    }
                } else {
                    Markdown(store.message)
                    .textSelection(.enabled)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).stroke(lineWidth: 1).foregroundColor(store.editMode ? .accentColor : .clear))
                
         
            Divider()
        }.onHover(perform: { hovering in
            isHovering = hovering
        })
    }
}

#Preview("Markdown") {
    let message: String = """
This is a **markdown** formated message

- item 1
- item 2
"""
    let store: StoreOf<ChatBubble> = .init(
        initialState: ChatBubble.State(
            id: UUID().uuidString,
            message: message
        )
    ) {
        ChatBubble()
    }
    return VStack {
        ChatBubbleView(store: store)
        Spacer()
    }
}
#Preview("Empty") {
    let message: String = ""
    let store: StoreOf<ChatBubble> = .init(
        initialState: ChatBubble.State(
            id: UUID().uuidString,
            message: message,
            editMode: true
        )
    ) {
        ChatBubble()
    }
    return VStack {
        ChatBubbleView(store: store)
        Spacer()
    }
}
