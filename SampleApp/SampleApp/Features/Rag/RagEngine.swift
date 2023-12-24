//
//  RagEngine.swift
//  SampleApp
//
//  Created by stephane on 12/16/23.
//

import Foundation
import IdentifiedCollections
import SimilaritySearchKit
import SimilaritySearchKitDistilbert
import LLMKitOpenAI
import LLMKit

struct GroupScore: Identifiable {
    let id: String
    let scoredElements: [(String, Float)]
    var body: String {
        scoredElements.reduce("") { partial, e in
            partial + (partial.isEmpty ? "" : " ") + e.0
        }
    }
    var topScore: Float {
        scoredElements.reduce(0) { partialResult, e in
            max(partialResult, e.1)
        }
    }
    var score: Float {
        let total = scoredElements.reduce(0) { partialResult, e in
            partialResult + e.1
        }
        let count = scoredElements.filter { $0.1 > 0}.count
        return total / Float(count)
    }
    func updatingScoredElement(_ text:String,_ score: Float) -> GroupScore {
        let newScoredElements = scoredElements.map { e in
            if e.0 == text {
                return (text, score)
            } else {
                return e
            }
        }
        return GroupScore(id: id, scoredElements: newScoredElements)
    }
}

extension StructuredDoc {
    func paragraph(index: Int) -> StructuredDoc? {
        let paragraphs = elements.compactMap { e in
            switch e {
            case .child(let d):
                return d
            case .text:
                return nil
            }
        }
        guard paragraphs.count > index else { return nil }
        return paragraphs[index]
    }
}

protocol DocStorage {
    func addDoc(at url: String) async throws -> StructuredDoc?
    func getDoc(at url: String) async throws -> StructuredDoc?
//    func setDoc(at url: String, doc: StructuredDoc) async throws
    func removeDoc(at url: String) async throws
    func docURLs() async throws -> [String]
    func documentsStream() async throws -> AsyncStream<IdentifiedArrayOf<StructuredDoc>>
}


struct DocStats: Identifiable {
    let url: URL
    var id: String {
        url.absoluteString
    }
    var fragmentsCount: Int = 0
    var embeddingsCount: Int = 0
}

public class OllamaEmbeddings: EmbeddingsProtocol {
    public var tokenizer: String = "Test"
    public var model: String = "mistral:latest"
    
    public typealias TokenizerType = String
    public typealias ModelType = String
    
    public init(model: String) {
        self.model = model
    }
    
    public func encode(sentence: String) async -> [Float]? {
        var req = URLRequest(url: URL(string: "http://localhost:11434/api/embeddings")!)
        req.httpMethod = "POST"
        req.httpBody = try! JSONSerialization.data(withJSONObject: [
            "model": model,
            "prompt": sentence
        ],options: .prettyPrinted)
        let (data, response) = try! await URLSession.shared.data(for: req)
        struct Response: Decodable {
            let embedding: [Float]
        }
        let r = try? JSONDecoder().decode(Response.self, from: data)
        return r?.embedding
    }
}

actor RagEngine {
    struct Status {
        var docStats: IdentifiedArrayOf<DocStats>
    }
    
    let storage: DocStorage
    let llm: LLMKit<String>

    var _similarityIndex: SimilarityIndex?

    @Published var status: Status = .init(docStats: [])

    var statusStream: AsyncStream<Status> {
        $status.values.eraseToStream()
    }

    init(storage: DocStorage, llm: LLMKit<String>) {
        self.storage = storage
        self.llm = llm
    }

    var similarityIndex: SimilarityIndex {
        get async {
            if let _similarityIndex {
                return _similarityIndex
            } else {
                _similarityIndex = await .init(
                    model: OllamaEmbeddings(model: "mistral:latest"),
//                    model: DistilbertEmbeddings(),
                    metric: CosineSimilarity(),
                    vectorStore: BinaryStore()
                )
                return _similarityIndex!
            }
        }
    }
    func addURL(_ url: URL) async throws -> Void {
        if let doc = try await storage.addDoc(at: url.absoluteString) {
            await indexAll(doc)
        }
//        let pickedFile: PickedFile = .init(url: url)
//        let doc = try await pickedFile.asStructuredDoc
//        try await storage.setDoc(at: url.absoluteString, doc: doc)
//        Task {
//            await indexAll(doc)
//        }
    }
    
    struct DocIndexableItem {
        let url: URL
        let indexPath: [Int]
        let offset: Int
        let text: String
        var id: String {
            url.absoluteString + "#" + indexPath.map { String($0)}.joined(separator: "#")
        }
    }

    private func docIndexableItems(_ doc: StructuredDoc, indexPath: [Int], items: [DocIndexableItem]) async -> [DocIndexableItem] {
        var newItems = items
        for enumeratedElement in doc.elements.enumerated() {
            let (offset, e) = enumeratedElement
            switch e {
            case .text(let string):
                newItems.append(
                    .init(url: doc.url, indexPath: indexPath, offset: offset, text: string)
                )
            case .child(let structuredDoc):
                await newItems.append(contentsOf: docIndexableItems(structuredDoc, indexPath: indexPath + [offset], items: items))
            }
        }
        return newItems
    }
    
    private func indexAll(_ doc: StructuredDoc) async {
        let indexableItems = await docIndexableItems(doc, indexPath: [], items: [])
        status.docStats[id: doc.id] = status.docStats[id: doc.id] ?? .init(url: doc.url)
        status.docStats[id: doc.id]?.fragmentsCount = indexableItems.count
        status.docStats[id: doc.id]?.embeddingsCount = 0
//        status.fragmentsCount += indexableItems.count
        let oldIDs = await similarityIndex.indexItems.compactMap { item in
            item.id.hasPrefix(doc.url.absoluteString + "#") ? item.id : nil
        }
        for id in oldIDs {
            await similarityIndex.removeItem(id: id)
        }
        
        for element in indexableItems.enumerated() {
            let (offset, i) = element
            await similarityIndex.addItem(
                id: i.id,
                text: i.text,
                metadata: [
                    "url": i.url.absoluteString,
                    "path": i.indexPath.map { String($0) }.joined(separator: "#"),
                    "offset": String(i.offset),
                ]
            )
            status.docStats[id: doc.id]?.embeddingsCount += 1
//            status.embeddingsCount += 1// = .init(embeddingsCount: status.embeddingsCount + 1)
        }
    }
    
    
    
    struct SearchResultGroup: Identifiable {
        let id: String
        var items: [SearchResult]
        var paragraphScores: IdentifiedArrayOf<GroupScore> = []
        
    }
    
    func runQuery(_ query: String) async throws -> ChatLog? {
        let results = await similarityIndex.search(query, top: 50)
        dump(results)
        // get the top paragraph
        
        // group by url
        var grouppedResults = results.reduce(into: IdentifiedArrayOf<SearchResultGroup>() ) { partialResult, result in
            guard let url = result.metadata["url"] else { return }
            partialResult[id: url] = partialResult[id: url] ?? .init(id: url, items: [])
            partialResult[id: url]?.items.append(result)
        }
        
        for group in grouppedResults {
            var paragraphScores = IdentifiedArrayOf<GroupScore>(uniqueElements: [])
            for r in group.items {
                guard let u = r.metadata["url"],
                      let doc = try await storage.getDoc(at: u) else {
                    continue
                }

                guard let indexPath = r.metadata["path"],
                      let index = indexPath.components(separatedBy: "#").first,
                      let idx = Int(index) else {
                    continue
                }
                guard let paragraph = doc.paragraph(index: idx) else { continue }
                let p = u + "#\(idx)"
                paragraphScores[id: p] = paragraphScores[id: p].map {
                    $0.updatingScoredElement(r.text, r.score)
                }
                ?? .init(id: p, scoredElements: paragraph.elements.map { e in
                    let b = e.body
                    if b == r.text {
                        return (b, r.score)
                    } else {
                        return (b, 0)
                    }
                })
            }
            paragraphScores.sort { p0, p1 in
                p0.topScore > p1.topScore
            }
            grouppedResults[id: group.id]?.paragraphScores = paragraphScores
        }

        grouppedResults = grouppedResults.filter { $0.paragraphScores.count > 0 }
        
        guard grouppedResults.count > 0 else { return nil }
        
        let chain = CompletionChain(systemPrompt: "", idGen: { UUID().uuidString } )

        let qa_template = """
Context information is below.
---------------------
{context_str}
---------------------
Given the context information and not prior knowledge, answer the query.
Query: {query_str}
"""
        let refine_template = """
The original query is as follows: {query_str}
We have provided an existing answer: {existing_answer}
We have the opportunity to refine the existing answer
(only if needed) with some more context below.
------------
{context_str}
------------
Given the new context, refine the original answer to better answer the query.
If the context isn't useful, return the original answer.
"""
        
        
        var msg = ""
        for g in grouppedResults {
            msg += "from File `\(g.id)`:\n"
            for p in g.paragraphScores.prefix(20) {
                if p.score > 0 {
                    msg += "\n -\(p.body)"
//                    for e in p.scoredElements {
//                        if e.1 > 0 {
//                            msg += "\n- \(e.0)"
//                        } else if !msg.hasSuffix(" (...) "){
//                            msg += " (...) "
//                        }
//                    }
                }
            }
        }
        print("Call>>>")
        let r = try await llm(chain: chain, message: qa_template.replacingOccurrences(of: "{context_str}", with: msg).replacingOccurrences(of: "{query_str}", with: query), idGenerator: .init(id: { UUID().uuidString }))
        switch r {
        case let .chain(c):
            return c.output
        case let .error(err):
            print("[ERROR]", err)
            return nil
        }
    }
}

struct RagResult {
    let id: String
    let score: Float
    let metadata: [String: String]
}


struct Fragment: Identifiable {
    var id: String {
        "\(documentURL.absoluteString)_\(index)"
    }
    let index: Int
    let text: String
    let documentURL: URL
}


extension String {
    func splitIntoChunks(of maxSize: Int) -> [String] {
        let words = self.components(separatedBy: " ")
        var chunks = [String]()
        var currentChunk = [String]()

        for word in words {
            if currentChunk.count + 1 > maxSize {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = [word]
            } else {
                currentChunk.append(word)
            }
        }

        // Add the last chunk if not empty
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        return chunks
    }
    func splitIntoChunks(maxLength: Int, overlapLength: Int) -> [String] {
            let words = self.components(separatedBy: " ")
            var chunks = [String]()
            var startIndex = 0

            while startIndex < words.count {
                let endIndex = min(startIndex + maxLength, words.count)
                let chunk = words[startIndex..<endIndex].joined(separator: " ")
                chunks.append(chunk)
                
                // Move the start index forward by the length of the chunk minus the overlap length
                startIndex += maxLength - overlapLength

                // Ensure that the start index does not go back, which might happen if overlapLength >= maxLength
                startIndex = max(startIndex, 0)
            }

            return chunks
        }
}
