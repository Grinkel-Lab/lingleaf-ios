import Foundation

/// A public-domain book from Project Gutenberg, as listed by the Gutendex API.
public struct GutenbergBook: Decodable, Identifiable, Hashable, Sendable {
    public struct Person: Decodable, Hashable, Sendable {
        public let name: String
    }

    public let id: Int
    public let title: String
    public let authors: [Person]
    public let formats: [String: String]

    public init(id: Int, title: String, authors: [Person] = [], formats: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.authors = authors
        self.formats = formats
    }

    enum CodingKeys: String, CodingKey { case id, title, authors, formats }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        authors = try c.decodeIfPresent([Person].self, forKey: .authors) ?? []
        formats = try c.decodeIfPresent([String: String].self, forKey: .formats) ?? [:]
    }

    /// "Carroll, Lewis" → "Lewis Carroll"
    public var authorName: String? {
        guard let name = authors.first?.name else { return nil }
        let parts = name.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.count == 2 ? "\(parts[1]) \(parts[0])" : name
    }

    public var coverURL: URL? { formats["image/jpeg"].flatMap(URL.init(string:)) }

    public var textURL: String? {
        let candidates = formats
            .filter { $0.key.hasPrefix("text/plain") && !$0.value.hasSuffix(".zip") }
            .sorted { $0.key < $1.key }
        return (candidates.first { $0.key.contains("utf-8") } ?? candidates.first)?.value
    }
}

private struct GutendexResponse: Decodable {
    let results: [GutenbergBook]
}

public struct GutenbergClient: Sendable {
    private let http: HttpFetcher
    private static let base = "https://gutendex.com/books"

    /// Hand-picked classics with a CEFR level hint, easiest first.
    public static let recommended: [(id: Int, level: String)] = [
        (21, "A2"), // Aesop's Fables
        (55, "B1"), // The Wonderful Wizard of Oz
        (16, "B1"), // Peter Pan
        (236, "B1"), // The Jungle Book
        (11, "B2"), // Alice's Adventures in Wonderland
        (74, "B2"), // The Adventures of Tom Sawyer
        (120, "B2"), // Treasure Island
        (1661, "B2"), // The Adventures of Sherlock Holmes
        (1342, "C1"), // Pride and Prejudice
        (84, "C1"), // Frankenstein
        (174, "C1"), // The Picture of Dorian Gray
        (1400, "C1"), // Great Expectations
        (345, "C1"), // Dracula
        (2701, "C2"), // Moby-Dick
        (219, "C2"), // Heart of Darkness
        (145, "C2"), // Middlemarch
    ]

    /// CEFR levels, easiest first.
    public static let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]

    public init(http: HttpFetcher) { self.http = http }

    public static func level(for id: Int) -> String? { recommended.first { $0.id == id }?.level }

    /// Books at `level`, in their original order; a nil level keeps every book.
    public static func filter(_ books: [GutenbergBook], level: String?) -> [GutenbergBook] {
        guard let level else { return books }
        return books.filter { Self.level(for: $0.id) == level }
    }

    public func search(_ query: String) async throws -> [GutenbergBook] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return try await fetch("\(Self.base)?languages=en&search=\(encoded)")
    }

    public func fetchRecommended() async throws -> [GutenbergBook] {
        let ids = Self.recommended.map(\.id)
        let books = try await fetch("\(Self.base)?ids=\(ids.map(String.init).joined(separator: ","))")
        return books.sorted { (ids.firstIndex(of: $0.id) ?? .max) < (ids.firstIndex(of: $1.id) ?? .max) }
    }

    public func downloadText(_ book: GutenbergBook) async throws -> String {
        guard let url = book.textURL else { throw NetworkError("No plain-text edition") }
        let response = try await http.get(url)
        guard response.status == 200 else { throw NetworkError("HTTP \(response.status)") }
        let text = Self.stripBoilerplate(response.text)
        guard !text.isEmpty else { throw NetworkError("Empty book") }
        return text
    }

    private func fetch(_ url: String) async throws -> [GutenbergBook] {
        let response = try await http.get(url)
        guard response.status == 200 else { throw NetworkError("HTTP \(response.status)") }
        return try JSONDecoder().decode(GutendexResponse.self, from: response.body).results
    }

    /// Removes the Project Gutenberg license header and footer.
    public static func stripBoilerplate(_ text: String) -> String {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        func isMarker(_ line: String, _ kind: String) -> Bool {
            line.hasPrefix("*** \(kind) OF") || line.hasPrefix("***\(kind) OF")
        }
        if let start = lines.firstIndex(where: { isMarker($0, "START") }) { lines.removeSubrange(...start) }
        if let end = lines.firstIndex(where: { isMarker($0, "END") }) { lines.removeSubrange(end...) }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
