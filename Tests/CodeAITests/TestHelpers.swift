import Foundation
import XCTest

/// Helper functions for loading test resources
enum TestHelpers {
  /// Loads a JSON file from the test Resources directory
  /// - Parameter filename: The name of the JSON file (without extension)
  /// - Returns: The Data contents of the file
  /// - Throws: XCTSkip if the file cannot be found
  static func loadTestJSON(_ filename: String) throws -> Data {
    guard let url = Bundle.module.url(
      forResource: filename,
      withExtension: "json",
      subdirectory: "Resources"
    ) else {
      throw XCTSkip("Could not find \(filename).json in test resources")
    }
    return try Data(contentsOf: url)
  }

  /// Loads and decodes a JSON file from the test Resources directory
  /// - Parameters:
  ///   - filename: The name of the JSON file (without extension)
  ///   - type: The Decodable type to decode into
  /// - Returns: The decoded object
  /// - Throws: XCTSkip if the file cannot be found, or decoding errors
  static func loadAndDecodeJSON<T: Decodable>(_ filename: String, as _: T.Type) throws -> T {
    let data = try loadTestJSON(filename)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(T.self, from: data)
  }
}

// MARK: - Usage Examples

/*
 Example usage in your tests:

 func testWithAPIInput() throws {
     // Load raw data
     let apiInputData = try TestHelpers.loadTestJSON("api-input")

     // Or decode directly into a model
     let apiInput = try TestHelpers.loadAndDecodeJSON("api-input", as: SwiftArrayCommand.self)

     // Use the loaded data in your test...
 }

 func testWithChatInput() throws {
     let chatInputData = try TestHelpers.loadTestJSON("chat-input")
     let chatInput = try TestHelpers.loadAndDecodeJSON("chat-input", as: ChatCompletionRequest.self)

     // Use the loaded data in your test...
 }
 */
