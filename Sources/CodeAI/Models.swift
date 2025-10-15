import Vapor

struct Message: Content
{
  let role: String // "system", "user", "assistant"
  let content: String
}

struct ChatCompletionRequest: Content
{
  let model: String?
  let messages: [Message]
  let maxTokens: Int?
  let temperature: Double?
  let stream: Bool?

  enum CodingKeys: String, CodingKey
  {
    case model, messages
    case maxTokens = "max_tokens"
    case temperature, stream
  }
}

struct SwiftArrayCommand: Content
{
  let code: String
  let model: String?
  let maxTokens: Int?
  let temperature: Double?

  enum CodingKeys: String, CodingKey
  {
    case code, model
    case maxTokens = "max_tokens"
    case temperature
  }
}

struct ChatCompletionResponse: Content
{
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [Choice]
  let usage: Usage

  struct Choice: Content
  {
    let index: Int
    let message: Message
    let finishReason: String?

    enum CodingKeys: String, CodingKey
    {
      case index, message
      case finishReason = "finish_reason"
    }
  }

  struct Usage: Content
  {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey
    {
      case promptTokens = "prompt_tokens"
      case completionTokens = "completion_tokens"
      case totalTokens = "total_tokens"
    }
  }
}

struct ModelsResponse: Content
{
  let data: [Model]

  struct Model: Content
  {
    let id: String
    var object: String
    {
      return "model"
    }
  }
}

struct HealthResponse: Content
{
  let ok: Bool
  let provider: String
  let configured: Bool
  let model: String
}

struct StreamingChunk: Content
{
  let id: String
  let object: String
  let created: Int
  let model: String
  let choices: [Choice]

  struct Choice: Content
  {
    let index: Int
    let delta: Delta
    let finishReason: String?

    enum CodingKeys: String, CodingKey
    {
      case index, delta
      case finishReason = "finish_reason"
    }
  }

  struct Delta: Content
  {
    let role: String?
    let content: String?
  }
}
