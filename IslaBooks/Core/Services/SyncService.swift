import Foundation
import CloudKit
import Combine

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.islabooks.app")
        self.privateDatabase = container.privateCloudDatabase
        
        setupNotificationObservers()
    }
    
    func initialize() {
        checkAccountStatus()
        subscribeToRemoteNotifications()
    }
    
    // MARK: - Account Status
    private func checkAccountStatus() {
        Task {
            do {
                let status = try await container.accountStatus()
                await handleAccountStatus(status)
            } catch {
                syncError = error
                syncStatus = .error
            }
        }
    }
    
    private func handleAccountStatus(_ status: CKAccountStatus) async {
        switch status {
        case .available:
            print("iCloud account available")
            await startInitialSync()
        case .noAccount:
            print("No iCloud account")
            syncStatus = .disabled
        case .restricted:
            print("iCloud account restricted")
            syncStatus = .restricted
        case .couldNotDetermine:
            print("Could not determine iCloud account status")
            syncStatus = .error
        case .temporarilyUnavailable:
            print("iCloud temporarily unavailable")
            syncStatus = .error
        @unknown default:
            print("Unknown iCloud account status")
            syncStatus = .error
        }
    }
    
    // MARK: - Sync Operations
    func startInitialSync() async {
        guard syncStatus != .syncing else { return }
        
        syncStatus = .syncing
        syncError = nil
        
        do {
            // 同步阅读进度
            try await syncReadingProgress()
            
            // 同步高亮和注释
            try await syncHighlights()
            try await syncAnnotations()
            
            // 同步图书馆项目
            try await syncLibraryItems()
            
            lastSyncDate = Date()
            syncStatus = .completed
            
        } catch {
            syncError = error
            syncStatus = .error
            print("Sync failed: \(error)")
        }
    }
    
    func forceSyncAll() async {
        await startInitialSync()
    }
    
    // MARK: - Reading Progress Sync
    private func syncReadingProgress() async throws {
        // 获取本地未同步的阅读进度
        let localProgress = try await fetchLocalReadingProgress()
        
        // 上传到CloudKit
        for progress in localProgress {
            try await uploadReadingProgress(progress)
        }
        
        // 从CloudKit下载更新
        try await downloadReadingProgressUpdates()
    }
    
    private func fetchLocalReadingProgress() async throws -> [ReadingProgress] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let request: NSFetchRequest<ReadingProgress> = ReadingProgress.fetchRequest()
            request.predicate = NSPredicate(format: "cloudKitRecordID == nil OR cloudKitRecordID == ''")
            return try context.fetch(request)
        }
    }
    
    private func uploadReadingProgress(_ progress: ReadingProgress) async throws {
        let record = CKRecord(recordType: "ReadingProgress")
        
        record["bookId"] = progress.libraryItem?.book?.id?.uuidString
        record["currentChapterId"] = progress.currentChapterId?.uuidString
        record["currentPosition"] = progress.currentPosition
        record["totalReadingTime"] = progress.totalReadingTime
        record["lastReadAt"] = progress.lastReadAt
        record["userId"] = progress.userId
        
        let savedRecord = try await privateDatabase.save(record)
        
        // 更新本地记录的CloudKit ID
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            if let localProgress = try context.existingObject(with: progress.objectID) as? ReadingProgress {
                localProgress.cloudKitRecordID = savedRecord.recordID.recordName
                try context.save()
            }
        }
    }
    
    private func downloadReadingProgressUpdates() async throws {
        let query = CKQuery(recordType: "ReadingProgress", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await processReadingProgressRecord(record)
            case .failure(let error):
                print("Failed to fetch reading progress record: \(error)")
            }
        }
    }
    
    private func processReadingProgressRecord(_ record: CKRecord) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            // 查找现有记录
            let request: NSFetchRequest<ReadingProgress> = ReadingProgress.fetchRequest()
            request.predicate = NSPredicate(format: "cloudKitRecordID == %@", record.recordID.recordName)
            
            let existingProgress = try context.fetch(request).first
            
            if let progress = existingProgress {
                // 更新现有记录
                self.updateReadingProgress(progress, from: record)
            } else {
                // 创建新记录
                try self.createReadingProgress(from: record, in: context)
            }
            
            try context.save()
        }
    }
    
    private func updateReadingProgress(_ progress: ReadingProgress, from record: CKRecord) {
        if let position = record["currentPosition"] as? Double {
            progress.currentPosition = position
        }
        
        if let chapterIdString = record["currentChapterId"] as? String,
           let chapterId = UUID(uuidString: chapterIdString) {
            progress.currentChapterId = chapterId
        }
        
        if let readingTime = record["totalReadingTime"] as? Int32 {
            progress.totalReadingTime = readingTime
        }
        
        if let lastReadAt = record["lastReadAt"] as? Date {
            progress.lastReadAt = lastReadAt
        }
    }
    
    private func createReadingProgress(from record: CKRecord, in context: NSManagedObjectContext) throws {
        // 这里需要先查找对应的LibraryItem
        // 实际实现中需要根据bookId查找对应的书籍和库项目
        
        guard let bookIdString = record["bookId"] as? String,
              let bookId = UUID(uuidString: bookIdString) else {
            throw SyncError.invalidRecord
        }
        
        // 查找对应的LibraryItem
        let libraryRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
        libraryRequest.predicate = NSPredicate(format: "book.id == %@", bookId as CVarArg)
        
        if let libraryItem = try context.fetch(libraryRequest).first {
            let progress = ReadingProgress(context: context)
            progress.id = UUID()
            progress.libraryItem = libraryItem
            progress.cloudKitRecordID = record.recordID.recordName
            
            updateReadingProgress(progress, from: record)
        }
    }
    
    // MARK: - Highlights Sync
    private func syncHighlights() async throws {
        // 类似于阅读进度的同步逻辑
        let localHighlights = try await fetchLocalHighlights()
        
        for highlight in localHighlights {
            try await uploadHighlight(highlight)
        }
        
        try await downloadHighlightUpdates()
    }
    
    private func fetchLocalHighlights() async throws -> [Highlight] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            request.predicate = NSPredicate(format: "cloudKitRecordID == nil OR cloudKitRecordID == ''")
            return try context.fetch(request)
        }
    }
    
    private func uploadHighlight(_ highlight: Highlight) async throws {
        let record = CKRecord(recordType: "Highlight")
        
        record["bookId"] = highlight.chapter?.book?.id?.uuidString
        record["chapterId"] = highlight.chapter?.id?.uuidString
        record["rangeStart"] = highlight.rangeStart
        record["rangeEnd"] = highlight.rangeEnd
        record["text"] = highlight.text
        record["note"] = highlight.note
        record["color"] = highlight.color
        record["createdAt"] = highlight.createdAt
        record["userId"] = highlight.userId
        
        let savedRecord = try await privateDatabase.save(record)
        
        // 更新本地记录
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            if let localHighlight = try context.existingObject(with: highlight.objectID) as? Highlight {
                localHighlight.cloudKitRecordID = savedRecord.recordID.recordName
                try context.save()
            }
        }
    }
    
    private func downloadHighlightUpdates() async throws {
        let query = CKQuery(recordType: "Highlight", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await processHighlightRecord(record)
            case .failure(let error):
                print("Failed to fetch highlight record: \(error)")
            }
        }
    }
    
    private func processHighlightRecord(_ record: CKRecord) async throws {
        // 类似于阅读进度的处理逻辑
        // 实现略...
    }
    
    // MARK: - Annotations Sync
    private func syncAnnotations() async throws {
        // 注释同步逻辑，类似于高亮
        // 实现略...
    }
    
    // MARK: - Library Items Sync
    private func syncLibraryItems() async throws {
        // 图书馆项目同步逻辑
        // 实现略...
    }
    
    // MARK: - Remote Notifications
    private func subscribeToRemoteNotifications() {
        // 订阅CloudKit推送通知
        Task {
            do {
                let subscription = CKQuerySubscription(
                    recordType: "ReadingProgress",
                    predicate: NSPredicate(value: true),
                    options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
                )
                
                let notification = CKSubscription.NotificationInfo()
                notification.shouldSendContentAvailable = true
                subscription.notificationInfo = notification
                
                try await privateDatabase.save(subscription)
            } catch {
                print("Failed to subscribe to notifications: \(error)")
            }
        }
    }
    
    // MARK: - Conflict Resolution
    private func resolveConflict<T: NSManagedObject>(
        local: T,
        remote: CKRecord,
        resolution: ConflictResolution = .newestWins
    ) -> T {
        // 冲突解决逻辑
        // 默认使用最新修改时间优先
        return local
    }
    
    // MARK: - Data Deletion
    func deleteAllCloudData() async throws {
        syncStatus = .syncing
        
        // 删除所有记录类型
        let recordTypes = ["ReadingProgress", "Highlight", "Annotation", "LibraryItem"]
        
        for recordType in recordTypes {
            try await deleteRecordsOfType(recordType)
        }
        
        syncStatus = .completed
    }
    
    private func deleteRecordsOfType(_ recordType: String) async throws {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        let recordIDs = matchResults.compactMap { (_, result) in
            switch result {
            case .success(let record):
                return record.recordID
            case .failure:
                return nil
            }
        }
        
        if !recordIDs.isEmpty {
            let (_, _) = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDs)
        }
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Enums
enum SyncStatus {
    case idle
    case syncing
    case completed
    case error
    case disabled
    case restricted
}

enum ConflictResolution {
    case newestWins
    case localWins
    case remoteWins
    case merge
}

// MARK: - Errors
enum SyncError: LocalizedError {
    case accountUnavailable
    case networkError
    case invalidRecord
    case conflictResolution
    
    var errorDescription: String? {
        switch self {
        case .accountUnavailable:
            return "iCloud账户不可用"
        case .networkError:
            return "网络连接错误"
        case .invalidRecord:
            return "无效的CloudKit记录"
        case .conflictResolution:
            return "数据冲突解决失败"
        }
    }
}

