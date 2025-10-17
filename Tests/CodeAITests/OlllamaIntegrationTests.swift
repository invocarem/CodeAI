@testable import CodeAI
import XCTest
import XCTVapor
import Foundation

final class OllamaIntegrationTests: BaseAIIntegrationTests {
    override func setUp() {
      print ("=== OllamaIntegrationTests setUp ===")
      super.setUp()
   }

    override func skipIfNotConfigured() throws {
        let currentProvider = Config.aiProvider.lowercased()
        guard currentProvider == "ollama" else {
            throw XCTSkip("Ollama is not the currently configured provider (current: \(currentProvider))")
        }
        guard Config.isConfigured() else {
            throw XCTSkip("Ollama is not properly configured")
        }
    }
    
    func testChatCompletionWithOllama() throws {
        try skipIfNotConfigured()
        
        let chatRequest = try loadChatRequest()
        
        try self.app.test(.POST, "v1/chat/completions", beforeRequest: { req in
            try req.content.encode(chatRequest)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertFalse(response.choices.isEmpty)
            
            let content = response.choices[0].message.content
            print("Ollama chat response: \(String(describing: content.prefix(200)))...")
            XCTAssertTrue(content.contains("```swift") || content.contains("/* 1 */") || content.contains("private let"))
        }
    }
    
    func testChatCompletionWithRawDataOllama() throws {
        try skipIfNotConfigured()
        
        let chatInputData = try TestHelpers.loadTestJSON("chat-input")
        
        try self.app.test(.POST, "v1/chat/completions") { req in
            req.headers.contentType = .json
            req.body = .init(data: chatInputData)
        } afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(ChatCompletionResponse.self)
            XCTAssertFalse(response.choices.isEmpty)
            
            let content = response.choices[0].message.content
            print("Ollama raw data response: \(String(describing: content.prefix(200)))...")
            XCTAssertTrue(content.contains("```swift") || content.contains("/* 1 */") || content.contains("private let"))
        }
    }
    func testRenumberVersesWithOllama() throws {
      print("=== TEST DEBUG ===")
      try skipIfNotConfigured()
      print("Ollama URL: \(Config.ollamaBaseUrl)")
      print("Model: \(Config.defaultModel)")
       
      let command = try loadAPICommand()
      print("=== command done ===")
      
      try self.app.test(.POST, "renumber-verses", beforeRequest: { req in
          try req.content.encode(command)
      }) { res in
          XCTAssertEqual(res.status, .ok)
          
          // Try a safer approach to decode the response
          let responseBody = res.body
          if let data = responseBody.getData(at: responseBody.readerIndex, length: responseBody.readableBytes) {
              let response = try JSONDecoder().decode([String: String].self, from: data)
              let formattedCode = response["formatted_code"] ?? ""
              
              print("Renumber verses response: \(String(describing: formattedCode.prefix(200)))...")
              
              // Check for Swift array formatting patterns
              XCTAssertTrue(formattedCode.contains("private let") || formattedCode.contains("[") || formattedCode.contains("]"))
              XCTAssertTrue(formattedCode.contains("/*") || formattedCode.contains("*/") || formattedCode.contains("\""))
          } else {
              XCTFail("No response data received")
          }
      }
  }
      
    func testOllamaSpecificModels() throws {
        try skipIfNotConfigured()
        
        // Test with different Ollama models that are commonly available
        let models = ["mistral:latest", "llama2:latest", "codellama:latest"]
        let baseRequest = try loadChatRequest()
        
        for model in models {
            print("Testing Ollama model: \(model)")
            
            let chatRequest = ChatCompletionRequest(
                model: model,
                messages: baseRequest.messages,
                maxTokens: baseRequest.maxTokens,
                temperature: baseRequest.temperature,
                stream: baseRequest.stream
            )
            
            try app.test(.POST, "v1/chat/completions", beforeRequest: { req in
                try req.content.encode(chatRequest)
            }) { res in
                XCTAssertEqual(res.status, .ok, "Model \(model) should work with Ollama")
                let response = try res.content.decode(ChatCompletionResponse.self)
                XCTAssertFalse(response.choices.isEmpty)
                
                let content = response.choices[0].message.content
                XCTAssertFalse(content.isEmpty, "Response from model \(model) should not be empty")
                print("Model \(model) response length: \(content.count)")
            }
        }
    }
    
    func testOllamaStreamingResponse() throws {
        try skipIfNotConfigured()
   
        // Create a new request with streaming enabled instead of modifying existing one
        let baseRequest = try loadChatRequest()
        let chatRequest = ChatCompletionRequest(
            model: baseRequest.model,
            messages: baseRequest.messages,
            maxTokens: baseRequest.maxTokens,
            temperature: baseRequest.temperature,
            stream: true
        )
        
        try self.app.test(.POST, "v1/chat/completions", beforeRequest: { req in
            try req.content.encode(chatRequest)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            
            // For streaming, we should get a text/event-stream response
            let contentType = res.headers.first(name: "Content-Type")
            XCTAssertTrue(contentType?.contains("text/event-stream") == true || contentType?.contains("application/json") == true)
            
            let body = res.body
            XCTAssertNotNil(body)
            
            // Basic check that we got some response data
            if let data = body.getData(at: body.readerIndex, length: body.readableBytes) {
                let responseString = String(data: data, encoding: .utf8) ?? ""
                XCTAssertFalse(responseString.isEmpty)
                print("Streaming response preview: \(String(describing: responseString.prefix(200)))...")
            }
        }
    }
    
    func testOllamaHealthCheck() throws {
        try skipIfNotConfigured()
        
        try self.app.test(.GET, "health") { res in
            XCTAssertEqual(res.status, .ok)
            let health = try res.content.decode(HealthResponse.self)
            
            XCTAssertEqual(health.provider, "ollama")
            XCTAssertTrue(health.configured)
            XCTAssertTrue(health.ok)
            
            print("Ollama health check - Provider: \(health.provider), Configured: \(health.configured), Model: \(health.model)")
        }
    }
}