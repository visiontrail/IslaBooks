import Foundation
import CoreData
import Combine

class BookService: ObservableObject {
    static let shared = BookService()
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 监听CloudKit数据变化
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Fetch Operations
    func fetchAllBooks() async throws -> [Book] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Book.updatedAt, ascending: false)
            ]
            
            do {
                return try context.fetch(request)
            } catch {
                throw BookServiceError.fetchFailed(error)
            }
        }
    }
    
    func fetchBook(by id: UUID) async throws -> Book? {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            do {
                let books = try context.fetch(request)
                return books.first
            } catch {
                throw BookServiceError.fetchFailed(error)
            }
        }
    }
    
    func fetchBooksWithStatus(_ status: String) async throws -> [Book] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "libraryItem.status == %@", status)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Book.libraryItem.lastReadAt, ascending: false)
            ]
            
            do {
                return try context.fetch(request)
            } catch {
                throw BookServiceError.fetchFailed(error)
            }
        }
    }
    
    func searchBooks(query: String) async throws -> [Book] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            
            if !query.isEmpty {
                let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
                let authorPredicate = NSPredicate(format: "ANY authors CONTAINS[cd] %@", query)
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                    titlePredicate, authorPredicate
                ])
            }
            
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Book.title, ascending: true)
            ]
            
            do {
                return try context.fetch(request)
            } catch {
                throw BookServiceError.searchFailed(error)
            }
        }
    }
    
    // MARK: - Create Operations
    func createBook(
        title: String,
        authors: [String],
        language: String,
        filePath: String,
        fileFormat: String,
        fileChecksum: String
    ) async throws -> Book {
        let context = persistenceController.newBackgroundContext()
        
        return try await context.perform {
            let book = Book(context: context)
            book.id = UUID()
            book.title = title
            book.authors = authors
            book.language = language
            book.source = "local"
            book.filePath = filePath
            book.fileFormat = fileFormat
            book.fileChecksum = fileChecksum
            book.createdAt = Date()
            book.updatedAt = Date()
            
            do {
                try context.save()
                return book
            } catch {
                throw BookServiceError.createFailed(error)
            }
        }
    }
    
    // MARK: - Update Operations
    func updateBook(_ book: Book) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            guard let bookInContext = try context.existingObject(with: book.objectID) as? Book else {
                throw BookServiceError.bookNotFound
            }
            
            bookInContext.updatedAt = Date()
            
            do {
                try context.save()
            } catch {
                throw BookServiceError.updateFailed(error)
            }
        }
    }
    
    func updateBookStatus(_ book: Book, status: BookStatus) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            guard let bookInContext = try context.existingObject(with: book.objectID) as? Book else {
                throw BookServiceError.bookNotFound
            }
            
            if let libraryItem = bookInContext.libraryItem {
                libraryItem.status = status.rawValue
                libraryItem.lastReadAt = Date()
            } else {
                // 创建新的LibraryItem
                let libraryItem = LibraryItem(book: bookInContext, userId: getCurrentUserId(), context: context)
                libraryItem.status = status.rawValue
            }
            
            bookInContext.updatedAt = Date()
            
            do {
                try context.save()
            } catch {
                throw BookServiceError.updateFailed(error)
            }
        }
    }
    
    func updateBookCover(_ book: Book, coverPath: String) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            guard let bookInContext = try context.existingObject(with: book.objectID) as? Book else {
                throw BookServiceError.bookNotFound
            }
            
            bookInContext.coverImagePath = coverPath
            bookInContext.updatedAt = Date()
            
            do {
                try context.save()
            } catch {
                throw BookServiceError.updateFailed(error)
            }
        }
    }
    
    // MARK: - Delete Operations
    func deleteBook(_ book: Book) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            guard let bookInContext = try context.existingObject(with: book.objectID) as? Book else {
                throw BookServiceError.bookNotFound
            }
            
            // 删除本地文件
            if let filePath = bookInContext.filePath {
                try? FileManager.default.removeItem(atPath: filePath)
            }
            
            if let coverPath = bookInContext.coverImagePath {
                try? FileManager.default.removeItem(atPath: coverPath)
            }
            
            context.delete(bookInContext)
            
            do {
                try context.save()
            } catch {
                throw BookServiceError.deleteFailed(error)
            }
        }
    }
    
    // MARK: - Reading Progress
    func updateReadingProgress(
        for book: Book,
        position: Double,
        chapterId: UUID,
        readingTime: Int32
    ) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            guard let bookInContext = try context.existingObject(with: book.objectID) as? Book else {
                throw BookServiceError.bookNotFound
            }
            
            if let libraryItem = bookInContext.libraryItem {
                if let progress = libraryItem.readingProgress {
                    progress.updateProgress(position: position, chapterId: chapterId)
                    progress.totalReadingTime += readingTime
                } else {
                    let progress = ReadingProgress(libraryItem: libraryItem, context: context)
                    progress.updateProgress(position: position, chapterId: chapterId)
                    progress.totalReadingTime = readingTime
                }
                
                libraryItem.lastReadAt = Date()
            } else {
                // 创建LibraryItem和ReadingProgress
                let libraryItem = LibraryItem(book: bookInContext, userId: getCurrentUserId(), context: context)
                let progress = ReadingProgress(libraryItem: libraryItem, context: context)
                progress.updateProgress(position: position, chapterId: chapterId)
                progress.totalReadingTime = readingTime
            }
            
            do {
                try context.save()
            } catch {
                throw BookServiceError.updateFailed(error)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserId() -> String {
        // 返回当前iCloud用户标识符的哈希值
        // 在实际实现中，这应该从CloudKit获取当前用户标识符
        return "default_user"
    }
}

// MARK: - Error Types
enum BookServiceError: LocalizedError {
    case fetchFailed(Error)
    case createFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case searchFailed(Error)
    case bookNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "获取书籍失败: \(error.localizedDescription)"
        case .createFailed(let error):
            return "创建书籍失败: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "更新书籍失败: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "删除书籍失败: \(error.localizedDescription)"
        case .searchFailed(let error):
            return "搜索书籍失败: \(error.localizedDescription)"
        case .bookNotFound:
            return "未找到指定书籍"
        case .invalidData:
            return "无效的书籍数据"
        }
    }
}

