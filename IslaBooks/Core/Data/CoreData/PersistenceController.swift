import CoreData
import CloudKit

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建一些预览数据
        let sampleBook = Book(context: viewContext)
        sampleBook.id = UUID()
        sampleBook.title = "示例书籍"
        sampleBook.authors = ["示例作者"]
        sampleBook.language = "zh-Hans"
        sampleBook.source = "local"
        sampleBook.createdAt = Date()
        sampleBook.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    lazy var container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "IslaBooks")
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        if !inMemory {
            // 配置CloudKit
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // 设置CloudKit容器标识符
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.islabooks.app"
            )
        } else {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    private let inMemory: Bool
    
    private init(inMemory: Bool = false) {
        self.inMemory = inMemory
        
        // 监听远程变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }
    
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveContext() {
        save()
    }
    
    @objc private func storeRemoteChange(_ notification: Notification) {
        // 处理CloudKit远程变更
        DispatchQueue.main.async {
            // 刷新UI或触发数据重新加载
            NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
        }
    }
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - CloudKit Management
    func initializeCloudKitSchema() async throws {
        // 初始化CloudKit Schema
        try await container.initializeCloudKitSchema()
    }
    
    func resetCloudKitData() async throws {
        // 重置CloudKit数据（用于数据删除功能）
        // 注意：这个操作会删除所有CloudKit私有数据库中的记录
        // 实际实现需要调用CloudKit API
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
}

// MARK: - Core Data Extensions
extension Book {
    var readingProgress: Double? {
        guard let progress = libraryItem?.readingProgress else { return nil }
        return progress.currentPosition
    }
    
    convenience init(title: String, authors: [String], context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.authors = authors
        self.source = "local"
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension LibraryItem {
    convenience init(book: Book, userId: String, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.book = book
        self.userId = userId
        self.status = "want_to_read"
        self.addedAt = Date()
        self.isFavorite = false
        self.tags = []
    }
}

extension ReadingProgress {
    convenience init(libraryItem: LibraryItem, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.libraryItem = libraryItem
        self.userId = libraryItem.userId ?? ""
        self.currentPosition = 0.0
        self.totalReadingTime = 0
        self.lastReadAt = Date()
    }
    
    func updateProgress(position: Double, chapterId: UUID) {
        self.currentPosition = position
        self.currentChapterId = chapterId
        self.lastReadAt = Date()
    }
}

extension Highlight {
    convenience init(
        text: String,
        range: NSRange,
        chapter: Chapter,
        userId: String,
        context: NSManagedObjectContext
    ) {
        self.init(context: context)
        self.id = UUID()
        self.text = text
        self.rangeStart = Int64(range.location)
        self.rangeEnd = Int64(range.location + range.length)
        self.chapter = chapter
        self.userId = userId
        self.color = "yellow"
        self.createdAt = Date()
    }
}

extension Annotation {
    convenience init(
        content: String,
        range: NSRange,
        chapter: Chapter,
        userId: String,
        context: NSManagedObjectContext
    ) {
        self.init(context: context)
        self.id = UUID()
        self.content = content
        self.rangeStart = Int64(range.location)
        self.rangeEnd = Int64(range.location + range.length)
        self.chapter = chapter
        self.userId = userId
        self.createdAt = Date()
    }
}

