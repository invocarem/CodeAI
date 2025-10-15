// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "CodeAI",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0")
  ],
  targets: [
    .executableTarget(
      name: "CodeAI",
      dependencies: [
        .product(name: "Vapor", package: "vapor")
      ]
    ),
    .testTarget(name: "CodeAITests", dependencies: [
      .target(name: "CodeAI"),
      .product(name: "XCTVapor", package: "vapor")
    ])
  ]
)
