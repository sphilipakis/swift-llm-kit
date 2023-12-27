// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-llm-kit",
    platforms: [.iOS(.v15),.macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LLMKit",
            targets: ["LLMKit"]),
        .library(
            name: "LLMKitOpenAI",
            targets: ["LLMKitOpenAI"]
        ),
        .library(
            name: "LLMKitOllama",
            targets: ["LLMKitOllama"]
        ),
        .library(name: "LLMKitMistral", targets: ["LLMKitMistral"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0" ),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LLMKit",
            dependencies: [
                "LLMToolMacros",
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            ]
        ),
        .testTarget(
            name: "LLMKitTests",
            dependencies: [
                "LLMKit",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "LLMKitOllama",
            dependencies: ["LLMKit"]
        ),
        .testTarget(name: "LLMKitOllamaTests", dependencies: ["LLMKitOllama"]),
        .target(
            name: "LLMKitOpenAI",
            dependencies: ["LLMKit"]
        ),
        .testTarget(
            name: "LLMKitOpenAITests",
            dependencies: ["LLMKitOpenAI"]
        ),
        .target(name: "LLMKitMistral", dependencies: ["LLMKit"]),
        .testTarget(name: "LLMKitMistralTests", dependencies: ["LLMKitMistral"]),
        .macro(
            name: "LLMToolMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax" ),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax" ),
            ]
        ),
        
    ]
)
