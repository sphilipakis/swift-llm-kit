import XCTest
@testable import LLMKit
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import LLMToolMacros

final class LLMKitTests: XCTestCase {
    private var apiKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!
    }
    func test_fallback_on_success() async throws {
        let failingLLM: LLMKit = .init { chain in
            chain.appending(chain.output.appending(.assistant("how can I help", tool_calls: nil)))
        }
        let fallbackLLM: LLMKit = .echo
        let llm: LLMKit = failingLLM.fallback(to: fallbackLLM)
        let result = try await llm.complete(.init([.init(system: "system prompt", messages: [])]))
        XCTAssertEqual(result.output.lastMessage.content, "how can I help")
    }
    func test_fallback_on_error() async throws {
        enum TestError: Error {
            case firstError
        }
        let failingLLM: LLMKit = .init { chatLog in
            throw TestError.firstError
        }
        let fallbackLLM: LLMKit = .echo
        let llm: LLMKit = failingLLM.fallback(to: fallbackLLM)
        let result = try await llm.complete(.init([.init(system: "system prompt", messages: [])]))
        XCTAssertEqual(result.output.lastMessage.content, result.input.system)
    }

    func test_tracking() async throws {
        let tracker = LLMKit.Tracker(0) { $0($1+1) }
        let tracked: LLMKit = .echo.tracked(tracker)
        _ = try await tracked.complete(.init([.init(system: "hello", messages: [])]))
        let count = await tracker.value
        XCTAssertEqual(count, 1)
    }
    func test_pipe() async throws {
        let llm0: LLMKit = .echo
        let llm1: LLMKit = .init { chain in
            chain.appending { chatLog in
                .assistant(String((chatLog.lastMessage.content ?? "").count), tool_calls: nil)
            }
        }
        let tracker0 = LLMKit.Tracker(0) { $0($1+1) }
        let tracker1 = LLMKit.Tracker(0) { $0($1+1) }
        let llm = llm0.tracked(tracker0).pipe(to: llm1.tracked(tracker1))
        let completion = try await llm.complete(.init([.init(system: "hello", messages: [])]))
        let count0 = await tracker0.value
        let count1 = await tracker1.value
        XCTAssertEqual(count0, 1)
        XCTAssertEqual(count1, 1)
        XCTAssertEqual(completion.chatLogs.count, 3)
        XCTAssertEqual(completion.output.messages.count, 2)
        dump(completion)
    }
    
    func test_withModifier_append() async throws {
        let modifier: LLMKit = .systemPromptModifier({ "\($0) world!"}, mode: .append)
        let llm: LLMKit = .echo
        let completion = try await llm.withModifier(modifier).complete(.init([.init(system: "hello", messages: [])]))
        XCTAssertEqual("hello world!", completion.output.lastMessage.content)
        XCTAssertEqual("hello world!", completion.output.system)
        XCTAssertEqual("hello", completion.input.system)
        dump(completion)
    }
    func test_withModifier_replace() async throws {
        let modifier: LLMKit = .systemPromptModifier({ "\($0) world!"}, mode: .replace)
        let llm: LLMKit = .echo
        let completion = try await llm.withModifier(modifier).complete(.init([.init(system: "hello", messages: [])]))
        XCTAssertEqual("hello world!", completion.output.lastMessage.content)
        XCTAssertEqual("hello world!", completion.output.system)
        XCTAssertEqual("hello world!", completion.input.system)
        dump(completion)
    }
    func test_compacting() async throws {
        let llm = LLMKit.echo.compact
        var completion: CompletionChain = try .init([.init(system: "hello!", messages: [])])
        for _ in (0..<5)  {
            completion = try await llm.complete(completion)
        }
        XCTAssertEqual(completion.chatLogs.count, 2)
        dump(completion)
    }
}
