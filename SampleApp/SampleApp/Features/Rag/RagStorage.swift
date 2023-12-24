//
//  RagStorage.swift
//  SampleApp
//
//  Created by stephane on 12/18/23.
//

import Foundation
import ComposableArchitecture
import SwiftUI


public struct DocumentStorageClient {
    public var documentsStream: () async throws -> AsyncStream<[StoredDocument]>
    public init(documentsStream: @escaping () -> AsyncStream<[StoredDocument]>) {
        self.documentsStream = documentsStream
    }
}



extension DocumentStorageClient: TestDependencyKey {
    public static var testValue: DocumentStorageClient {
        .init(documentsStream: XCTUnimplemented("\(Self.self).documentsStream"))
    }
    public static var previewValue: DocumentStorageClient {
        .init {
            .init { continuation in
                continuation.yield(
                    (0..<10).map {
                        StoredDocument(id: "document \($0)", name: "document \($0).png")
                    }
                )
            }
        }
    }
}

public extension DependencyValues {
    var documentStorageClient: DocumentStorageClient {
        get {
            self[DocumentStorageClient.self]
        }
        set {
            self[DocumentStorageClient.self] = newValue
        }
    }
}

public struct StoredDocumentStats {
    var embeddingsCount: Int = 0
    var indexingProgress: Float = 0
}
public struct StoredDocument: Identifiable {
    public let id: String
    let name: String
    var stats: StoredDocumentStats = .init()
}

public struct DocumentStorageView: View {

    @Reducer
    struct Feature {
        @Dependency(\.documentStorageClient) var documentStorageClient
        
        @ObservableState
        struct State {
            var documents: IdentifiedArrayOf<StoredDocument> = []
            init(documents: IdentifiedArrayOf<StoredDocument>) {
                self.documents = documents
            }
        }
        enum Action {
            case start
            case setDocuments(IdentifiedArrayOf<StoredDocument>)
        }
        var body: some ReducerOf<Self> {
            Reduce { state, action in
                switch action {
                case .start:
                    return .run { send in
                        for await docs in try await documentStorageClient.documentsStream() {
                            await send(.setDocuments(.init(uniqueElements: docs)))
                        }
                    }
                case let .setDocuments(docs):
                    state.documents = docs
                    return .none
                }
            }
        }
    }
    
    
    let store: StoreOf<Feature>

    @State var hoverIndices: Set<String> = .init()
    
    public var body: some View {
        ScrollView {
            VStack(spacing:10) {
                ForEach(store.documents, id: \.id) { document in
                    HStack(alignment: .top) {
                        Image(systemName: "doc.text.fill")
                        VStack(alignment: .leading){
                            Text(document.name)
                            HStack {
                                Text("Embeddings: \(document.stats.embeddingsCount)")
                                Text("Indexing: \(Int(document.stats.indexingProgress * 100.0))%")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if (hoverIndices.contains(document.id)) {
                            Button(action:{ }) {
                                Image(systemName: "xmark")
                                Text("Remove")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onHover(perform: { hovering in
                        if hovering {
                            hoverIndices.insert(document.id)
                        } else {
                            hoverIndices.remove(document.id)
                        }
                    })
                }
                Spacer()
            }
        }
        .task {
            store.send(.start)
        }
    }
    
}


#Preview {
    DocumentStorageView(
        store: .init(
            initialState: .init(
                documents: .init(uniqueElements: [StoredDocument]())
            )
        ) {
            DocumentStorageView.Feature()
        }
    )
    .padding()
    .frame(width: 340)
}
