//
//  Extractor.swift
//  SampleApp
//
//  Created by stephane on 12/20/23.
//

import Foundation
import LLMKit
import Quartz

public struct Extractor<P> {
    public let structuredDoc: (P) async throws -> StructuredDoc
    public init(structuredDoc: @Sendable @escaping (P) async throws -> StructuredDoc) {
        self.structuredDoc = structuredDoc
    }
}

public extension Extractor where P == PickedFile {
    enum PDFExtractorError: Error {
        case notAPDF(URL)
        case noText(URL)
        case noParagraph(URL)
    }
    static func pdf<ERR>(llm: Infering<ChatLog, ChatLog, ERR>) -> Self {
        .init { pickedFile in
            let url = pickedFile.url
            let pdf = PDFDocument(url: pickedFile.url)
            guard let pdf else { throw PDFExtractorError.notAPDF(url) }
            guard let body = pdf.string else { throw PDFExtractorError.noText(url) }

            let template: String = """
Context information is bellow
-------
{content}
-------
Given this context information and not prior knowledge, summarize it in one paragraph.
"""

            var pageSummaries: [Paragraph] = []
            
            for p in 0..<pdf.pageCount {
                if let page = pdf.page(at: p), let pageContent = page.string {
                    let summary = try await llm.infer(.init(id: UUID().uuidString, system: "", messages: [.user(template.replacingOccurrences(of: "{content}", with: pageContent))]))
                    if case let .infered(chatLog, finished: _) = summary.result, let answer = chatLog.lastMessage.body {
                        pageSummaries.append(.init(text: "Page \(p) summary: "+answer))
                        print("Summary: page \(p)---")
                        print(answer)
                        print("")
                    }
                }
            }
            
            
            var chapters: [Paragraph] = pageSummaries + body.splitIntoParagraphs().map { .init(text: $0) }
            guard chapters.count > 0 else { throw PDFExtractorError.noParagraph(url) }

            let title = chapters.removeFirst().sentences.first ?? ""
            return .init(url: url, title: title , elements: chapters.map {
                .child(.init(url: url, title: $0.sentences.first ?? "", elements: $0.sentences.map { .text($0)}))
            })
        }
    }
}
public extension Extractor where P == PickedFile {
    func caching() -> Self {
        .init { pickedFile in
            // check if there is a cached structuredDocument
            var components = URLComponents(url: pickedFile.url, resolvingAgainstBaseURL: false)
            if let path = components?.path {
                components?.path = path + ".struct.json"
                if let cacheURL = components?.url {
                    if let data: Data = try? Data(contentsOf: cacheURL) {
                        let decoder = JSONDecoder()
                        if let structuredDoc = try? decoder.decode(StructuredDoc.self, from: data) {
                            return structuredDoc
                        }
                    }
                    let structuredDoc = try await self.structuredDoc(pickedFile)
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    if let data = try? encoder.encode(structuredDoc) {
                        try? data.write(to: cacheURL, options: .atomic)
                    }
                    return structuredDoc
                }
            }
            return try await self.structuredDoc(pickedFile)
        }
    }
}
