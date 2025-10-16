import Vapor

enum Config
{
  static let appTitle = "AI Server"
  static let appVersion = "1.0.0"

  // AI Provider Configuration
  static let aiProvider = Environment.get("AI_PROVIDER") ?? "openai"
  static let openAIApiKey = Environment.get("OPENAI_API_KEY")
  static let mistralApiKey = Environment.get("MISTRAL_API_KEY")

  static let ollamaBaseUrl = Environment.get("OLLAMA_BASE_URL") ?? "http://localhost:11434"

  // Server Configuration
  static let host = Environment.get("HOST") ?? "0.0.0.0"
  static let port = Int(Environment.get("PORT") ?? "8080") ?? 8080

  // Default Model Configuration
  static let defaultModel = Environment.get("DEFAULT_MODEL") ?? "gpt-4o-mini"
  static let defaultSwiftModel = Environment.get("DEFAULT_SWIFT_MODEL") ?? "gpt-4o-mini"
  static let defaultMaxTokens = Int(Environment.get("DEFAULT_MAX_TOKENS") ?? "4096") ?? 4096
  static let defaultSwiftMaxTokens = Int(Environment.get("DEFAULT_SWIFT_MAX_TOKENS") ?? "4096") ?? 4096
  static let defaultTemperature = Double(Environment.get("DEFAULT_TEMPERATURE") ?? "0.0") ?? 0.0

  // Request Configuration
  static let requestTimeout = Int(Environment.get("REQUEST_TIMEOUT") ?? "60") ?? 60

  static func getApiEndpoint() -> String
  {
    switch aiProvider
    {
    case "openai":
      return "https://api.openai.com/v1/chat/completions"
    case "mistral":
      return "https://api.mistral.ai/v1/chat/completions"
    case "ollama":
      return "\(ollamaBaseUrl)/v1/chat/completions"
    default:
      return "https://api.openai.com/v1/chat/completions"
    }
  }

  static func getApiKey() -> String?
  {
    switch aiProvider
    {
    case "openai":
      return openAIApiKey
    case "mistral":
      return mistralApiKey
    case "ollama":
      return nil // Ollama typically doesn't require API key
    default:
      return openAIApiKey
    }
  }

  static func isOpenAICompatible() -> Bool
  {
    return aiProvider != "ollama"
  }

  static func isConfigured() -> Bool
  {
    switch aiProvider
    {
    case "openai":
      return openAIApiKey != nil
    case "mistral":
      return mistralApiKey != nil
    case "ollama":
      return true // Ollama is available if endpoint is reachable
    default:
      return false
    }
  }
}
