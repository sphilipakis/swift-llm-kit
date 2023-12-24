//
//  Rag.swift
//  SampleApp
//
//  Created by stephane on 12/15/23.
//

import Foundation
import ComposableArchitecture
import SimilaritySearchKit
import SimilaritySearchKitDistilbert
import SwiftUI
import LLMKit
import LLMKitOpenAI
import LLMKitOllama

struct RagClient {
    let engine: () async throws -> RagEngine
    init(
        engine: @Sendable @escaping () async throws -> RagEngine
    ) {
        self.engine = engine
    }
}
struct StorageClient {
    let storage: () async throws -> DocStorage
    init(storage: @escaping () -> DocStorage) {
        self.storage = storage
    }
}

let _previewStorage: MemoryDocStorage = {
    .init(documents: [], extractor: Extractor.pdf(llm: Infering<ChatLog,  ChatLog, OllamaClientErrorResponse>.ollama(
        model: "mistral:latest",
        idGenerator: .init {
            UUID().uuidString
        }
    )
    ).caching() )
}()
extension StorageClient: TestDependencyKey {
    static var testValue: StorageClient {
        .init(storage: XCTUnimplemented("\(Self.self).storage"))
    }
    static var previewValue: StorageClient {
        return .init {
            _previewStorage
        }
    }
}
extension DependencyValues {
    var storage: StorageClient {
        get { self[StorageClient.self]}
        set { self[StorageClient.self] = newValue}
    }
}

extension StructuredDoc: Identifiable {
    public var id: String {
        url.absoluteString
    }
}

actor MemoryDocStorage: DocStorage {
    @Published var documents: IdentifiedArrayOf<StructuredDoc> = []
    let extractor: Extractor<PickedFile>
    init(documents: IdentifiedArrayOf<StructuredDoc> = [], extractor: Extractor<PickedFile>) {
//        self.documents = documents
        self.extractor = extractor
    }
    func addDoc(at url: String) async throws -> StructuredDoc? {
        guard let u = URL(string: url) else { return nil }
        let structuredDoc = try await extractor.structuredDoc(PickedFile(url: u))
        documents.append(structuredDoc)
        return structuredDoc
    }
    func getDoc(at url: String) async throws -> StructuredDoc? {
        documents[id: url]
    }
    
    func setDoc(at url: String, doc: StructuredDoc) async throws {
        documents[id: url] = doc
    }
    
    func removeDoc(at url: String) async throws {
        documents.remove(id: url)
    }
    
    func docURLs() async throws -> [String] {
        Array(documents.ids)
    }
    func documentsStream() async throws -> AsyncStream<IdentifiedArrayOf<StructuredDoc>> {
        $documents.values.eraseToStream()
    }
    
}


extension RagClient: TestDependencyKey {
    static var testValue: RagClient {
        .init(engine: XCTUnimplemented("\(Self.self).engine"))
    }
    static var previewValue: RagClient {
        let rag: RagEngine = .init(
            storage: _previewStorage,
            llm: LLMKit.ollama(url: URL(string: "http://localhost:11434")!, model: "mistral:latest").mapError({ error in
                error.error
            })
        )
        return .init {
            rag
        }
    }
}
extension DependencyValues {
    var ragClient: RagClient {
        get { self[RagClient.self]}
        set { self[RagClient.self] = newValue}
    }
}

@Reducer
struct RagFeature  {
    @Dependency(\.storage) var storage
    @Dependency(\.ragClient) var ragClient
    @Dependency(\.inputClient) var inputClient

    @ObservableState
    struct State {
        var ready = false
        var docStats: IdentifiedArrayOf<DocStats> = []
//        var docsCount: Int = 0
//        var fragmentsCount: Int = 0
//        var embeddingsCount: Int = 0
        var error: String?
        var query: String = ""
        var resultsQuery: String? = nil
        var results: IdentifiedArrayOf<GroupScore> = []
        var response: ChatLog?

        var documents: IdentifiedArrayOf<StructuredDoc> = []
    }
    
    enum Action {
        case start
        case browseButtonClicked
        case setIndexReady(Bool, URL?, Int, String?)
        case setQuery(String)
        case runQuery
        case updateResponse(String, ChatLog)
        case updateResults(String, IdentifiedArrayOf<GroupScore>)
        case updateRagEngineStatus(RagEngine.Status)
        case updateDocuments(IdentifiedArrayOf<StructuredDoc>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateDocuments(docs):
                state.documents = docs
                return .none
            case let .updateRagEngineStatus(s):
                state.docStats = s.docStats
//                state.embeddingsCount = s.embeddingsCount
//                state.fragmentsCount = s.fragmentsCount
//                state.docsCount = s.docsCount
                return .none
            case .start:
                return
                    .merge(
                        .run { send in
                            for await s in try await ragClient.engine().statusStream {
                                await send(.updateRagEngineStatus(s))
                            }
                    },
                        .run { send in
                            for await docs in try await storage.storage().documentsStream() {
                                await send(.updateDocuments(docs))
                            }
                    }


                    
                    
                    )
            case .updateResponse(let q, let r):
                state.resultsQuery = q
                state.response = r
                return .none
            case .updateResults(let q, let r):
                state.resultsQuery = q
                state.results = r
                return .none
            case .runQuery:
                return .run { [query = state.query] send in
                    do {
                        if let result = try await ragClient.engine().runQuery(query) {
                            await send(.updateResponse(query, result))
                        }
                    } catch {
                        print("Error", error)
                    }
//                    await send(.updateResults(query, result))
                }
            case let.setQuery(q):
                state.query = q
                return .none
            case let .setIndexReady(b,url, embeddingsCount, error):
                state.ready = b
                state.error = error
//                state.embeddingsCount = embeddingsCount
                return .none
            case .browseButtonClicked:
                state.ready = false
                return .run { send in
                    if let pickedFile = await self.inputClient.pickFile(false) {
                        print("picked",pickedFile)
                        let url = pickedFile.url
                        do {
                            try await ragClient.engine().addURL(url)
//                            let (indexed, root, embeddings) =
//                            await send(.setIndexReady(indexed,root, embeddings, nil))
                        } catch {
                            await send(.setIndexReady(false, nil, 0, error.localizedDescription))
                        }
                    }
                }
            }
        }
    }
}

struct RagView: View {
    @Bindable var store: StoreOf<RagFeature>
    var body: some View {
        
        HSplitView {
            ScrollView{
                VStack(alignment: .leading) {
                    Section {
                        ForEach(store.documents, id: \.id) { doc in
                            VStack {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text(doc.url.lastPathComponent)
                                    Spacer()
                                }
                                if let stats = store.docStats[id: doc.id] {
                                    HStack {
                                        Spacer()
                                        Text("Embeddings:")
                                        Text("\(stats.embeddingsCount)/\(stats.fragmentsCount)")
                                    }
                                }
                            }
                            .padding(.leading)

                        }
                    } header: {
                        HStack{
                            Text("Documents")
                            Spacer()
                            Text("\(store.documents.count)")
                            Button(action: {
                                store.send(.browseButtonClicked)
                            }) {
                                Text("Add Document")
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding()
            .frame(minWidth: 250)

            VStack(alignment: .leading) {
                HStack {
                    if let err = store.error {
                        Text(err)
                    }
                }
                ScrollView {
                    HStack {
                    }
                    Divider()
                    if let q = store.resultsQuery {
                        Text("Query: \(q)")
                            .font(.title)
                    }
                    Divider()
                    if let c = store.response {
                        ForEach(0..<c.items.count, id:\.self) { idx in
                            let item = c.items[idx]
                            ChatBubbleView2<Any>(item: item, runTool: { _,_,_ in })
                        }
                    }
                    ForEach(store.results, id:\.id) { r in
                    
                        HStack(alignment: .top) {
                            Text("\(Int(r.score * 100))").font(.title).foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                ForEach(0..<r.scoredElements.count, id: \.self) { index in
                                    let scoredSentence: (String, Float) = r.scoredElements[index]
                                    HStack(alignment: .top) {
                                        Text("\(Int(scoredSentence.1 * 100))%")
                                            .foregroundStyle(.secondary)
                                        Text(scoredSentence.0)
                                            .foregroundColor(.white.opacity(Double(scoredSentence.1 + 1.0)/2.0))
                                    }
                                }
    //                            Text(r.)
    //                                .lineLimit(5)
    //                            Text(r.id)
    //                                .font(.caption)
    //                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.padding()
                    }
                    
                    
                }
                TextField("Query", text: $store.query.sending(\.setQuery))
                    .onSubmit {
                        store.send(.runQuery)
                    }
            }
        }
        .task {
            store.send(.start)
        }
    }
}
#Preview {
    let store: StoreOf<RagFeature> = .init(initialState: .init()) {
        RagFeature()
    }
    return RagView(store: store)
}
