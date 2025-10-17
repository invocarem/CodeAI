@testable import CodeAI
import Foundation
import XCTest
import XCTVapor

// MARK: - Base Test Class

class BaseAIIntegrationTests: XCTestCase {
    
    internal var app: Application!
    
    override func setUp() {
        print ("=== BaseAIIntegrationTests setUp ===")
        super.setUp()
        
        // Skip if not configured
        do {
            try skipIfNotConfigured()
        } catch {
            return // Test will be skipped
        }
        
        // Create app synchronously
        self.app = try! Application(.testing)
        try! configure(app)
    }
    
    override func tearDown() {
        try? app?.shutdown()
        app = nil
        super.tearDown()
    }
    
    // Subclasses must override this
    func skipIfNotConfigured() throws {
        fatalError("Subclasses must override skipIfNotConfigured()")
    }
    
    // Shared helper methods
    func loadChatRequest() throws -> ChatCompletionRequest {
        return try TestHelpers.loadAndDecodeJSON("chat-input", as: ChatCompletionRequest.self)
    }
    
    func loadAPICommand() throws -> SwiftArrayCommand {
        return try TestHelpers.loadAndDecodeJSON("api-input", as: SwiftArrayCommand.self)
    }
}