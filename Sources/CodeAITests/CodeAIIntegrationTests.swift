@testable import CodeAI
import XCTest
import XCTVapor

final class CodeAIIntegrationTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func skipIfNotConfigured(provider: String) throws {
        // Check if the requested provider is currently configured
        let currentProvider = Config.aiProvider.lowercased()
        guard currentProvider == provider.lowercased() else {
            throw XCTSkip("\(provider) is not the currently configured provider (current: \(currentProvider))")
        }
        
        // Check if the provider is properly configured
        guard Config.isConfigured() else {
            throw XCTSkip("\(provider) is not properly configured")
        }
    }
    
    // MARK: - AI Provider Integration Tests
    
    func testOllamaProviderIntegration() throws {
        // Skip if Ollama is not configured
        try skipIfNotConfigured(provider: "ollama")
        
        let app = try Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        
        let chatRequest = ChatCompletionRequest(
            model: "mistral:latest",
            messages: [Message(role: "user", content: "Say 'Hello World'")],
            maxTokens: 100,
            temperature: 0.0,
            stream: false
        )
        
        try app.test(.POST, "v1/chat/completions", beforeRequest: { req in
            try req.content.encode(chatRequest)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertFalse(response.choices.isEmpty)
            let content = response.choices[0].message.content
            XCTAssertTrue(content.contains("Hello") || content.contains("World"))
        }
    }
    
    func testOpenAIProviderIntegration() throws {
        // Skip if OpenAI is not configured
        try skipIfNotConfigured(provider: "openai")
        
        let app = try Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        
        let chatRequest = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [Message(role: "user", content: "Say 'Hello World'")],
            maxTokens: 100,
            temperature: 0.0,
            stream: false
        )
        
        try app.test(.POST, "v1/chat/completions", beforeRequest: { req in
            try req.content.encode(chatRequest)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertFalse(response.choices.isEmpty)
            // OpenAI should return a coherent response
            XCTAssertTrue(response.choices[0].message.content.count > 5)
        }
    }
    
    func testRenumberVersesWithAI() throws {
        // Skip if no AI provider is configured
        try skipIfNotConfigured(provider: Config.aiProvider)
        
        let app = try Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        
        let swiftCode = """
        let verses = [
            Verse(reference: "1:1", text: "First verse content"),
            Verse(reference: "1:3", text: "Third verse content")
        ]
        """
        
        let command = SwiftArrayCommand(
            code: swiftCode,
            model: Config.defaultSwiftModel,
            maxTokens: Config.defaultSwiftMaxTokens,
            temperature: Config.defaultTemperature
        )
        
        try app.test(.POST, "renumber-verses", beforeRequest: { req in
            try req.content.encode(command)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode([String: String].self)
            let formattedCode = response["formatted_code"] ?? ""
            XCTAssertTrue(formattedCode.contains("Verse"))
            XCTAssertTrue(formattedCode.contains("1:1"))
            XCTAssertTrue(formattedCode.contains("1:2")) // Should be renumbered
        }
    }
}