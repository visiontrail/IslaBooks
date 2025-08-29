import Foundation
import CoreData

class DataDeletionService {
    static let shared = DataDeletionService()
    
    private let persistenceController = PersistenceController.shared
    private let syncService = SyncService.shared
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Complete Data Deletion
    func deleteAllUserData() async throws {
        // 1. 删除CloudKit数据
        try await deleteCloudKitData()
        
        // 2. 删除本地Core Data数据
        try await deleteLocalCoreData()
        
        // 3. 删除本地文件
        try await deleteLocalFiles()
        
        // 4. 清除UserDefaults
        clearUserDefaults()
        
        // 5. 清除缓存
        clearCaches()
        
        // 6. 通知应用重置
        NotificationCenter.default.post(name: .userDataDeleted, object: nil)
    }
    
    // MARK: - CloudKit Data Deletion
    private func deleteCloudKitData() async throws {
        do {
            try await syncService.deleteAllCloudData()
        } catch {
            print("Failed to delete CloudKit data: \(error)")
            // 继续删除本地数据，即使CloudKit删除失败
        }
    }
    
    // MARK: - Local Core Data Deletion
    private func deleteLocalCoreData() async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            // 删除所有实体的数据
            let entityNames = [
                "ReadingProgress",
                "Highlight", 
                "Annotation",
                "LibraryItem",
                "Chapter",
                "Book"
            ]
            
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                
                do {
                    let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                    
                    if let objectIDs = result?.result as? [NSManagedObjectID] {
                        // 通知主上下文更新
                        let changes = [NSDeletedObjectsKey: objectIDs]
                        NSManagedObjectContext.mergeChanges(
                            fromRemoteContextSave: changes,
                            into: [self.persistenceController.container.viewContext]
                        )
                    }
                } catch {
                    print("Failed to delete \(entityName): \(error)")
                    throw DataDeletionError.coreDataDeletionFailed(entityName, error)
                }
            }
            
            try context.save()
        }
    }
    
    // MARK: - Local Files Deletion
    private func deleteLocalFiles() async throws {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 删除Books目录
        let booksURL = documentsURL.appendingPathComponent("Books")
        if fileManager.fileExists(atPath: booksURL.path) {
            try fileManager.removeItem(at: booksURL)
        }
        
        // 删除Covers目录
        let coversURL = documentsURL.appendingPathComponent("Covers")
        if fileManager.fileExists(atPath: coversURL.path) {
            try fileManager.removeItem(at: coversURL)
        }
        
        // 删除Cache目录
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let appCacheURL = cachesURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.islabooks.app")
        if fileManager.fileExists(atPath: appCacheURL.path) {
            try fileManager.removeItem(at: appCacheURL)
        }
    }
    
    // MARK: - UserDefaults Cleanup
    private func clearUserDefaults() {
        let defaults = UserDefaults.standard
        
        // 保留系统设置，只删除应用相关数据
        let keysToDelete = [
            "user_properties",
            "stored_events",
            "anonymous_user_id",
            "last_sync_date",
            "ai_cache",
            "reading_statistics"
        ]
        
        for key in keysToDelete {
            defaults.removeObject(forKey: key)
        }
        
        // 重置应用配置为默认值，但保留用户偏好设置如语言、字体等
        // AppConfiguration.shared.resetToDefaults()
    }
    
    // MARK: - Cache Cleanup
    private func clearCaches() {
        // 清除内存缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 清除自定义缓存
        // CacheManager.shared.clearAll()
    }
    
    // MARK: - Selective Deletion
    func deleteBook(_ bookId: UUID) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            // 查找书籍
            let bookRequest: NSFetchRequest<Book> = Book.fetchRequest()
            bookRequest.predicate = NSPredicate(format: "id == %@", bookId as CVarArg)
            
            guard let book = try context.fetch(bookRequest).first else {
                throw DataDeletionError.bookNotFound
            }
            
            // 删除本地文件
            if let filePath = book.filePath {
                try? self.fileManager.removeItem(atPath: filePath)
            }
            
            if let coverPath = book.coverImagePath {
                try? self.fileManager.removeItem(atPath: coverPath)
            }
            
            // 删除数据库记录（级联删除会自动删除相关数据）
            context.delete(book)
            
            try context.save()
        }
    }
    
    func deleteReadingData(for bookId: UUID) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            // 删除阅读进度
            let progressRequest: NSFetchRequest<ReadingProgress> = ReadingProgress.fetchRequest()
            progressRequest.predicate = NSPredicate(format: "libraryItem.book.id == %@", bookId as CVarArg)
            
            let progressItems = try context.fetch(progressRequest)
            progressItems.forEach { context.delete($0) }
            
            // 删除高亮
            let highlightRequest: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            highlightRequest.predicate = NSPredicate(format: "chapter.book.id == %@", bookId as CVarArg)
            
            let highlights = try context.fetch(highlightRequest)
            highlights.forEach { context.delete($0) }
            
            // 删除注释
            let annotationRequest: NSFetchRequest<Annotation> = Annotation.fetchRequest()
            annotationRequest.predicate = NSPredicate(format: "chapter.book.id == %@", bookId as CVarArg)
            
            let annotations = try context.fetch(annotationRequest)
            annotations.forEach { context.delete($0) }
            
            try context.save()
        }
    }
    
    // MARK: - Data Export (before deletion)
    func exportUserData() async throws -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documentsURL.appendingPathComponent("IslaBooks_Export_\(Date().timeIntervalSince1970)")
        
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        
        // 导出Core Data数据
        try await exportCoreDataToJSON(to: exportURL)
        
        // 导出用户设置
        try exportUserSettings(to: exportURL)
        
        // 压缩导出目录
        let zipURL = documentsURL.appendingPathComponent("IslaBooks_Export.zip")
        try await createZipArchive(from: exportURL, to: zipURL)
        
        // 清理临时目录
        try fileManager.removeItem(at: exportURL)
        
        return zipURL
    }
    
    private func exportCoreDataToJSON(to exportURL: URL) async throws {
        let context = persistenceController.container.viewContext
        
        try await context.perform {
            // 导出Books
            let bookRequest: NSFetchRequest<Book> = Book.fetchRequest()
            let books = try context.fetch(bookRequest)
            let booksData = try JSONSerialization.data(withJSONObject: books.map { self.bookToDict($0) })
            try booksData.write(to: exportURL.appendingPathComponent("books.json"))
            
            // 导出Reading Progress
            let progressRequest: NSFetchRequest<ReadingProgress> = ReadingProgress.fetchRequest()
            let progress = try context.fetch(progressRequest)
            let progressData = try JSONSerialization.data(withJSONObject: progress.map { self.progressToDict($0) })
            try progressData.write(to: exportURL.appendingPathComponent("reading_progress.json"))
            
            // 导出Highlights
            let highlightRequest: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            let highlights = try context.fetch(highlightRequest)
            let highlightsData = try JSONSerialization.data(withJSONObject: highlights.map { self.highlightToDict($0) })
            try highlightsData.write(to: exportURL.appendingPathComponent("highlights.json"))
            
            // 导出Annotations
            let annotationRequest: NSFetchRequest<Annotation> = Annotation.fetchRequest()
            let annotations = try context.fetch(annotationRequest)
            let annotationsData = try JSONSerialization.data(withJSONObject: annotations.map { self.annotationToDict($0) })
            try annotationsData.write(to: exportURL.appendingPathComponent("annotations.json"))
        }
    }
    
    private func exportUserSettings(to exportURL: URL) throws {
        let settings = [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown",
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "user_preferences": getUserPreferences()
        ]
        
        let settingsData = try JSONSerialization.data(withJSONObject: settings)
        try settingsData.write(to: exportURL.appendingPathComponent("settings.json"))
    }
    
    private func getUserPreferences() -> [String: Any] {
        let appConfig = AppConfiguration.shared
        return [
            "preferred_language": appConfig.preferredLanguage,
            "font_size": appConfig.fontSize,
            "line_spacing": appConfig.lineSpacing,
            "night_mode_enabled": appConfig.nightModeEnabled,
            "ai_model": appConfig.aiModel,
            "cloud_sync_enabled": appConfig.cloudSyncEnabled
        ]
    }
    
    private func createZipArchive(from sourceURL: URL, to destinationURL: URL) async throws {
        // 这里应该实现ZIP压缩逻辑
        // 可以使用Compression框架或第三方库如ZIPFoundation
        // 简化实现，直接复制目录
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
    
    // MARK: - Helper Methods for Data Export
    private func bookToDict(_ book: Book) -> [String: Any] {
        return [
            "id": book.id?.uuidString ?? "",
            "title": book.title ?? "",
            "authors": book.authors ?? [],
            "language": book.language ?? "",
            "created_at": ISO8601DateFormatter().string(from: book.createdAt ?? Date())
        ]
    }
    
    private func progressToDict(_ progress: ReadingProgress) -> [String: Any] {
        return [
            "id": progress.id?.uuidString ?? "",
            "book_id": progress.libraryItem?.book?.id?.uuidString ?? "",
            "current_position": progress.currentPosition,
            "total_reading_time": progress.totalReadingTime,
            "last_read_at": ISO8601DateFormatter().string(from: progress.lastReadAt ?? Date())
        ]
    }
    
    private func highlightToDict(_ highlight: Highlight) -> [String: Any] {
        return [
            "id": highlight.id?.uuidString ?? "",
            "text": highlight.text ?? "",
            "note": highlight.note ?? "",
            "color": highlight.color ?? "",
            "created_at": ISO8601DateFormatter().string(from: highlight.createdAt ?? Date())
        ]
    }
    
    private func annotationToDict(_ annotation: Annotation) -> [String: Any] {
        return [
            "id": annotation.id?.uuidString ?? "",
            "content": annotation.content ?? "",
            "created_at": ISO8601DateFormatter().string(from: annotation.createdAt ?? Date())
        ]
    }
}

// MARK: - Error Types
enum DataDeletionError: LocalizedError {
    case coreDataDeletionFailed(String, Error)
    case fileDeletionFailed(Error)
    case cloudKitDeletionFailed(Error)
    case bookNotFound
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .coreDataDeletionFailed(let entity, let error):
            return "删除\(entity)数据失败: \(error.localizedDescription)"
        case .fileDeletionFailed(let error):
            return "删除文件失败: \(error.localizedDescription)"
        case .cloudKitDeletionFailed(let error):
            return "删除云端数据失败: \(error.localizedDescription)"
        case .bookNotFound:
            return "未找到指定书籍"
        case .exportFailed(let error):
            return "导出数据失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let userDataDeleted = Notification.Name("userDataDeleted")
}

