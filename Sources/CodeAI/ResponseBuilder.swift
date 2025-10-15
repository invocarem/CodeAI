import Foundation
import Vapor

class ResponseBuilder
{
  static func buildChatCompletion(
    content: String,
    model: String
  ) -> ChatCompletionResponse
  {
    let tokenCount = content.split(separator: " ").count

    return ChatCompletionResponse(
      id: "chatcmpl-\(UUID().uuidString)",
      object: "chat.completion",
      created: Int(Date().timeIntervalSince1970),
      model: model,
      choices: [
        ChatCompletionResponse.Choice(
          index: 0,
          message: Message(role: "assistant", content: content),
          finishReason: "stop"
        )
      ],
      usage: ChatCompletionResponse.Usage(
        promptTokens: 0,
        completionTokens: tokenCount,
        totalTokens: tokenCount
      )
    )
  }

  static func createStreamingResponse(content: String, model: String) -> [String]
  {
    let chunkId = "chatcmpl-\(UUID().uuidString)"
    let createdTs = Int(Date().timeIntervalSince1970)

    var chunks: [String] = []

    // Helper function to encode chunks
    func encodeChunk(_ chunk: StreamingChunk) -> String?
    {
      let encoder = JSONEncoder()
      if let data = try? encoder.encode(chunk),
         let jsonString = String(data: data, encoding: .utf8)
      {
        return "data: \(jsonString)\n\n"
      }
      return nil
    }

    // First chunk with role
    let firstChunk = StreamingChunk(
      id: chunkId,
      object: "chat.completion.chunk",
      created: createdTs,
      model: model,
      choices: [
        StreamingChunk.Choice(
          index: 0,
          delta: StreamingChunk.Delta(role: "assistant", content: ""),
          finishReason: nil
        )
      ]
    )

    if let chunkString = encodeChunk(firstChunk)
    {
      chunks.append(chunkString)
    }

    // Content chunk
    let contentChunk = StreamingChunk(
      id: chunkId,
      object: "chat.completion.chunk",
      created: createdTs,
      model: model,
      choices: [
        StreamingChunk.Choice(
          index: 0,
          delta: StreamingChunk.Delta(role: nil, content: content),
          finishReason: nil
        )
      ]
    )

    if let chunkString = encodeChunk(contentChunk)
    {
      chunks.append(chunkString)
    }

    // Final chunk with finish_reason
    let finalChunk = StreamingChunk(
      id: chunkId,
      object: "chat.completion.chunk",
      created: createdTs,
      model: model,
      choices: [
        StreamingChunk.Choice(
          index: 0,
          delta: StreamingChunk.Delta(role: nil, content: nil),
          finishReason: "stop"
        )
      ]
    )

    if let chunkString = encodeChunk(finalChunk)
    {
      chunks.append(chunkString)
    }

    chunks.append("data: [DONE]\n\n")

    return chunks
  }
}
