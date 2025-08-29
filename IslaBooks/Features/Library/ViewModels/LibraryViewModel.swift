import Foundation
import Combine
import CoreData

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedStatus: BookStatus = .all
    
    private let bookService = BookService.shared
    private let importService = BookImportService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // 搜索文本变化时过滤书籍
        $searchText
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterBooks()
            }
            .store(in: &cancellables)
        
        // 状态筛选变化时过滤书籍
        $selectedStatus
            .sink { [weak self] _ in
                self?.filterBooks()
            }
            .store(in: &cancellables)
    }
    
    func loadBooks() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedBooks = try await bookService.fetchAllBooks()
                books = fetchedBooks
            } catch {
                errorMessage = "加载书籍失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    func importBooks(from urls: [URL]) async {
        isLoading = true
        
        for url in urls {
            do {
                let book = try await importService.importBook(from: url)
                books.append(book)
                
                // 追踪导入事件
                AnalyticsService.shared.track(event: .bookImported, properties: [
                    "file_type": url.pathExtension,
                    "source": "file_picker"
                ])
                
            } catch {
                errorMessage = "导入书籍失败: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func deleteBook(_ book: Book) async {
        do {
            try await bookService.deleteBook(book)
            books.removeAll { $0.id == book.id }
            
            // 追踪删除事件
            AnalyticsService.shared.track(event: .bookDeleted, properties: [
                "book_id": book.id.uuidString
            ])
            
        } catch {
            errorMessage = "删除书籍失败: \(error.localizedDescription)"
        }
    }
    
    func refreshLibrary() async {
        loadBooks()
    }
    
    private func filterBooks() {
        // 实现书籍过滤逻辑
        // 这里应该根据搜索文本和状态筛选来过滤books数组
    }
    
    func markAsReading(_ book: Book) async {
        await updateBookStatus(book, status: .reading)
    }
    
    func markAsFinished(_ book: Book) async {
        await updateBookStatus(book, status: .finished)
    }
    
    func markAsWantToRead(_ book: Book) async {
        await updateBookStatus(book, status: .wantToRead)
    }
    
    private func updateBookStatus(_ book: Book, status: BookStatus) async {
        do {
            try await bookService.updateBookStatus(book, status: status)
            // 更新本地状态
            if let index = books.firstIndex(where: { $0.id == book.id }) {
                // 这里需要更新书籍状态
                // books[index].status = status
            }
        } catch {
            errorMessage = "更新书籍状态失败: \(error.localizedDescription)"
        }
    }
}

enum BookStatus: String, CaseIterable {
    case all = "all"
    case reading = "reading"
    case finished = "finished"
    case wantToRead = "want_to_read"
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .reading:
            return "在读"
        case .finished:
            return "已读"
        case .wantToRead:
            return "想读"
        }
    }
}

