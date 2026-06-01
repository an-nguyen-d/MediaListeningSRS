import Foundation
import MSRS_Shared

enum OllamaGradingHelper {

  struct GradeResult: Sendable {
    let score: Int
    let reasoning: String
  }

  enum GradingError: Error, LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Could not parse LLM response as JSON"
      case .serverError(let msg): return msg
      }
    }
  }

  static func grade(
    japaneseTranscript: String,
    englishTranslation: String?,
    learnerResponse: String
  ) async throws -> GradeResult {
    let systemPrompt = MSRSAppSettings.llmGradingPrompt

    var userContent = "Japanese transcript: \(japaneseTranscript)"
    if let translation = englishTranslation {
      userContent += "\nEnglish translation: \(translation)"
    }
    userContent += "\nLearner's response: \(learnerResponse)"

    let requestBody: [String: Any] = [
      "model": "qwen3.6:35b-a3b",
      "messages": [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": userContent],
      ],
      "think": false,
      "stream": false,
    ]

    let url = URL(string: "http://localhost:11434/api/chat")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    request.timeoutInterval = 120

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
      let body = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw GradingError.serverError("Ollama returned \(httpResponse.statusCode): \(body)")
    }

    struct OllamaResponse: Decodable {
      struct Message: Decodable { let content: String }
      let message: Message
    }

    let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)

    var content = ollamaResponse.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    if content.hasPrefix("```json") {
      content = String(content.dropFirst(7))
    } else if content.hasPrefix("```") {
      content = String(content.dropFirst(3))
    }
    if content.hasSuffix("```") {
      content = String(content.dropLast(3))
    }
    content = content.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let jsonData = content.data(using: .utf8) else {
      throw GradingError.invalidResponse
    }

    struct GradeJSON: Decodable {
      let score: Int
      let reasoning: String
    }

    let grade = try JSONDecoder().decode(GradeJSON.self, from: jsonData)
    return GradeResult(score: grade.score, reasoning: grade.reasoning)
  }
}
