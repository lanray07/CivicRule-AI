import Foundation

enum CivicError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct RegulatoryAnswerService {
    func askRegulationQuestion(_ request: QuestionRequest) async throws -> RegulatoryAnswer {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CivicAPIBaseURL") as? String,
              let base = URL(string: raw), base.scheme == "https" else {
            throw CivicError.message("Live answers are not connected yet. You can still organise your business, permits and documents locally. Configure the verified source service to enable questions.")
        }
        var urlRequest = URLRequest(url: base.appendingPathComponent("v1/answers"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try KeychainService.read("apiToken") { urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw CivicError.message("The source service could not complete this check. Please try again later.") }
        let answer = try JSONDecoder().decode(RegulatoryAnswer.self, from: data)
        guard answer.status != "answered" || !answer.sources.isEmpty else { throw CivicError.message("The response did not include evidence. No answer has been shown.") }
        return answer
    }
}

