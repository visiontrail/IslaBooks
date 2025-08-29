import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

class BookImportService: ObservableObject {
    static let shared = BookImportService()
    
    private let bookService = BookService.shared
    private let fileManager = FileManager.default
    private let bookParsingService = BookParsingService.shared
    
    private init() {}
    
    // MARK: - Import Methods
    func importBook(from url: URL) async throws -> Book {
        // 确保有访问权限
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // 检查文件类型
        let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
        
        guard let contentType = contentType else {
            throw ImportError.unsupportedFileType
        }
        
        // 验证文件类型
        if contentType.conforms(to: .epub) {
            return try await importEPubBook(from: url)
        } else if contentType.conforms(to: .plainText) {
            return try await importTextBook(from: url)
        } else {
            throw ImportError.unsupportedFileType
        }
    }
    
    private func importEPubBook(from url: URL) async throws -> Book {
        // 1. 创建目标路径
        let documentsPath = getDocumentsDirectory()
        let booksDirectory = documentsPath.appendingPathComponent("Books")
        try createDirectoryIfNeeded(booksDirectory)
        
        let bookId = UUID()
        let bookDirectory = booksDirectory.appendingPathComponent(bookId.uuidString)
        try createDirectoryIfNeeded(bookDirectory)
        
        // 2. 复制文件到应用文档目录
        let destinationURL = bookDirectory.appendingPathComponent(url.lastPathComponent)
        try fileManager.copyItem(at: url, to: destinationURL)
        
        // 3. 解析ePub文件
        let bookMetadata = try await bookParsingService.parseEPub(at: destinationURL)
        
        // 4. 提取封面（如果有）
        let coverPath = try await extractCover(from: destinationURL, to: bookDirectory)
        
        // 5. 计算文件校验和
        let checksum = try calculateChecksum(for: destinationURL)
        
        // 6. 创建书籍记录
        let book = try await bookService.createBook(
            title: bookMetadata.title,
            authors: bookMetadata.authors,
            language: bookMetadata.language,
            filePath: destinationURL.path,
            fileFormat: "epub",
            fileChecksum: checksum
        )
        
        // 7. 更新封面路径
        if let coverPath = coverPath {
            try await bookService.updateBookCover(book, coverPath: coverPath)
        }
        
        return book
    }
    
    private func importTextBook(from url: URL) async throws -> Book {
        // 1. 创建目标路径
        let documentsPath = getDocumentsDirectory()
        let booksDirectory = documentsPath.appendingPathComponent("Books")
        try createDirectoryIfNeeded(booksDirectory)
        
        let bookId = UUID()
        let bookDirectory = booksDirectory.appendingPathComponent(bookId.uuidString)
        try createDirectoryIfNeeded(bookDirectory)
        
        // 2. 复制文件到应用文档目录
        let destinationURL = bookDirectory.appendingPathComponent(url.lastPathComponent)
        try fileManager.copyItem(at: url, to: destinationURL)
        
        // 3. 解析文本文件
        let bookMetadata = try await bookParsingService.parseTextFile(at: destinationURL)
        
        // 4. 计算文件校验和
        let checksum = try calculateChecksum(for: destinationURL)
        
        // 5. 创建书籍记录
        let book = try await bookService.createBook(
            title: bookMetadata.title,
            authors: bookMetadata.authors,
            language: bookMetadata.language,
            filePath: destinationURL.path,
            fileFormat: "txt",
            fileChecksum: checksum
        )
        
        return book
    }
    
    // MARK: - Helper Methods
    private func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func createDirectoryIfNeeded(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func extractCover(from epubURL: URL, to directory: URL) async throws -> String? {
        // 这里应该实现ePub封面提取逻辑
        // 由于ZIPFoundation的复杂性，这里先返回nil
        // 在实际实现中，需要解压ePub文件并查找封面图片
        return nil
    }
    
    private func calculateChecksum(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return data.sha256
    }
    
    // MARK: - Validation
    func validateFile(at url: URL) throws {
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: url.path) else {
            throw ImportError.fileNotFound
        }
        
        // 检查文件大小（限制为50MB）
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int64 {
            let maxSize: Int64 = 50 * 1024 * 1024 // 50MB
            if fileSize > maxSize {
                throw ImportError.fileTooLarge
            }
        }
        
        // 检查文件类型
        let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
        guard let contentType = contentType,
              contentType.conforms(to: .epub) || contentType.conforms(to: .plainText) else {
            throw ImportError.unsupportedFileType
        }
    }
    
    // MARK: - Cleanup
    func removeImportedFile(at path: String) throws {
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }
}

// MARK: - Error Types
enum ImportError: LocalizedError {
    case fileNotFound
    case unsupportedFileType
    case fileTooLarge
    case parseError(String)
    case copyError(Error)
    case checksumError
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件不存在"
        case .unsupportedFileType:
            return "不支持的文件类型。请选择ePub或纯文本文件。"
        case .fileTooLarge:
            return "文件过大。文件大小不能超过50MB。"
        case .parseError(let message):
            return "文件解析失败: \(message)"
        case .copyError(let error):
            return "文件复制失败: \(error.localizedDescription)"
        case .checksumError:
            return "文件校验失败"
        }
    }
}

// MARK: - UTType Extensions
extension UTType {
    static let epub = UTType(filenameExtension: "epub")!
}

// MARK: - Data Extensions
extension Data {
    var sha256: String {
        let digest = self.withUnsafeBytes { bytes in
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(self.count), &digest)
            return digest
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// 添加CommonCrypto导入
import CommonCrypto

