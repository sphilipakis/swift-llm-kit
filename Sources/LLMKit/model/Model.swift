//
//  File.swift
//  
//
//  Created by stephane on 12/5/23.
//

import Foundation


public enum  Model {
    public struct ChatCompletion: Codable {
        public let id: String
        public let object: String
        public let created: Int
        public let model: String
        public let systemFingerprint: String?
        public let choices: [Choice]
        public let usage: Usage

        enum CodingKeys: String, CodingKey {
            case id
            case object
            case created
            case model
            case systemFingerprint = "system_fingerprint"
            case choices
            case usage
        }

        public init(id: String, created: Int, model: String, systemFingerprint: String, choices: [Choice], usage: Usage) {
            self.id = id
            self.object = "chat.completion"
            self.created = created
            self.model = model
            self.systemFingerprint = systemFingerprint
            self.choices = choices
            self.usage = usage
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            object = try container.decode(String.self, forKey: .object)
            created = try container.decode(Int.self, forKey: .created)
            model = try container.decode(String.self, forKey: .model)
            systemFingerprint = try container.decodeIfPresent(String.self, forKey: .systemFingerprint)
            choices = try container.decode([Choice].self, forKey: .choices)
            usage = try container.decode(Usage.self, forKey: .usage)

            guard object == "chat.completion" else {
                throw DecodingError.dataCorruptedError(forKey: .object, in: container, debugDescription: "Invalid object value")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode("chat.completion", forKey: .object)
            try container.encode(created, forKey: .created)
            try container.encode(model, forKey: .model)
            try container.encodeIfPresent(systemFingerprint, forKey: .systemFingerprint)
            try container.encode(choices, forKey: .choices)
            try container.encode(usage, forKey: .usage)
        }
    }

    public enum FinishReason: String, Codable {
        case stop
        case length
        case contentFilter = "content_filter"
        case toolCalls = "tool_calls"
        case functionCall = "function_call"
    }
    
    public struct Choice: Codable {
        public let index: Int
        public let message: Message
        public let finishReason: FinishReason

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = try container.decode(Int.self, forKey: .index)
            message = try container.decode(Message.self, forKey: .message)
            finishReason = try container.decode(FinishReason.self, forKey: .finishReason)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(index, forKey: .index)
            try container.encode(message, forKey: .message)
            try container.encode(finishReason, forKey: .finishReason)
        }
    }

    public struct Function: Codable, Equatable {
        public let name: String
        public let arguments: String
        public init(name: String, arguments: String) {
            self.name = name
            self.arguments = arguments
        }
    }
    public enum ToolType: String, Codable, Equatable {
        case function
    }
    public struct ToolCall: Codable, Identifiable, Equatable {
        public let id: String
        public let type: ToolType
        public let function: Function
        public init(id: String, type: ToolType, function: Function) {
            self.id = id
            self.type = type
            self.function = function
        }
    }

    public struct Message: Codable {
        public let role: Role
        public let content: String?
        public let toolCalls: [ToolCall]?
        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Model.Message.CodingKeys> = try decoder.container(keyedBy: Model.Message.CodingKeys.self)
            self.role = try container.decode(Role.self, forKey: Model.Message.CodingKeys.role)
            self.content = try container.decodeIfPresent(String.self, forKey: Model.Message.CodingKeys.content)
            self.toolCalls = try container.decodeIfPresent([Model.ToolCall].self, forKey: Model.Message.CodingKeys.toolCalls)
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Model.Message.CodingKeys.self)
            try container.encode(self.role, forKey: Model.Message.CodingKeys.role)
            try container.encodeIfPresent(self.content, forKey: Model.Message.CodingKeys.content)
            try container.encodeIfPresent(self.toolCalls, forKey: Model.Message.CodingKeys.toolCalls)
        }
    }

    public struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    public struct ChatCompletionChunk: Decodable, Identifiable {
        public let id: String
        public let object: String
        public let choices: [ChunkChoice]
        public let created: Int
        public let model: String
        public let systemFingerprint: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case object
            case created
            case model
            case systemFingerprint = "system_fingerprint"
            case choices
            case usage
        }

        public init(id: String, created: Int, model: String, systemFingerprint: String, choices: [ChunkChoice]) {
            self.id = id
            self.object = "chat.completion.chunk"
            self.created = created
            self.model = model
            self.systemFingerprint = systemFingerprint
            self.choices = choices
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            object = try container.decode(String.self, forKey: .object)
            created = try container.decode(Int.self, forKey: .created)
            model = try container.decode(String.self, forKey: .model)
            systemFingerprint = try container.decodeIfPresent(String.self, forKey: .systemFingerprint)
            choices = try container.decode([ChunkChoice].self, forKey: .choices)

            guard object == "chat.completion.chunk" else {
                throw DecodingError.dataCorruptedError(forKey: .object, in: container, debugDescription: "Invalid object value")
            }
        }
    }
    
    public struct ChunkChoice: Decodable {
        public let index: Int
        public let finishReason: FinishReason?
        public let delta: Delta
        
        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
        public init(index: Int, finishReason: FinishReason, delta: Delta) {
            self.index = index
            self.finishReason = finishReason
            self.delta = delta
        }
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Model.ChunkChoice.CodingKeys> = try decoder.container(keyedBy: Model.ChunkChoice.CodingKeys.self)
            self.index = try container.decode(Int.self, forKey: Model.ChunkChoice.CodingKeys.index)
            self.delta = try container.decode(Model.Delta.self, forKey: Model.ChunkChoice.CodingKeys.delta)
            self.finishReason = try container.decodeIfPresent(Model.FinishReason.self, forKey: Model.ChunkChoice.CodingKeys.finishReason)
        }
    }
    
    public struct Delta: Decodable {
        public let content: String?
        public let toolCalls: [ToolCall]?
        public let role: Role?
    }
    
    public enum ResponseFormat: Codable {
        case jsonObject
        
        enum CodingKeys: CodingKey {
            case type
        }
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "json_object":
                self = .jsonObject
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "type \(type) not found")
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .jsonObject:
                try container.encode("json_object", forKey: .type)
            }
        }
    }
    
    public enum Role: String, Codable, Equatable {
        case system
        case user
        case assistant
        case tool
    }
    
    public enum MessageContent: Encodable {
        case system(String?)
        case user(String?)
        case assistant(String?, tool_calls: [ToolCall]?)
        case tool(String?, toolCallID: String)
        
        struct SystemPayload: Encodable {
            let content: String?
            let role: Role
            enum CodingKeys: CodingKey {
                case content
                case role
            }
        }
        struct AssistantPayload: Encodable {
            let content: String?
            let role: Role
            let toolCalls: [ToolCall]?
            enum CodingKeys:String, CodingKey {
                case content
                case role
                case toolCalls = "tool_calls"
            }
        }
        struct UserPayload: Encodable {
            let content: String?
            let role: Role
            enum CodingKeys: CodingKey {
                case content
                case role
            }
        }
        struct ToolPayload: Encodable {
            let content: String?
            let role: Role
            let toolCallId: String
            enum CodingKeys: String, CodingKey {
                case content
                case role
                case toolCallId = "tool_call_id"
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .system(let a0):
                try container.encode(SystemPayload(content: a0, role: .system))
            case .user(let a0):
                try container.encode(UserPayload(content: a0, role: .user))
            case .assistant(let a0, tool_calls:let toolCalls):
                try container.encode(AssistantPayload(content: a0, role: .assistant, toolCalls: toolCalls))
            case .tool(let a0, let toolCallID):
                try container.encode(ToolPayload(content: a0, role: .tool, toolCallId: toolCallID))
            }
        }
    }
    
    public struct ToolDef: Encodable {
        let type: ToolType
        let function: FunctionDef
        public init(type: ToolType, function: FunctionDef) {
            self.type = type
            self.function = function
        }
        public init<T>(tool: T.Type, description: String, name: String? = nil) where T:ToolPayload {
            self.type = .function
            self.function = .init(description: description, name: name ?? "\(tool)", parameters: tool.toolSchema.jsonSchema!)
        }
    }
    public struct FunctionDef: Encodable {
        public let description: String
        public let name: String
        public let parameters: JSONSchema
        public init(description: String, name: String, parameters: JSONSchema) {
            self.description = description
            self.name = name
            self.parameters = parameters
        }
    }
}

