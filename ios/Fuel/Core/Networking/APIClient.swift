import Foundation

// Actor wrapping URLSession for the Fuel Express API. Unwraps the `{ data: T }`
// envelope, attaches a fresh Supabase bearer token when a route needs auth, and
// maps failures to APIError. Request timeout is generous (75s) for Render
// free-tier cold starts.
actor APIClient {
  static let shared = APIClient()

  private let baseURL: URL
  private let session: URLSession
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder
  private let tokenProvider: () async throws -> String

  init(
    baseURL: URL = AppConfig.apiBaseURL,
    tokenProvider: @escaping () async throws -> String = { try await SupabaseService.shared.accessToken() }
  ) {
    self.baseURL = baseURL
    self.tokenProvider = tokenProvider

    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 75
    config.timeoutIntervalForResource = 75
    config.waitsForConnectivity = false
    self.session = URLSession(configuration: config)

    self.decoder = JSONDecoder.fuel()
    self.encoder = JSONEncoder()
  }

  private struct Envelope<T: Decodable>: Decodable { let data: T }
  private struct ListEnvelope<T: Decodable>: Decodable {
    let data: [T]
    let count: Int?
  }

  // MARK: - HTTP verbs

  func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], authorized: Bool = true) async throws -> T {
    try await send(path, method: "GET", query: query, body: Optional<Empty>.none, authorized: authorized)
  }

  func post<T: Decodable, B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws -> T {
    try await send(path, method: "POST", body: body, authorized: authorized)
  }

  func put<T: Decodable, B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws -> T {
    try await send(path, method: "PUT", body: body, authorized: authorized)
  }

  func patch<T: Decodable, B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws -> T {
    try await send(path, method: "PATCH", body: body, authorized: authorized)
  }

  @discardableResult
  func delete<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
    try await send(path, method: "DELETE", body: Optional<Empty>.none, authorized: authorized)
  }

  /// Paginated list endpoints returning `{ data: [T], count: Int }`.
  func list<T: Decodable>(
    _ path: String,
    query: [URLQueryItem] = [],
    authorized: Bool = true
  ) async throws -> (items: [T], count: Int) {
    let data = try await rawData(path, method: "GET", query: query, body: Optional<Empty>.none, authorized: authorized)
    do {
      let env = try decoder.decode(ListEnvelope<T>.self, from: data)
      return (env.data, env.count ?? env.data.count)
    } catch {
      throw APIError.decoding
    }
  }

  // MARK: - Core request

  private func send<T: Decodable, B: Encodable>(
    _ path: String,
    method: String,
    query: [URLQueryItem] = [],
    body: B?,
    authorized: Bool
  ) async throws -> T {
    let data = try await rawData(path, method: method, query: query, body: body, authorized: authorized)
    do {
      return try decoder.decode(Envelope<T>.self, from: data).data
    } catch {
      throw APIError.decoding
    }
  }

  private func rawData<B: Encodable>(
    _ path: String,
    method: String,
    query: [URLQueryItem],
    body: B?,
    authorized: Bool
  ) async throws -> Data {
    var components = URLComponents(
      url: baseURL.appendingPathComponent(path.trimmingLeadingSlash),
      resolvingAgainstBaseURL: false
    )
    if !query.isEmpty { components?.queryItems = query }
    guard let url = components?.url else { throw APIError.network }

    var request = URLRequest(url: url)
    request.httpMethod = method

    if authorized {
      do {
        let token = try await tokenProvider()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      } catch {
        throw APIError.unauthorized
      }
    }

    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try encoder.encode(body)
    }

    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw APIError.network }
      guard (200..<300).contains(http.statusCode) else {
        throw APIError.from(status: http.statusCode, data: data)
      }
      return data
    } catch let error as APIError {
      throw error
    } catch let urlError as URLError {
      switch urlError.code {
      case .timedOut: throw APIError.timeout
      default: throw APIError.network
      }
    } catch {
      throw APIError.network
    }
  }

  // Placeholder empty body for request builders that have none.
  private struct Empty: Codable {}
}

private extension String {
  var trimmingLeadingSlash: String {
    hasPrefix("/") ? String(dropFirst()) : self
  }
}
