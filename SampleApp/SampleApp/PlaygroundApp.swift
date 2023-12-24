//
//  PlaygroundApp.swift
//  SampleApp
//
//  Created by stephane on 12/23/23.
//
import SwiftUI
import ComposableArchitecture
import LLMKit

extension IDGenerator: DependencyKey {
    public static var liveValue: IDGenerator {
        .init {
            UUID().uuidString
        }
    }
}


@main
struct PlaygroundApp: App {
    var body: some Scene {
        let store: StoreOf<AppReducer> = .init(initialState: .init(
            playgrounds: .init(uniqueElements: [Playground.State]())
        )) {
            AppReducer()
                .dependency(\.persistenceClient, .files)
                .dependency(\.inferer, .previewValue)
                .dependency(\.inputClient, .init(
                    prompt: { prompt in
                        await MainActor.run {
                            let alert = NSAlert()
                                alert.messageText = prompt
                                alert.addButton(withTitle: "OK")
                                alert.addButton(withTitle: "Cancel")

                                let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    //                            textField.stringValue = defaultAnswer
                                alert.accessoryView = textField

                                let response = alert.runModal()
                                
                                if response == .alertFirstButtonReturn {
                                    return textField.stringValue
                                } else {
                                    return nil
                                }
                        }
                    
                    },
                    confirm: { prompt in
                        await MainActor.run {
                            let alert = NSAlert()
                                alert.messageText = prompt
                                alert.addButton(withTitle: "YES")
                                alert.addButton(withTitle: "NO")
                                let response = alert.runModal()
                                
                                if response == .alertFirstButtonReturn {
                                    return true
                                } else {
                                    return false
                                }
                        }
                        
                    },
                    pickFile: { @MainActor folderOnly in
                        await MainActor.run {
                            let filePanel = NSOpenPanel()
                            filePanel.canChooseDirectories = folderOnly
                            filePanel.canChooseFiles = !folderOnly
                            filePanel.allowsMultipleSelection = false
                            filePanel.canChooseFiles = true
                            filePanel.canCreateDirectories = true
                            let response = filePanel.runModal()
                            switch response {
                            case .OK:
                                guard let url = filePanel.url else { return nil }
//                                          let data = try? Data(contentsOf: url),
//                                          let string = String(data: data, encoding: .utf8) else {
//                                        return nil
//                                    }
                                return .init(url: url)
//                                    return string
                            default:
                                return nil
                            }
                        }
                    }
                ))
        }
        
        WindowGroup {
            AppView(store: store)
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppReducer>
    var body: some View {
        VStack {
            Button(action: { 
                store.send(.openButtonClicked)
            }) {
                Text("Open")
            }
            TabView {
                ForEachStore(store.scope(state: \.playgrounds, action: \.playgrounds)) { store in
                    PlaygroundView(store: store)
                        .tabItem { Text(store.id) }
                }
            }
        }
    }
}
