import Foundation
import Combine

class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let session: URLSession
    private let baseURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: AppConfiguration.shared.apiBaseURL)!
    }
    
    // MARK: - Generic Request Method
    func request<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        let request = try buildRequest(for: endpoint)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Streaming Request
    func streamingRequest(
        endpoint: APIEndpoint
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(for: endpoint)
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw APIError.invalidResponse
                    }
                    
                    for try await byte in asyncBytes {
                        let data = Data([byte])
                        continuation.yield(data)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - AI API Methods
    func generateSummary(request: AISummaryRequest) async throws -> AISummaryResponse {
        let endpoint = APIEndpoint.aiSummary(request)
        return try await self.request(endpoint: endpoint, responseType: AISummaryResponse.self)
    }
    
    func answerQuestion(request: AIQuestionRequest) -> AsyncThrowingStream<AIResponseChunk, Error> {
        let endpoint = APIEndpoint.aiQuestion(request)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let streamRequest = try buildRequest(for: endpoint)
                    let (asyncBytes, response) = try await session.bytes(for: streamRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw APIError.invalidResponse
                    }
                    
                    var buffer = Data()
                    
                    for try await byte in asyncBytes {
                        buffer.append(byte)
                        
                        // 处理服务器发送事件(SSE)格式
                        if let string = String(data: buffer, encoding: .utf8),
                           string.contains("\n\n") {
                            let lines = string.components(separatedBy: "\n\n")
                            
                            for line in lines.dropLast() {
                                if let chunk = parseSSELine(line) {
                                    continuation.yield(chunk)
                                }
                            }
                            
                            // 保留最后一个不完整的行
                            if let lastLine = lines.last {
                                buffer = lastLine.data(using: .utf8) ?? Data()
                            } else {
                                buffer = Data()
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Recommendation API
    func getRecommendations(type: String, limit: Int, offset: Int) async throws -> RecommendationResponse {
        let endpoint = APIEndpoint.recommendations(type: type, limit: limit, offset: offset)
        return try await request(endpoint: endpoint, responseType: RecommendationResponse.self)
    }
    
    // MARK: - Helper Methods
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        
        request.httpMethod = endpoint.method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        // 添加查询参数
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            request.url = components?.url ?? url
        }
        
        // 添加请求体
        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    private func getAuthToken() -> String {
        // 这里应该实现JWT token获取逻辑
        // 基于iCloud用户标识符生成token
        return "demo_token"
    }
    
    private func parseSSELine(_ line: String) -> AIResponseChunk? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.hasPrefix("data: ") {
            let jsonString = String(trimmedLine.dropFirst(6))
            
            if let data = jsonString.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(AIResponseChunk.self, from: data) {
                return chunk
            }
        }
        
        return nil
    }
}

// MARK: - API Endpoints
enum APIEndpoint {
    case aiSummary(AISummaryRequest)
    case aiQuestion(AIQuestionRequest)
    case recommendations(type: String, limit: Int, offset: Int)
    case syncProgress(ReadingProgressSync)
    
    var path: String {
        switch self {
        case .aiSummary:
            return "/api/v1/ai/summary"
        case .aiQuestion:
            return "/api/v1/ai/qa"
        case .recommendations:
            return "/api/v1/recommendations/feed"
        case .syncProgress:
            return "/api/v1/sync/progress"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .aiSummary, .aiQuestion, .syncProgress:
            return .POST
        case .recommendations:
            return .GET
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .recommendations(let type, let limit, let offset):
            return [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        default:
            return nil
        }
    }
    
    var body: [String: Any]? {
        switch self {
        case .aiSummary(let request):
            return try? request.toDictionary()
        case .aiQuestion(let request):
            return try? request.toDictionary()
        case .syncProgress(let request):
            return try? request.toDictionary()
        default:
            return nil
        }
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Error Types
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .authenticationFailed:
            return "认证失败"
        }
    }
}

// MARK: - Request Models
struct AISummaryRequest: Codable {
    let type: String // "book" or "chapter"
    let bookId: String
    let chapterId: String?
    let content: String
    let metadata: BookMetadataRequest
    
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

struct BookMetadataRequest: Codable {
    let title: String
    let authors: [String]
    let language: String
}

struct AIQuestionRequest: Codable {
    let question: String
    let context: AIContextRequest
    let mode: String
    
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

struct AIContextRequest: Codable {
    let selection: String?
    let paragraphs: [String]
    let chapter: ChapterMetadataRequest
    let book: BookMetadataRequest
}

struct ChapterMetadataRequest: Codable {
    let title: String
    let number: Int
    let position: String
}

struct ReadingProgressSync: Codable {
    let bookId: String
    let chapterId: String
    let position: Double
    let readingTime: Int
    let timestamp: String
    
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Response Models
struct AISummaryResponse: Codable {
    let id: String
    let summary: String
    let keyPoints: [String]
    let keywords: [String]
    let estimatedReadingTime: Int
    let cached: Bool
}

struct AIResponseChunk: Codable {
    let type: String
    let id: String?
    let delta: String?
    let reference: AIReference?
    let usage: TokenUsage?
}

struct AIReference: Codable {
    let text: String
    let chapterTitle: String
    let position: String
    let confidence: Double
}

struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

struct RecommendationResponse: Codable {
    let recommendations: [BookRecommendationAPI]
    let hasMore: Bool
}

struct BookRecommendationAPI: Codable {
    let id: String
    let title: String
    let description: String
    let books: [BookRecommendationItem]
    let reason: String
}

struct BookRecommendationItem: Codable {
    let id: String
    let title: String
    let authors: [String]
    let description: String
    let coverUrl: String?
    let estimatedReadingTime: Int
    let difficulty: String
    let tags: [String]
}

