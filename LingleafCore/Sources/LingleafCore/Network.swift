import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HttpResponse: Sendable {
    public let status: Int
    public let body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }

    public init(status: Int, text: String) {
        self.init(status: status, body: Data(text.utf8))
    }

    public var text: String { String(decoding: body, as: UTF8.self) }
}

/// Minimal HTTP abstraction so network code stays testable without a server.
public protocol HttpFetcher: Sendable {
    func get(_ url: String) async throws -> HttpResponse
}

public struct NetworkError: Error, Equatable {
    public let message: String

    public init(_ message: String) { self.message = message }
}

/// Wraps a closure; handy for tests and previews.
public struct ClosureFetcher: HttpFetcher {
    private let handler: @Sendable (String) async throws -> HttpResponse

    public init(_ handler: @escaping @Sendable (String) async throws -> HttpResponse) {
        self.handler = handler
    }

    public func get(_ url: String) async throws -> HttpResponse { try await handler(url) }
}

/// HTTPS-only fetcher. Plain HTTP is refused before any connection is made.
public struct URLSessionFetcher: HttpFetcher {
    public init() {}

    public func get(_ url: String) async throws -> HttpResponse {
        guard url.hasPrefix("https://"), let address = URL(string: url) else { throw NetworkError("Only HTTPS is allowed") }
        var request = URLRequest(url: address, timeoutInterval: 30)
        request.setValue("Lingleaf/0.1 (+https://github.com/erobinsonc/lingleaf-ios)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        return HttpResponse(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
    }
}
