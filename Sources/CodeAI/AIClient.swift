import Foundation
import Vapor

final class AIClient {
  private let app: Application
  private let provider: String
  private let endpoint: String
  private let apiKey: String?
  private let timeout: Int
  private let isOpenAICompatible: Bool

  init(_ app: Application) {
    self.app = app
    provider = Config.aiProvider
    endpoint = Config.getApiEndpoint()
    apiKey = Config.getApiKey()
    timeout = Config.requestTimeout
    isOpenAICompatible = Config.isOpenAICompatible()
  }

  func isAvailable() -> Bool {
    return Config.isConfigured()
  }

  func chatCompletion(
    messages: [Message],
    model: String,
    maxTokens: Int = 4096,
    temperature: Double = 0.0
  ) async throws -> String {
    guard isAvailable()
    else {
      throw Abort(.internalServerError, reason: "AI provider '\(provider)' is not properly configured")
    }

    if isOpenAICompatible {
      return try await callOpenAICompatible(messages: messages, model: model, maxTokens: maxTokens, temperature: temperature)
    } else {
      return try await callOllama(messages: messages, model: model, maxTokens: maxTokens, temperature: temperature)
    }
  }

  // MARK: - OpenAI-compatible provider

  private func callOpenAICompatible(
    messages: [Message],
    model: String,
    maxTokens: Int,
    temperature: Double
  ) async throws -> String {
    var headers = HTTPHeaders()
    headers.add(name: "Content-Type", value: "application/json")
    if let apiKey = apiKey {
      headers.add(name: "Authorization", value: "Bearer \(apiKey)")
    }

    let payload: [String: Any] = [
      "model": model,
      "messages": messages.map { ["role": $0.role, "content": $0.content] },
      "max_tokens": maxTokens,
      "temperature": temperature,
    ]

    app.logger.debug("Calling \(provider) (OpenAI-compatible) at \(endpoint)")

    // Convert payload to JSON data
    let jsonData = try JSONSerialization.data(withJSONObject: payload)

    // Use Vapor's client so we can encode content in the request closure and set headers
    let response = try await app.client.post(URI(string: endpoint)) { req in
      req.headers = headers
      req.body = ByteBuffer(data: jsonData)
    }

    guard response.status == HTTPResponseStatus.ok
    else {
      let errorDetail: String
      if let body = response.body, let data = body.getData(at: body.readerIndex, length: body.readableBytes) {
        errorDetail = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
      } else {
        errorDetail = "<no body>"
      }
      throw Abort(.internalServerError, reason: "\(provider) returned \(response.status.code): \(errorDetail)")
    }

    guard let body = response.body,
          let data = body.getData(at: body.readerIndex, length: body.readableBytes),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw Abort(.internalServerError, reason: "Invalid JSON response from \(provider)")
    }

    // Extract content from OpenAI-compatible response
    if let choices = json["choices"] as? [[String: Any]], let firstChoice = choices.first {
      if let message = firstChoice["message"] as? [String: Any], let content = message["content"] as? String {
        return content
      } else if let text = firstChoice["text"] as? String {
        return text
      }
    }

    throw Abort(.internalServerError, reason: "Unexpected response format from \(provider)")
  }

  // MARK: - Ollama provider

  private func callOllama(
    messages: [Message],
    model: String,
    maxTokens: Int,
    temperature: Double
  ) async throws -> String {
    var headers = HTTPHeaders()
    headers.add(name: "Content-Type", value: "application/json")
    if let apiKey = apiKey {
      headers.add(name: "Authorization", value: "Bearer \(apiKey)")
    }
    app.logger.debug("!! DEBUG: Ollama messages count: \(messages.count)")

    let prompt = messagesToPrompt(messages: messages)
    app.logger.debug("DEBUG: Ollama prompt: \(prompt)")
    let payload: [String: Any] = [
      "model": model,
      "prompt": prompt,
      "max_tokens": maxTokens,
      "temperature": temperature,
      "stream": false,
    ]

    app.logger.debug("Calling Ollama at \(endpoint) with model \(model)")

    // Convert payload to JSON data
    let jsonData = try JSONSerialization.data(withJSONObject: payload)

    let response = try await app.client.post(URI(string: endpoint)) { req in
      req.headers = headers
      req.body = ByteBuffer(data: jsonData)
    }

    guard response.status == HTTPResponseStatus.ok
    else {
      let errorDetail: String
      if let body = response.body, let data = body.getData(at: body.readerIndex, length: body.readableBytes) {
        errorDetail = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
      } else {
        errorDetail = "<no body>"
      }
      throw Abort(.internalServerError, reason: "Ollama returned \(response.status.code): \(errorDetail)")
    }

    return try parseOllamaResponse(response: response)
  }

  private func parseOllamaResponse(response: ClientResponse) throws -> String {
    guard let body = response.body,
          let data = body.getData(at: body.readerIndex, length: body.readableBytes),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw Abort(.internalServerError, reason: "Invalid JSON response from Ollama")
    }

    // Try different response field names
    if let response = json["response"] as? String { return response }
    if let text = json["text"] as? String { return text }
    if let result = json["result"] as? String { return result }

    // Handle choices format
    if let choices = json["choices"] as? [[String: Any]], let firstChoice = choices.first {
      if let message = firstChoice["message"] as? [String: Any], let content = message["content"] as? String {
        return content
      }
      if let content = firstChoice["content"] as? String { return content }
      if let text = firstChoice["text"] as? String { return text }
    }

    return "\(json)"
  }

  private func messagesToPrompt(messages: [Message]) -> String {
    return messages.map { "[\($0.role.uppercased())] \($0.content)" }.joined(separator: "\n\n")
  }
}
