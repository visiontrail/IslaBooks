import Foundation

extension FileManager {
    
    // MARK: - Directory Management
    static func createDirectoryIfNeeded(at url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - App Directories
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    static var booksDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Books")
        try? createDirectoryIfNeeded(at: url)
        return url
    }
    
    static var coversDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Covers")
        try? createDirectoryIfNeeded(at: url)
        return url
    }
    
    static var tempDirectory: URL {
        let url = cachesDirectory.appendingPathComponent("Temp")
        try? createDirectoryIfNeeded(at: url)
        return url
    }
    
    // MARK: - File Operations
    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    func clearDirectory(at url: URL) throws {
        guard directoryExists(at: url) else { return }
        
        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for item in contents {
            try removeItem(at: item)
        }
    }
    
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    // MARK: - Safe File Operations
    func safeRemoveItem(at url: URL) {
        do {
            if fileExists(atPath: url.path) {
                try removeItem(at: url)
            }
        } catch {
            print("Failed to remove item at \(url): \(error)")
        }
    }
    
    func safeCopyItem(at sourceURL: URL, to destinationURL: URL) throws {
        // 如果目标文件存在，先删除
        if fileExists(atPath: destinationURL.path) {
            try removeItem(at: destinationURL)
        }
        
        try copyItem(at: sourceURL, to: destinationURL)
    }
    
    func safeMoveItem(at sourceURL: URL, to destinationURL: URL) throws {
        // 如果目标文件存在，先删除
        if fileExists(atPath: destinationURL.path) {
            try removeItem(at: destinationURL)
        }
        
        try moveItem(at: sourceURL, to: destinationURL)
    }
}

// MARK: - File Type Detection
extension FileManager {
    func mimeType(for url: URL) -> String? {
        guard let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return nil
        }
        
        return contentType.preferredMIMEType
    }
    
    func isEPubFile(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == "epub"
    }
    
    func isTextFile(_ url: URL) -> Bool {
        let textExtensions = ["txt", "text", "rtf"]
        return textExtensions.contains(url.pathExtension.lowercased())
    }
    
    func isSupportedBookFile(_ url: URL) -> Bool {
        return isEPubFile(url) || isTextFile(url)
    }
}

// MARK: - Unique File Names
extension FileManager {
    func uniqueFileName(for originalName: String, in directory: URL) -> String {
        let baseName = originalName.deletingPathExtension
        let fileExtension = originalName.pathExtension
        var fileName = originalName
        var counter = 1
        
        while fileExists(atPath: directory.appendingPathComponent(fileName).path) {
            if fileExtension.isEmpty {
                fileName = "\(baseName)(\(counter))"
            } else {
                fileName = "\(baseName)(\(counter)).\(fileExtension)"
            }
            counter += 1
        }
        
        return fileName
    }
    
    func uniqueURL(for originalURL: URL, in directory: URL) -> URL {
        let fileName = uniqueFileName(for: originalURL.lastPathComponent, in: directory)
        return directory.appendingPathComponent(fileName)
    }
}

