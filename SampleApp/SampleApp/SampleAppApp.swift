//
//  SampleAppApp.swift
//  SampleApp
//
//  Created by stephane on 12/7/23.
//

import SwiftUI
import ComposableArchitecture

//@main
struct SampleAppApp: App {
    var body: some Scene {
        let store: StoreOf<RagFeature> = .init(initialState: .init()) {
            RagFeature().dependency(\.inputClient, .init(
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
                })
            ).dependency(\.ragClient, .previewValue).dependency(\.storage, .previewValue)}
        
        WindowGroup {
            RagView(store: store)
                .padding()
        }
    }
}
