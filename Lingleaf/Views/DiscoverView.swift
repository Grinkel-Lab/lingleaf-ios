import SwiftUI
import LingleafCore

/// Search and download free public-domain books from Project Gutenberg.
struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var recommended: [GutenbergBook] = []
    @State private var results: [GutenbergBook]?
    @State private var loading = false
    @State private var failed = false
    @State private var downloading: Set<Int> = []
    @State private var message: String?

    private var downloaded: Set<Int> { Set(model.state.books.compactMap(\.gutenbergID)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if loading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if failed {
                        VStack(spacing: 12) {
                            Text("Couldn't load the catalog. Check your connection.")
                            Button("Retry") { Task { await load(results == nil ? nil : query) } }
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                    } else if (results ?? recommended).isEmpty {
                        Text("No books found. Try another title or author.")
                    } else {
                        ForEach(results ?? recommended) { row($0) }
                    }
                } header: {
                    // The credit lives in the header: as a footer, a row among the books or
                    // a section of its own, the audit reported it as not scaling with Dynamic Type.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(results == nil ? "Recommended for learners" : "Results")
                        Text("Free public-domain classics from Project Gutenberg.")
                            .font(.footnote)
                            .textCase(nil)
                    }
                    .foregroundStyle(Brand.secondaryText)
                }
            }
            .navigationTitle("Discover")
            .searchable(text: $query, prompt: "Title or author")
            .onSubmit(of: .search) { Task { await load(query) } }
            .onChange(of: query) { _, newValue in if newValue.isEmpty { results = nil } }
            .task { if recommended.isEmpty { await load(nil) } }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func row(_ book: GutenbergBook) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: book.coverURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                BookCover(title: book.title)
            }
            .frame(width: 44, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.headline)
                HStack(spacing: 6) {
                    if let level = GutenbergClient.level(for: book.id) { LevelBadge(level: level) }
                    Text(book.authorName ?? String(localized: "Unknown author"))
                        .font(.subheadline).foregroundStyle(Brand.secondaryText)
                }
            }
            Spacer(minLength: 8)
            if downloaded.contains(book.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Brand.ink)
                    .accessibilityLabel(Text("In your library"))
            } else if downloading.contains(book.id) {
                ProgressView()
                    .accessibilityLabel(Text("Downloading"))
            } else if book.textURL != nil {
                Button("Get") { Task { await download(book) } }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("Get \(book.title)"))
            } else {
                // No plain-text edition: a disabled button would be dimmed below readable contrast.
                Text("Not available")
                    .font(.subheadline)
                    .foregroundStyle(Brand.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private func load(_ search: String?) async {
        loading = true
        failed = false
        defer { loading = false }
        do {
            if let search, !search.trimmingCharacters(in: .whitespaces).isEmpty {
                results = try await model.gutenberg.search(search.trimmingCharacters(in: .whitespaces))
            } else {
                recommended = try await model.gutenberg.fetchRecommended()
            }
        } catch {
            failed = true
        }
    }

    private func download(_ book: GutenbergBook) async {
        downloading.insert(book.id)
        defer { downloading.remove(book.id) }
        do {
            let text = try await model.gutenberg.downloadText(book)
            model.library.addBook(
                title: book.title,
                author: book.authorName ?? String(localized: "Unknown author"),
                text: text,
                level: GutenbergClient.level(for: book.id),
                gutenbergID: book.id
            )
            message = String(localized: "“\(book.title)” is in your library.")
        } catch {
            message = String(localized: "Couldn't download “\(book.title)”. Try again.")
        }
    }
}
