import SwiftUI
import UniformTypeIdentifiers
import LingleafCore

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var importing = false
    @State private var message: String?
    @State private var bookToDelete: Book?

    var body: some View {
        NavigationStack {
            List {
                Section { DailyGoalCard() }
                if let current = model.state.lastOpened {
                    Section(header: SectionHeader("Continue reading")) {
                        NavigationLink(value: current.id) { BookRow(book: current) }
                    }
                }
                Section(header: SectionHeader("Your books")) {
                    ForEach(model.state.books.reversed()) { book in
                        NavigationLink(value: book.id) { BookRow(book: book) }
                            .swipeActions {
                                Button("Delete", role: .destructive) { bookToDelete = book }
                            }
                    }
                }
            }
            .overlay {
                if model.state.books.isEmpty {
                    ContentUnavailableView(
                        "Your library is empty",
                        systemImage: "books.vertical",
                        description: Text("Get a book in Discover or import a .txt file.")
                    )
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: String.self) { ReaderView(bookID: $0) }
            .toolbar {
                Button { importing = true } label: {
                    Label("Import a .txt file", systemImage: "plus")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { importFile($0) }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete book?",
                isPresented: Binding(get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } }),
                presenting: bookToDelete
            ) { book in
                Button("Delete", role: .destructive) { model.library.deleteBook(book.id) }
            } message: { book in
                Text("“\(book.title)” will be removed from your library. Your saved words stay.")
            }
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let raw = String(decoding: data, as: UTF8.self)
            let text = GutenbergClient.stripBoilerplate(raw)
            guard !text.isEmpty else { throw NetworkError("empty") }
            let title = url.deletingPathExtension().lastPathComponent
            model.library.addBook(title: title, author: "—", text: text)
            message = String(localized: "“\(title)” added to your library.")
        } catch {
            message = String(localized: "Couldn't import that file. Try a plain-text (.txt) English book.")
        }
    }
}
