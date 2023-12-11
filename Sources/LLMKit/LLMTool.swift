//
//  File.swift
//  
//
//  Created by stephane on 12/8/23.
//

import Foundation

public enum ToolSchema {
    case object([String: ToolSchema])
    case property(JSONSchema.Property)
}

public protocol Tool {
    associatedtype Payload: ToolPayload & Decodable
    func call(_ payload: Payload) async throws -> String?
}
public extension Tool {
    static func toolDef(name: String? = nil, description: String) -> Model.ToolDef? {
        Payload.toolDef(name: name ?? "\(Self.self)", description: description)
    }
    func decode(_ string: String) throws -> Self.Payload? {
        let decoder = JSONDecoder()
        return try decoder.decode(Payload.self, from: string.data(using: .utf8)!)
    }
    static func decode(_ string: String) throws -> Self.Payload? {
        let decoder = JSONDecoder()
        return try decoder.decode(Payload.self, from: string.data(using: .utf8)!)
    }
}

public protocol ToolPayload: Decodable {
    static var toolSchema: ToolSchema { get }
}

public extension ToolPayload {
    static func toolDef(name: String, description: String) -> Model.ToolDef? {
        self.toolSchema.jsonSchema.map {
            .init(type: .function, function: .init(description: description, name: name, parameters: $0))
        }
    }
}

public extension ToolSchema {
    var jsonSchemaProperty: JSONSchema.Property {
        switch self {
        case .object( let dictionary):
            let mappedDict = dictionary.mapValues { $0.jsonSchemaProperty }
            return .init(type: .object, items: .init(type: .object, properties: mappedDict))
        case .property(let property):
            return property
        }
    }
    var jsonSchema : JSONSchema? {
        switch self {
        case .object(let dictionary):
            let mappedDict = dictionary.mapValues { $0.jsonSchemaProperty }
            return .init(type: .object, properties: mappedDict)
        case .property:
            return nil
        }
    }
}

extension String: ToolPayload {
    public static var toolSchema: ToolSchema {
        .property(.init(type: .string))
    }
}
extension Bool: ToolPayload {
    public static var toolSchema: ToolSchema {
        .property(.init(type:.boolean))
    }
}
extension Int: ToolPayload {
    public static var toolSchema: ToolSchema {
        .property(.init(type: .integer))
    }
}
extension Float: ToolPayload {
    public static var toolSchema: ToolSchema {
        .property(.init(type: .number))
    }
}
extension Double: ToolPayload {
    public static var toolSchema: ToolSchema {
        .property(.init(type: .number))
    }
}
