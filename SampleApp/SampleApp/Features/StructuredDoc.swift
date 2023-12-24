//
//  StructuredDoc.swift
//  SampleApp
//
//  Created by stephane on 12/20/23.
//

import Foundation
import LLMKit

public enum StructuredDocElement: Codable {
    case text(String)
    case child(StructuredDoc)
    var body: String {
        switch self {
        case .text(let string):
            string
        case .child(let structuredDoc):
            structuredDoc.body
        }
    }
}
public struct StructuredDoc: Codable {
    let url: URL
    let title: String
    let elements: [StructuredDocElement]
    var body: String {
        elements.map { $0.body }.joined(separator: "\n")
    }
    var fragmentsCount: Int {
        elements.reduce(0) { partialResult, elem in
            switch elem {
            case .text(let string):
                partialResult + 1
            case .child(let structuredDoc):
                partialResult + structuredDoc.fragmentsCount
            }
        }
    }
}

