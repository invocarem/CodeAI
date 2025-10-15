import Vapor

func routes(_ app: Application) throws
{
  let aiClient = AIClient(app)

  // Health check
  app.get("health")
  { _ -> HealthResponse in
    return HealthResponse(
      ok: true,
      provider: Config.aiProvider,
      configured: aiClient.isAvailable(),
      model: Config.defaultModel
    )
  }

  // List models
  app.get("v1", "models")
  { _ -> ModelsResponse in
    var models = [
      ModelsResponse.Model(id: "mistral-small-latest"),
      ModelsResponse.Model(id: "mistral-medium-latest"),
      ModelsResponse.Model(id: "mistral-large-latest"),
      ModelsResponse.Model(id: "gpt-4o"),
      ModelsResponse.Model(id: "gpt-4o-mini")
    ]

    if Config.aiProvider == "ollama"
    {
      models.append(contentsOf: [
        ModelsResponse.Model(id: "mistral:latest"),
        ModelsResponse.Model(id: "deepseek-coder:6.7b")
      ])
    }

    return ModelsResponse(data: models)
  }

  // Chat completions
  app.post("v1", "chat", "completions")
  { req -> Response in
    let body = try req.content.decode(ChatCompletionRequest.self)

    let model = body.model ?? Config.defaultModel
    let messages = body.messages
    let maxTokens = body.maxTokens ?? Config.defaultMaxTokens
    let temperature = body.temperature ?? Config.defaultTemperature
    let stream = body.stream ?? false

    // Check for VS Code Continue commands
    if let lastUser = messages.last(where: { $0.role == "user" })?.content
    {
      let lower = lastUser.lowercased()

      if lower.contains("@renumber-verses") || lower.contains("renumber-verses")
      {
        var code = SwiftArrayFormatter.extractSwiftCode(from: lastUser)
        if code == nil
        {
          let allUser = messages
            .filter { $0.role == "user" }
            .map { $0.content }
            .joined(separator: "\n")
          code = SwiftArrayFormatter.extractSwiftCode(from: allUser)
        }

        if let code = code
        {
          let cmd = SwiftArrayCommand(
            code: code,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature
          )

          let response = try await renumberVersesStream(cmd: cmd, aiClient: aiClient)
          let content = response.choices.first?.message.content ?? ""

          // Extract inner Swift code and wrap in markdown
          let inner = SwiftArrayFormatter.extractSwiftCode(from: content) ??
            SwiftArrayFormatter.extractCodeFromResponse(content)
          let formattedResponse = "```swift\n\(inner)\n```"

          if stream
          {
            let chunks = ResponseBuilder.createStreamingResponse(content: formattedResponse, model: model)
            var responseBuffer = ""
            chunks.forEach { responseBuffer += $0 }
            return Response(status: .ok, body: .init(string: responseBuffer))
          }
          else
          {
            return try Response(
              status: .ok,
              body: .init(data: JSONEncoder().encode(
                ResponseBuilder.buildChatCompletion(content: formattedResponse, model: model)
              ))
            )
          }
        }
      }

      if lower.contains("@clean-verses") || lower.contains("clean-verses")
      {
        var code = SwiftArrayFormatter.extractSwiftCode(from: lastUser)
        if code == nil
        {
          let allUser = messages
            .filter { $0.role == "user" }
            .map { $0.content }
            .joined(separator: "\n")
          code = SwiftArrayFormatter.extractSwiftCode(from: allUser)
        }

        if let code = code
        {
          let cmd = SwiftArrayCommand(
            code: code,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature
          )

          let response = try await cleanVersesStream(cmd: cmd, aiClient: aiClient)
          let content = response.choices.first?.message.content ?? ""

          let inner = SwiftArrayFormatter.extractSwiftCode(from: content) ??
            SwiftArrayFormatter.extractCodeFromResponse(content)
          let formattedResponse = "```swift\n\(inner)\n```"

          if stream
          {
            let chunks = ResponseBuilder.createStreamingResponse(content: formattedResponse, model: model)
            var responseBuffer = ""
            chunks.forEach { responseBuffer += $0 }
            return Response(status: .ok, body: .init(string: responseBuffer))
          }
          else
          {
            return try Response(
              status: .ok,
              body: .init(data: JSONEncoder().encode(
                ResponseBuilder.buildChatCompletion(content: formattedResponse, model: model)
              ))
            )
          }
        }
      }
    }

    // Regular AI processing
    let replyText: String
    if aiClient.isAvailable()
    {
      replyText = try await aiClient.chatCompletion(
        messages: messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature
      )
    }
    else
    {
      replyText = LocalFallbackFormatter.simpleReply(messages: messages)
    }

    if stream
    {
      let chunks = ResponseBuilder.createStreamingResponse(content: replyText, model: model)
      var responseBuffer = ""
      chunks.forEach { responseBuffer += $0 }
      return Response(status: .ok, body: .init(string: responseBuffer))
    }
    else
    {
      return try Response(
        status: .ok,
        body: .init(data: JSONEncoder().encode(
          ResponseBuilder.buildChatCompletion(content: replyText, model: model)
        ))
      )
    }
  }

  // Renumber verses endpoint
  app.post("renumber-verses")
  { req -> [String: String] in
    let cmd = try req.content.decode(SwiftArrayCommand.self)

    do
    {
      let response = try await renumberVersesStream(cmd: cmd, aiClient: aiClient)
      return ["formatted_code": response.choices[0].message.content]
    }
    catch
    {
      // Fall back to local implementation
      guard let code = SwiftArrayFormatter.extractSwiftCode(from: cmd.code)
      else
      {
        throw Abort(.badRequest, reason: "Could not extract Swift code from input")
      }

      guard let formatted = SwiftArrayFormatter.formatLocal(code)
      else
      {
        throw Abort(.internalServerError, reason: "Formatting failed")
      }

      return ["formatted_code": formatted]
    }
  }

  // Clean verses endpoint
  app.post("clean-verses")
  { req -> [String: String] in
    let cmd = try req.content.decode(SwiftArrayCommand.self)

    do
    {
      let response = try await cleanVersesStream(cmd: cmd, aiClient: aiClient)
      return ["cleaned_code": response.choices[0].message.content]
    }
    catch
    {
      // Fall back to local implementation
      guard let cleaned = SwiftArrayFormatter.cleanCommentsLocal(cmd.code)
      else
      {
        throw Abort(.internalServerError, reason: "Comment cleaning failed")
      }

      return ["cleaned_code": cleaned]
    }
  }
}

private func renumberVersesStream(cmd: SwiftArrayCommand, aiClient: AIClient) async throws -> ChatCompletionResponse
{
  let userCode = cmd.code
  let model = cmd.model ?? Config.defaultSwiftModel
  let maxTokens = cmd.maxTokens ?? Config.defaultSwiftMaxTokens
  let temperature = cmd.temperature ?? Config.defaultTemperature

  let messages = [
    Message(role: "system", content: SwiftArrayFormatter.renumberSystemPrompt),
    Message(role: "user", content: "```swift\n\(userCode)\n```")
  ]

  var replyText: String?

  if aiClient.isAvailable()
  {
    print("[DEBUG] Sending to \(Config.aiProvider) with model: \(model)")

    do
    {
      let aiReply = try await aiClient.chatCompletion(
        messages: messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature
      )

      print("[DEBUG] Raw AI reply (first 500 chars): \(String(aiReply.prefix(500)))")
      print("[DEBUG] Raw AI reply (last 500 chars): \(String(aiReply.suffix(500)))")

      replyText = SwiftArrayFormatter.extractCodeFromResponse(aiReply)
      print("[DEBUG] Cleaned response (first 500 chars): \(String(replyText?.prefix(500) ?? ""))")
    }
    catch
    {
      print("[DEBUG] Error calling AI provider: \(error)")
      print("[DEBUG] Falling back to local deterministic formatter")
    }
  }

  // Use local formatter if AI not available or failed
  if replyText == nil
  {
    print("[DEBUG] Using local deterministic formatter")
    guard let codeSnippet = SwiftArrayFormatter.extractSwiftCode(from: userCode)
    else
    {
      throw Abort(.badRequest, reason: "Could not extract Swift code from input")
    }

    guard let formatted = SwiftArrayFormatter.formatLocal(codeSnippet)
    else
    {
      throw Abort(.internalServerError, reason: "Formatting failed")
    }

    replyText = formatted
  }

  return ResponseBuilder.buildChatCompletion(content: replyText ?? "", model: model)
}

private func cleanVersesStream(cmd: SwiftArrayCommand, aiClient: AIClient) async throws -> ChatCompletionResponse
{
  let userCode = cmd.code
  let model = cmd.model ?? Config.defaultSwiftModel
  let maxTokens = cmd.maxTokens ?? Config.defaultSwiftMaxTokens
  let temperature = cmd.temperature ?? Config.defaultTemperature

  var replyText: String?

  if aiClient.isAvailable()
  {
    let messages = [
      Message(role: "system", content: SwiftArrayFormatter.cleanSystemPrompt),
      Message(role: "user", content: "```swift\n\(userCode)\n```")
    ]

    print("[DEBUG] Cleaning verses with \(Config.aiProvider) model: \(model)")

    do
    {
      let aiReply = try await aiClient.chatCompletion(
        messages: messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature
      )

      print("[DEBUG] Raw AI reply for cleaning (first 500 chars): \(String(aiReply.prefix(500)))")
      replyText = SwiftArrayFormatter.extractCodeFromResponse(aiReply)
      print("[DEBUG] Cleaned response (first 500 chars): \(String(replyText?.prefix(500) ?? ""))")
    }
    catch
    {
      print("[DEBUG] Error calling AI provider for cleaning: \(error)")
      // Fall back to local implementation
      if let cleaned = SwiftArrayFormatter.cleanCommentsLocal(userCode)
      {
        replyText = cleaned
      }
      else
      {
        throw Abort(.internalServerError, reason: "Comment cleaning failed")
      }
    }
  }
  else
  {
    // Use local implementation
    print("[DEBUG] Using local comment cleaner")
    if let cleaned = SwiftArrayFormatter.cleanCommentsLocal(userCode)
    {
      replyText = cleaned
    }
    else
    {
      throw Abort(.internalServerError, reason: "Comment cleaning failed")
    }
  }

  return ResponseBuilder.buildChatCompletion(content: replyText ?? "", model: model)
}
