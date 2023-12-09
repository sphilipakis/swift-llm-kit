// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-llm-kit",
    platforms: [.iOS(.v15),.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LLMKit",
            targets: ["LLMKit"]),
        .library(name: "LLMKitOpenAI", targets: ["LLMKitOpenAI"])
    ],
    dependencies: [
        .package(
              url: "https://github.com/apple/swift-syntax.git",
              from: "509.0.0"
              ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LLMKit",
            dependencies: ["LLMToolMacros"]
        ),
        .testTarget(
            name: "LLMKitTests",
            dependencies: ["LLMKit", .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),]),
        .target(
            name: "LLMKitOpenAI",
            dependencies: ["LLMKit"]
        ),
        .testTarget(
            name: "LLMKitOpenAITests",
            dependencies: ["LLMKitOpenAI"]
        ),
        .macro(name: "LLMToolMacros",
              dependencies: [
                .product(
                          name: "SwiftSyntaxMacros",
                          package: "swift-syntax"
                        ),
                        .product(
                          name: "SwiftCompilerPlugin",
                          package: "swift-syntax"
                        )
              ]),
        
    ]
)
