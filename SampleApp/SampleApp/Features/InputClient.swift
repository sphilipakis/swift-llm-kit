//
//  InputClient.swift
//  AIPlayground
//
//  Created by stephane on 9/28/23.
//

import Foundation
import Dependencies
import Quartz

public struct PickedFile:Equatable {
    let url: URL
//    let data: Data
    var data: Data? {
        get async throws {
            try Data(contentsOf: url)
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
    public var pickFile: () async -> PickedFile?
    public init(
        prompt: @Sendable @escaping (String) async -> String?,
        confirm: @Sendable @escaping (String) async -> Bool,
        pickFile: @Sendable @escaping () async -> PickedFile?
    ) {
        self.prompt = prompt
        self.confirm = confirm
        self.pickFile = pickFile
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
            pickFile: { .init(url: .init(filePath: "/")) }
        )
    }
}
public extension DependencyValues {
    var inputClient: InputClient {
        get { self[InputClient.self]}
        set { self[InputClient.self] = newValue}
    }
}
