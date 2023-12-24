//
//  App.swift
//  SampleApp
//
//  Created by stephane on 12/23/23.
//

import Foundation
import ComposableArchitecture

@Reducer
struct AppReducer {
    @Dependency(\.inputClient) var inputClient
    @ObservableState
    struct State {
        var playgrounds: IdentifiedArrayOf<Playground.State>
    }
    enum Action {
        case playgrounds(IdentifiedActionOf<Playground>)
        case openPlayground(String, URL)
        case openButtonClicked
    }
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .openPlayground(id,url):
                state.playgrounds.append(.init(id: id, url: url, presets: .init(), chats: .init()))
                return .none
            case .playgrounds:
                return .none
            case .openButtonClicked:
                return .run { send in
                    if let folder = await inputClient.pickFolder() {
                        await send(.openPlayground(folder.url.lastPathComponent, folder.url))
                    }
                    
                }
            }
        }
        .forEach(\.playgrounds, action: \.playgrounds) {
            Playground()
        }
    }
}
