//
//  Persistence.swift
//  SampleApp
//
//  Created by stephane on 12/23/23.
//

import Foundation
import Dependencies
import IdentifiedCollections
import Ink
import Dumpling

struct PersistenceClient {
    let save: (Playground.State, URL) async throws -> Void
    let load: (URL) async throws -> Playground.State

    init(
        save: @Sendable @escaping (Playground.State, URL) async throws -> Void,
        load: @Sendable @escaping (URL) async throws -> Playground.State
    ) {
        self.save = save
        self.load = load
    }
}
extension PersistenceClient: TestDependencyKey {
    static var testValue: PersistenceClient {
        .init(
            save: XCTUnimplemented("\(Self.self).save"),
            load: XCTUnimplemented("\(Self.self).load")
        )
    }
    static var previewValue: PersistenceClient {
        .init(save: { state, url in
            print("[PERSISTENCE] save", state, url)
        },load: { url in
            print("[PERSISTENCE] load", url)
            return .init(id: "0001",url:url,  presets: .init(), chats: .init())
        })
    }
}
extension DependencyValues {
    var persistenceClient: PersistenceClient {
        get { self[PersistenceClient.self]}
        set { self[PersistenceClient.self] = newValue}
    }
}



extension PersistenceClient {
    static var files: Self {
        .init(
            save: { state,folder in
                let fileManager = FileManager.default
                let indexURL = folder.appendingPathComponent("index.md", conformingTo: .plainText)

                var indexContent = ""
                for log in state.chats.logs {
                    indexContent += "\(log.id)\n"
                    let fileName = "log_\(log.id).md"
                    let fileURL = folder.appendingPathComponent(fileName, conformingTo: .plainText)
                    let template: String = """
    ## CHUNK:{source}:{id}
    {content}
    
    
    """
                    let markdowns = log.bubbles.reduce("") { partialResult, bubble in
                        let id = bubble.id
                        let source = switch bubble.source {
                        case .user:
                            "USER"
                        case .assistant:
                            "ASSISTANT"
                        }
                        let content = bubble.message
                        
                        return partialResult + template.replacingOccurrences(of: "{source}", with:source).replacingOccurrences(of: "{id}", with: id).replacingOccurrences(of: "{content}", with: content)
                    }
                    do {
                        try indexContent.write(to: indexURL, atomically: true, encoding: .utf8)
                        try markdowns.write(to: fileURL, atomically: true, encoding: .utf8)
                    } catch {
                        print("[PERSISTENCE] error", error)
                    }
                }
            },
            load: { folder in
                let fileManager = FileManager.default
//                guard let documentDirectory = try? fileManager.url(for: .documentDirectory,
//                                                                    in: .userDomainMask,
//                                                                    appropriateFor: nil,
//                                                                   create: false) else { return .init(presets: .init(), chats: .init())}
                let indexURL = folder.appendingPathComponent("index.md", conformingTo: .plainText)
                let indexContent = try String(contentsOf: indexURL)
//                let logIDs = indexContent.components(separatedBy: .newlines)
                let logFileURLs = indexContent.components(separatedBy: .newlines).compactMap { line -> (URL,String)? in
                    guard !line.isEmpty else { return nil }
                    return (folder.appendingPathComponent("log_\(line).md", conformingTo: .plainText), line)
                }
                var logs: IdentifiedArrayOf<Log.State> = []
                for logFileURL in logFileURLs {
                    let logContent = try String(contentsOf: logFileURL.0)
                    let chunks = logContent.parseChunkData()

                    dump(chunks)

                    var log: Log.State = .init(id: logFileURL.1 , bubbles: .init(uniqueElements: chunks.map {
                        ChatBubble.State(id: $0.id, message: $0.content, source: $0.chatBubbleSource)
                    }))
                    if var lastBubble = log.bubbles.last {
                        lastBubble.editMode = true
                        log.bubbles[id: lastBubble.id] = lastBubble
                    }
                    logs.append(log)
                }
                return .init(id: folder.lastPathComponent, url: folder, presets: .init(), chats: .init(logs: logs, selectedStoreID: logs.first?.id))
            }
        )
    }
}
struct Chunk {
    let source: String
    let id: String
    let content: String
    var chatBubbleSource: ChatBubble.Source {
        switch source {
        case "USER":
            return .user
        case "ASSISTANT":
            return .assistant
        default:
            return .assistant
        }
    }
}
extension String {
    func splitDataIntoChunks() -> [Chunk] {
        let data: String = self
        var chunks: [Chunk] = []
        
        // Split the data by newline character
        let lines = data.components(separatedBy: "\n")
        
        var currentSource = ""
        var currentID: String?
        var currentContent = ""
        
        for line in lines {
            // Check if line starts with "--- CHUNK:"
            if line.hasPrefix("## CHUNK:") {
                // If a chunk is already in progress, add it to the list
                if !currentContent.isEmpty {
                    if let id = currentID {
                        let chunk = Chunk(source: currentSource, id: id, content: currentContent.trimmingCharacters(in: .newlines).trimmingMarkdownBlockMarkers())
                        chunks.append(chunk)
                    }
                    
                    // Reset the current content
                    currentContent = ""
                }
                
                // Extract the source and id from the line
                let components = line.components(separatedBy: ":")
                if components.count >= 3 {
                    currentSource = components[1]
                    currentID = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                // Append the line to the current content
                currentContent += line.trimmingCharacters(in: .whitespacesAndNewlines)
                currentContent += "\n" // Add newline character for each line
            }
        }
        
        // Add the last chunk to the list
        if !currentContent.isEmpty {
            if let id = currentID {
                let chunk = Chunk(source: currentSource, id: id, content: currentContent.trimmingCharacters(in: .newlines).trimmingMarkdownBlockMarkers())
                chunks.append(chunk)
            }
        }
        
        return chunks
    }
}
extension String {
    func trimmingMarkdownBlockMarkers() -> String {
        // This pattern assumes that the outermost ```markdown are the start and end markers.
        let pattern = "^```markdown\n(.*?)\n```\\s*$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            if let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
                if let range = Range(match.range(at: 1), in: self) {
                    return String(self[range])
                }
            }
        }
        return self
    }
}
extension String {
//    struct ChunkData {
//        var id: String
//        var title: String
//        var content: String
//    }

    func parseChunkData() -> [Chunk] {
        let pattern = "## CHUNK:(.*?):(.*?)\\n(.*?)(?=## CHUNK:|$)"
        let regex = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsRange = NSRange(self.startIndex..<self.endIndex, in: self)
        let matches = regex.matches(in: self, options: [], range: nsRange)

        var chunks = [Chunk]()
        for match in matches {
            let titleRange = match.range(at: 1)
            let idRange = match.range(at: 2)
            let contentRange = match.range(at: 3)
            
            let title = String(self[Range(titleRange, in: self)!])
            let id = String(self[Range(idRange, in: self)!])
            let content = String(self[Range(contentRange, in: self)!]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            chunks.append(Chunk(source: title, id: id, content: content))
        }
        
        return chunks
    }
}
