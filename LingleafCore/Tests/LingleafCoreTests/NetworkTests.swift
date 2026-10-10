import XCTest
@testable import LingleafCore

private func ok(_ body: String) -> HttpResponse { HttpResponse(status: 200, text: body) }
private let notFound = HttpResponse(status: 404, text: "[]")

/// Thread-safe list of requested URLs.
private actor Recorder {
    var urls: [String] = []
    func add(_ url: String) { urls.append(url) }
}

final class GutenbergTests: XCTestCase {
    private let alice = """
    {"id": 11, "title": "Alice", "authors": [{"name": "Carroll, Lewis", "birth_year": 1832}],
     "formats": {"text/plain; charset=us-ascii": "https://example.com/11.txt",
                 "text/plain; charset=utf-8": "https://example.com/11.utf8.txt",
                 "application/zip": "https://example.com/11.zip",
                 "image/jpeg": "https://example.com/11.jpg"},
     "download_count": 5}
    """

    func testStripsLicenseHeaderAndFooter() {
        let raw = "The Project Gutenberg eBook\r\nLicense\r\n*** START OF THE PROJECT GUTENBERG EBOOK X ***\r\n\r\n"
            + "Chapter 1\r\n\r\nOnce upon a time.\r\n*** END OF THE PROJECT GUTENBERG EBOOK X ***\r\nMore license"
        XCTAssertEqual(GutenbergClient.stripBoilerplate(raw), "Chapter 1\n\nOnce upon a time.")
        XCTAssertEqual(GutenbergClient.stripBoilerplate("  Just a story.\n"), "Just a story.")
    }

    func testRecommendedBooksParseAndKeepCuratedOrder() async throws {
        let alice = alice
        let client = GutenbergClient(http: ClosureFetcher { url in
            XCTAssertTrue(url.contains("ids=21,55"))
            return ok(#"{"count": 2, "results": [\#(alice), {"id": 21, "title": "Fables"}]}"#)
        })
        let books = try await client.fetchRecommended()
        XCTAssertEqual(books.map(\.id), [21, 11])
        XCTAssertNil(books[0].authorName)
        XCTAssertEqual(books[1].authorName, "Lewis Carroll")
        XCTAssertEqual(books[1].textURL, "https://example.com/11.utf8.txt")
        XCTAssertEqual(books[1].coverURL?.absoluteString, "https://example.com/11.jpg")
        XCTAssertEqual(GutenbergClient.level(for: 11), "B2")
    }

    func testRecommendedRequestsEveryCuratedID() async throws {
        let recorder = Recorder()
        let client = GutenbergClient(http: ClosureFetcher { url in
            await recorder.add(url)
            return ok(#"{"results": []}"#)
        })
        _ = try await client.fetchRecommended()
        let urls = await recorder.urls
        let ids = GutenbergClient.recommended.map { String($0.id) }.joined(separator: ",")
        XCTAssertEqual(urls, ["https://gutendex.com/books?ids=\(ids)"])
        XCTAssertLessThanOrEqual(GutenbergClient.recommended.count, 32, "Gutendex returns 32 books per page")
    }

    func testFilterKeepsBooksAtTheChosenLevelInOrder() {
        let books = GutenbergClient.recommended.map { GutenbergBook(id: $0.id, title: "Book \($0.id)") }
        XCTAssertEqual(GutenbergClient.filter(books, level: nil), books)
        XCTAssertEqual(GutenbergClient.filter(books, level: "B1").map(\.id), [55, 16, 236])
        XCTAssertEqual(GutenbergClient.filter(books, level: "A1"), [])
        XCTAssertEqual(GutenbergClient.filter([GutenbergBook(id: 999_999, title: "Unlisted")], level: "B1"), [])
    }

    func testEveryRecommendedLevelIsAKnownLevel() {
        for book in GutenbergClient.recommended {
            XCTAssertTrue(GutenbergClient.levels.contains(book.level), "\(book.id) has unknown level \(book.level)")
        }
    }

    func testSearchEncodesTheQueryAndErrorsOnBadStatus() async throws {
        let client = GutenbergClient(http: ClosureFetcher { url in
            url.contains("search=tom%20sawyer") ? ok(#"{"results": []}"#) : HttpResponse(status: 500, text: "")
        })
        let none = try await client.search("tom sawyer")
        XCTAssertTrue(none.isEmpty)
        do {
            _ = try await client.search("other")
            XCTFail("expected an error")
        } catch {}
    }

    func testDownloadStripsBoilerplateAndRejectsEmptyBooks() async throws {
        let book = GutenbergBook(id: 1, title: "X", formats: ["text/plain": "https://example.com/1.txt"])
        let text = try await GutenbergClient(http: ClosureFetcher { _ in ok("h\n*** START OF IT ***\nCafé story.\n*** END OF IT ***") })
            .downloadText(book)
        XCTAssertEqual(text, "Café story.")
        for (client, target) in [
            (GutenbergClient(http: ClosureFetcher { _ in ok("*** START OF IT ***\n*** END OF IT ***") }), book),
            (GutenbergClient(http: ClosureFetcher { _ in notFound }), book),
            (GutenbergClient(http: ClosureFetcher { _ in notFound }), GutenbergBook(id: 2, title: "No text")),
        ] {
            do {
                _ = try await client.downloadText(target)
                XCTFail("expected an error")
            } catch {}
        }
    }
}

final class DictionaryTests: XCTestCase {
    private static func entry(_ word: String, _ definition: String, phonetic: String? = nil) -> HttpResponse {
        let phoneticField = phonetic.map { #""phonetic": "\#($0)","# } ?? ""
        return ok(#"""
        [{"word": "\#(word)", \#(phoneticField)
          "phonetics": [{"audio": ""}, {"text": "/\#(word)/"}],
          "meanings": [{"partOfSpeech": "noun", "definitions": [{"definition": "\#(definition)"}]}]}]
        """#)
    }

    func testFallsBackToBaseFormsWhenTheWordIsMissing() async {
        let recorder = Recorder()
        let client = DictionaryClient(http: ClosureFetcher { url in
            let word = String(url.split(separator: "/").last ?? "")
            await recorder.add(word)
            return word == "animal" ? Self.entry("animal", "A living creature.", phonetic: "/ˈænɪməl/") : notFound
        })
        let result = await client.lookup("Animals")
        XCTAssertEqual(result?.word, "animal")
        XCTAssertEqual(result?.phonetic, "/ˈænɪməl/")
        XCTAssertEqual(result?.partOfSpeech, "noun")
        let requested = await recorder.urls
        XCTAssertEqual(requested, ["animals", "animal"])
        _ = await client.lookup("animals")
        let afterCache = await recorder.urls
        XCTAssertEqual(afterCache.count, 2, "results and misses are cached")
    }

    func testFollowsPastTenseOfToTheBaseWord() async {
        let client = DictionaryClient(http: ClosureFetcher { url in
            switch url.split(separator: "/").last.map(String.init) ?? "" {
            case "walked": return Self.entry("walked", "simple past tense and past participle of walk")
            case "walk": return Self.entry("walk", "To move on the feet.")
            default: return notFound
            }
        })
        let result = await client.lookup("walked")
        XCTAssertEqual(result?.word, "walk")
        XCTAssertEqual(result?.phonetic, "/walk/")
    }

    func testReturnsNilWhenOfflineOnServerErrorsOrBadJSON() async {
        let offline = await DictionaryClient(http: ClosureFetcher { _ in throw NetworkError("offline") }).lookup("equal")
        XCTAssertNil(offline)
        let serverError = await DictionaryClient(http: ClosureFetcher { _ in HttpResponse(status: 500, text: "") }).lookup("equal")
        XCTAssertNil(serverError)
        let badJSON = await DictionaryClient(http: ClosureFetcher { _ in ok("not json") }).lookup("equal")
        XCTAssertNil(badJSON)
        let missing = await DictionaryClient(http: ClosureFetcher { _ in notFound }).lookup("zzzz")
        XCTAssertNil(missing)
    }
}
