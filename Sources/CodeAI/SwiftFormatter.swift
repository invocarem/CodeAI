import Foundation

class SwiftArrayFormatter
{
  static let renumberSystemPrompt = """
  You are an expert Swift code formatter.
  Your task is to count **exactly how many strings** appear in the given Swift array and renumber them sequentially, and provide updated array
  ### RULES
  1. Do not generate or wrap the result in a Swift function.
  2. Do not merge or split any string in the array.
  3. Ignore any existing /* number */ comment -- they may be incorrect.
  4. Ignore period `.`, semicolons `;` or punctuation inside strings.
  5. Ignore blank lines -- they do not count as items
  6. Count one string for each element ending with a double quote (") followed by a comma (,).
  7. Count one string for the final element that ends with a double quote ("), no comma.
  8. Every string in the output must begin with a renumbered /* number */ as 
  ```
  /* N */ "string text",
  9. Preserve original indentation, spacing, and commas.
  10. No explanations, notes, but markdown code block only.

  ### EXAMPLE
  ** INPUT **
  private let text = [  
      /* 1 */ "string a",   
      "string b",  
      /* 2 */ "string c"
  ]
  ** Expected OUTPUT **
  ```swift
  private let text = [  
     /* 1 */ "string a",  
     /* 2 */ "string b",  
     /* 3 */ "string c"
  ]
  ### Now, process this input
  """

  static let cleanSystemPrompt = """
  You are an expert Swift code formatter.
  Your task is to remove all /* number */ comments from the given Swift array while preserving the array structure and string content.

  RULES:
  1. Remove ALL /* number */ comments (e.g., /* 1 */, /* 2 */, etc.)
  2. Preserve all string content exactly as is
  3. Preserve all indentation, spacing, and commas
  4. Do not modify the strings themselves
  5. Do not add or remove any array elements
  6. Return ONLY the cleaned Swift code in a markdown code block
  7. No explanations or additional text
  """

  static func extractSwiftCode(from text: String) -> String?
  {
    // Try markdown swift block
    if let match = text.range(of: "```swift\n([\\s\\S]*?)\n```", options: .regularExpression)
    {
      let content = String(text[match])
        .replacingOccurrences(of: "```swift\n", with: "")
        .replacingOccurrences(of: "\n```", with: "")
      return content
    }

    // Try generic code block
    if let match = text.range(of: "```\n([\\s\\S]*?)\n```", options: .regularExpression)
    {
      let content = String(text[match])
        .replacingOccurrences(of: "```\n", with: "")
        .replacingOccurrences(of: "\n```", with: "")
      return content
    }

    // Try to find array pattern
    if let match = text.range(of: "private\\s+let[\\s\\S]*?\\]", options: .regularExpression)
    {
      return String(text[match])
    }

    return nil
  }

  static func extractArrayParts(from code: String) -> (header: String, body: String, footer: String)?
  {
    // Try structured match
    if let match = code.range(of: "(private\\s+let\\s+\\w+\\s*=\\s*\\[)([\\s\\S]*?)(\\n\\])", options: .regularExpression)
    {
      let header = String(code[code.index(match.lowerBound, offsetBy: 0) ..< code.index(match.lowerBound, offsetBy: match.upperBound.utf16Offset(in: code) - match.lowerBound.utf16Offset(in: code))])
      let body = String(code[code.index(match.lowerBound, offsetBy: header.count) ..< match.upperBound])
      let footer = "]\n"
      return (header, String(body.dropLast(2)), footer)
    }

    // Fallback: find brackets
    guard let start = code.firstIndex(of: "["),
          let end = code.lastIndex(of: "]"),
          end > start
    else
    {
      return nil
    }

    let header = String(code[..<code.index(after: start)])
    let body = String(code[code.index(after: start) ..< end])
    let footer = String(code[end...])

    return (header, body, footer)
  }

  static func formatLocal(_ code: String) -> String?
  {
    guard let parts = extractArrayParts(from: code)
    else
    {
      return nil
    }

    let lines = parts.body.components(separatedBy: .newlines)
    var candidates: [(Int, String)] = []

    for (i, line) in lines.enumerated()
    {
      guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

      let stripped = line.trimmingCharacters(in: .whitespaces)
      if stripped.hasSuffix("\",") || stripped.hasSuffix("\"")
      {
        candidates.append((i, line))
      }
    }

    guard !candidates.isEmpty else { return nil }

    var newLines = lines
    for (index, (lineIndex, originalLine)) in candidates.enumerated()
    {
      let number = index + 1
      let leadingWhitespace = String(originalLine.prefix { $0.isWhitespace })
      var rest = String(originalLine.dropFirst(leadingWhitespace.count))

      // Remove existing comment if present
      if let commentRange = rest.range(of: #"/\*[^\*]*\*/\s*"#, options: .regularExpression)
      {
        rest = String(rest[commentRange.upperBound...])
      }

      let newLine = "\(leadingWhitespace)/* \(number) */ \(rest)"
      newLines[lineIndex] = newLine
    }

    let newBody = newLines.joined(separator: "\n")
    return "```swift\n\(parts.header)\n\(newBody)\n\(parts.footer)```"
  }

  static func cleanCommentsLocal(_ code: String) -> String?
  {
    guard let parts = extractArrayParts(from: code)
    else
    {
      return nil
    }

    let lines = parts.body.components(separatedBy: .newlines)
    let cleanedLines = lines.map
    { line in
      line.replacingOccurrences(of: #"/\*\s*\d+\s*\*/\s*"#, with: "", options: .regularExpression)
    }

    let cleanedBody = cleanedLines.joined(separator: "\n")
    return "```swift\n\(parts.header)\n\(cleanedBody)\n\(parts.footer)```"
  }

  static func extractCodeFromResponse(_ responseText: String) -> String
  {
    // Try to find markdown swift block first
    if let swiftMatch = responseText.range(of: "```swift\n(.*?)\n```", options: .regularExpression)
    {
      let content = String(responseText[swiftMatch])
      return "```swift\n\(content.replacingOccurrences(of: "```swift\n", with: "").replacingOccurrences(of: "\n```", with: ""))\n```"
    }

    // Try generic code block
    if let codeMatch = responseText.range(of: "```\n(.*?)\n```", options: .regularExpression)
    {
      let content = String(responseText[codeMatch])
      return "```swift\n\(content.replacingOccurrences(of: "```\n", with: "").replacingOccurrences(of: "\n```", with: ""))\n```"
    }

    // If no code blocks, look for array pattern
    if let arrayMatch = responseText.range(of: "private\\s+let\\s+\\w+\\s*=\\s*\\[[\\s\\S]*?\\]", options: .regularExpression)
    {
      return "```swift\n\(String(responseText[arrayMatch]))\n```"
    }

    // Return original if nothing else works
    return responseText
  }
}

class LocalFallbackFormatter
{
  static func simpleReply(messages: [Message]) -> String
  {
    let lastUser = messages.last { $0.role == "user" }?.content

    guard let lastUser = lastUser
    else
    {
      return "Hello — provide a prompt or some code and I'll respond."
    }

    if lastUser.lowercased().contains("remove blank")
    {
      let cleaned = lastUser.components(separatedBy: .newlines)
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        .joined(separator: "\n")
      return cleaned
    }

    return "Assistant (local fallback):\n\n\(lastUser)"
  }
}
