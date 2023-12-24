//
//  InputClient.swift
//  AIPlayground
//
//  Created by stephane on 9/28/23.
//

import Foundation
import Dependencies
import Quartz
import NaturalLanguage

struct Paragraph {
    let text: String
    var sentences: [String] {
        text.splitIntoSentences()
    }
}

extension String {
    
    func splitIntoParagraphs() -> [String] {
        var paragraphs = [String]()
        let tokenizer = NLTokenizer(unit: .paragraph)
        
        let preparedString = self.replacingOccurrences(of: ".\n", with: "[[PEND]]").replacingOccurrences(of: "-\n", with: "").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "[[PEND]]", with: ".\n")
        tokenizer.string = preparedString

        
        
        
        tokenizer.enumerateTokens(in: preparedString.startIndex..<preparedString.endIndex) { range, _ in
            paragraphs.append(String(preparedString[range]))//.trimmingCharacters(in: .newlines))
            return true
        }
        dump(paragraphs)
        
        var stats: (min: Int, max: Int, avg: Float) = (99999999,0,0)
        
        paragraphs.enumerated().forEach { element in
            let count = element.element.count
            stats.max = max(count, stats.max)
            stats.min = min(count, stats.min)
            stats.avg = ((stats.avg * (Float(element.offset + 1))) + Float(count)) / Float(element.offset + 1)
        }
        dump(stats)
        return paragraphs
    }
    
    func splitIntoSentences() -> [String] {
        var sentences = [String]()
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = self

        tokenizer.enumerateTokens(in: self.startIndex..<self.endIndex) { range, _ in
            sentences.append(String(self[range]).trimmingCharacters(in: .newlines))
            return true
        }

        return sentences
//
//        let reduced = sentences.reduce(into: [String]()) { partialResult, s in
//            guard let lastSentence = partialResult.last else {
//                partialResult.append(s)
//                return
//            }
////            print("last: [\(lastSentence)] -> new> [\(s)]")
//            if lastSentence.hasSuffix("-") {
//                partialResult[partialResult.count-1] = (lastSentence + s).replacingOccurrences(of: "-\(s)", with: s)
//            } else if !lastSentence.hasSuffix(". "){
//                partialResult[partialResult.count-1] = lastSentence + " " + s
//            } else {
//                partialResult.append(s)
//            }
//        }
//        return reduced
    }
}




public struct PickedFile:Equatable {
    let url: URL
    var data: Data? {
        get async throws {
            try Data(contentsOf: url)
        }
    }
    var asStructuredDoc: StructuredDoc {
        get async throws {
            
            if url.pathExtension == "pdf" {
                let pdf = PDFDocument(url: url)
                guard let pdf else { return .init(url: url, title: "Wrong pdf doc", elements: [])}
                dump(pdf.outlineRoot)
                print(pdf.outlineRoot?.action)
                guard let body = pdf.string else { return .init(url: url, title: "Wrong pdf content", elements: [])}
                var chapters: [Paragraph] = body.splitIntoParagraphs().map { .init(text: $0) }
                
                guard chapters.count > 0 else { return .init(url: url, title: "Empty pdf content", elements: [])}
                let title = chapters.removeFirst().sentences.first ?? ""
                return .init(url: url, title: title , elements: chapters.map {
                    .child(.init(url: url, title: $0.sentences.first ?? "", elements: $0.sentences.map { .text($0)}))
                })
            } else {
                let body = try String(contentsOf: url)
                var paragraphs = body.components(separatedBy: "\n\n").compactMap { str in
                    let r = str.trimmingCharacters(in:.whitespacesAndNewlines)
                    return r.isEmpty ? nil : r
                }
                guard paragraphs.count > 0 else { return .init(url: url, title: "Empty content", elements: [])}
                let title = paragraphs.removeFirst()
                
                return .init(url: url, title: paragraphs.first!, elements: paragraphs.map {
                    .text($0)
                })
            }
        }
    }
    var asString: String {
        get async throws {
            if url.pathExtension == "pdf" {
                // return pdf text
                let pdf = PDFDocument(url: url)
                return pdf!.string!
            } else {
                return try String(contentsOf: url)
            }
        }
    }
}
public struct InputClient {
    public var prompt: (String) async -> String?
    public var confirm: (String) async -> Bool
    public var pickFile: (Bool) async -> PickedFile?
    public init(
        prompt: @Sendable @escaping (String) async -> String?,
        confirm: @Sendable @escaping (String) async -> Bool,
        pickFile: @Sendable @escaping (Bool) async -> PickedFile?
    ) {
        self.prompt = prompt
        self.confirm = confirm
        self.pickFile = pickFile
    }
    public func pickFolder() async -> PickedFile? {
        await pickFile(true)
    }
}

extension InputClient: TestDependencyKey {
    public static var testValue: InputClient {
        .init(
            prompt: XCTUnimplemented("\(Self.self).prompt"),
            confirm: XCTUnimplemented("\(Self.self).confirm"),
            pickFile: XCTUnimplemented("\(Self.self).pickFile")
        
        )
    }
    public static var previewValue: InputClient {
        .init(
            prompt: { "name_for_\($0)"},
            confirm: { _ in false },
            pickFile: { _ in .init(url: .init(filePath: "/")) }
        )
    }
}
public extension DependencyValues {
    var inputClient: InputClient {
        get { self[InputClient.self]}
        set { self[InputClient.self] = newValue}
    }
}
