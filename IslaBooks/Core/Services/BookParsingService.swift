import Foundation
import ZIPFoundation

class BookParsingService {
    static let shared = BookParsingService()
    
    private init() {}
    
    // MARK: - ePub Parsing
    func parseEPub(at url: URL) async throws -> BookMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let metadata = try self.parseEPubSync(at: url)
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseEPubSync(at url: URL) throws -> BookMetadata {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw ParsingError.invalidEPubFile
        }
        
        // 1. 读取META-INF/container.xml获取OPF文件路径
        guard let containerEntry = archive["META-INF/container.xml"] else {
            throw ParsingError.missingContainerXML
        }
        
        let containerData = try extractData(from: containerEntry, in: archive)
        let opfPath = try parseContainerXML(containerData)
        
        // 2. 读取OPF文件
        guard let opfEntry = archive[opfPath] else {
            throw ParsingError.missingOPFFile
        }
        
        let opfData = try extractData(from: opfEntry, in: archive)
        let metadata = try parseOPF(opfData)
        
        return metadata
    }
    
    private func extractData(from entry: Entry, in archive: Archive) throws -> Data {
        var data = Data()
        try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }
    
    private func parseContainerXML(_ data: Data) throws -> String {
        // 解析container.xml获取OPF文件路径
        // 简化实现，实际应该使用XMLParser
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ParsingError.invalidXML
        }
        
        // 使用正则表达式提取full-path属性
        let pattern = #"full-path="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(xmlString.startIndex..<xmlString.endIndex, in: xmlString)
        
        if let match = regex.firstMatch(in: xmlString, range: range),
           let pathRange = Range(match.range(at: 1), in: xmlString) {
            return String(xmlString[pathRange])
        }
        
        throw ParsingError.invalidContainerXML
    }
    
    private func parseOPF(_ data: Data) throws -> BookMetadata {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ParsingError.invalidXML
        }
        
        // 提取标题
        let title = extractText(from: xmlString, pattern: #"<dc:title[^>]*>([^<]+)</dc:title>"#)
            ?? extractText(from: xmlString, pattern: #"<title[^>]*>([^<]+)</title>"#)
            ?? "未知标题"
        
        // 提取作者
        let authorPattern = #"<dc:creator[^>]*>([^<]+)</dc:creator>"#
        let authors = extractAllTexts(from: xmlString, pattern: authorPattern)
        
        // 提取语言
        let language = extractText(from: xmlString, pattern: #"<dc:language[^>]*>([^<]+)</dc:language>"#) 
            ?? "zh-Hans"
        
        return BookMetadata(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            authors: authors.isEmpty ? ["未知作者"] : authors,
            language: language,
            format: "epub"
        )
    }
    
    // MARK: - Text File Parsing
    func parseTextFile(at url: URL) async throws -> BookMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let metadata = try self.parseTextFileSync(at: url)
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseTextFileSync(at url: URL) throws -> BookMetadata {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            // 尝试其他编码
            if let content = try? String(contentsOf: url, encoding: .utf16) {
                return parseTextContent(content, filename: url.lastPathComponent)
            } else if let content = try? String(contentsOf: url, encoding: .gb_18030_2000) {
                return parseTextContent(content, filename: url.lastPathComponent)
            } else {
                throw ParsingError.unsupportedEncoding
            }
        }
        
        return parseTextContent(content, filename: url.lastPathComponent)
    }
    
    private func parseTextContent(_ content: String, filename: String) -> BookMetadata {
        let lines = content.components(separatedBy: .newlines)
        
        // 尝试从前几行提取标题和作者
        var title = filename.replacingOccurrences(of: ".txt", with: "")
        var authors = ["未知作者"]
        
        // 检查前10行是否包含标题或作者信息
        for (index, line) in lines.prefix(10).enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty {
                if index == 0 && trimmedLine.count < 100 {
                    // 第一行通常是标题
                    title = trimmedLine
                } else if trimmedLine.lowercased().contains("作者") || 
                         trimmedLine.lowercased().contains("author") {
                    // 包含作者信息的行
                    let authorLine = trimmedLine
                        .replacingOccurrences(of: "作者：", with: "")
                        .replacingOccurrences(of: "作者:", with: "")
                        .replacingOccurrences(of: "Author:", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !authorLine.isEmpty {
                        authors = [authorLine]
                    }
                }
            }
        }
        
        return BookMetadata(
            title: title,
            authors: authors,
            language: detectLanguage(content),
            format: "txt"
        )
    }
    
    // MARK: - Helper Methods
    private func extractText(from string: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let range = NSRange(string.startIndex..<string.endIndex, in: string)
            
            if let match = regex.firstMatch(in: string, range: range),
               let textRange = Range(match.range(at: 1), in: string) {
                return String(string[textRange])
            }
        } catch {
            print("Regex error: \(error)")
        }
        return nil
    }
    
    private func extractAllTexts(from string: String, pattern: String) -> [String] {
        var results: [String] = []
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let range = NSRange(string.startIndex..<string.endIndex, in: string)
            
            let matches = regex.matches(in: string, range: range)
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: string) {
                    results.append(String(string[textRange]).trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return results
    }
    
    private func detectLanguage(_ text: String) -> String {
        // 简单的语言检测
        let chineseCharacters = CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}")
        let sampleText = String(text.prefix(1000))
        
        let chineseCount = sampleText.unicodeScalars.filter { chineseCharacters.contains($0) }.count
        let totalCount = sampleText.count
        
        if totalCount > 0 && Double(chineseCount) / Double(totalCount) > 0.3 {
            return "zh-Hans"
        } else {
            return "en"
        }
    }
    
    // MARK: - Chapter Extraction
    func extractChapters(from content: String) -> [ChapterInfo] {
        var chapters: [ChapterInfo] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentChapter: ChapterInfo?
        var currentContent = ""
        var chapterNumber = 1
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检查是否是章节标题
            if isChapterTitle(trimmedLine) {
                // 保存之前的章节
                if let chapter = currentChapter {
                    chapters.append(ChapterInfo(
                        id: chapter.id,
                        number: chapter.number,
                        title: chapter.title,
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                
                // 开始新章节
                currentChapter = ChapterInfo(
                    id: UUID(),
                    number: chapterNumber,
                    title: extractChapterTitle(from: trimmedLine),
                    content: ""
                )
                currentContent = ""
                chapterNumber += 1
            } else {
                currentContent += line + "\n"
            }
        }
        
        // 保存最后一个章节
        if let chapter = currentChapter {
            chapters.append(ChapterInfo(
                id: chapter.id,
                number: chapter.number,
                title: chapter.title,
                content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        
        // 如果没有检测到章节，将整个内容作为一个章节
        if chapters.isEmpty {
            chapters.append(ChapterInfo(
                id: UUID(),
                number: 1,
                title: "正文",
                content: content
            ))
        }
        
        return chapters
    }
    
    private func isChapterTitle(_ line: String) -> Bool {
        // 检测章节标题的模式
        let patterns = [
            #"^第[一二三四五六七八九十\d]+章"#,
            #"^Chapter\s+\d+"#,
            #"^第[一二三四五六七八九十\d]+节"#,
            #"^\d+\."#,
            #"^[一二三四五六七八九十]+、"#
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
    
    private func extractChapterTitle(from line: String) -> String {
        // 提取章节标题，去除前缀数字
        let cleanTitle = line
            .replacingOccurrences(of: #"^第[一二三四五六七八九十\d]+章\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^Chapter\s+\d+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanTitle.isEmpty ? line : cleanTitle
    }
}

// MARK: - Data Models
struct BookMetadata {
    let title: String
    let authors: [String]
    let language: String
    let format: String
}

struct ChapterInfo {
    let id: UUID
    let number: Int
    let title: String
    let content: String
}

// MARK: - Error Types
enum ParsingError: LocalizedError {
    case invalidEPubFile
    case missingContainerXML
    case missingOPFFile
    case invalidXML
    case invalidContainerXML
    case unsupportedEncoding
    
    var errorDescription: String? {
        switch self {
        case .invalidEPubFile:
            return "无效的ePub文件"
        case .missingContainerXML:
            return "缺少container.xml文件"
        case .missingOPFFile:
            return "缺少OPF文件"
        case .invalidXML:
            return "无效的XML格式"
        case .invalidContainerXML:
            return "无效的container.xml格式"
        case .unsupportedEncoding:
            return "不支持的文件编码"
        }
    }
}

