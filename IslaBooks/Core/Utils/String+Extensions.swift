import Foundation
import CryptoKit

extension String {
    
    // MARK: - Validation
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return range(of: emailRegex, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    var isNotEmpty: Bool {
        return !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Text Processing
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        } else {
            return String(prefix(length)) + trailing
        }
    }
    
    func wordCount() -> Int {
        let words = components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    func estimatedReadingTime(wordsPerMinute: Int = 200) -> Int {
        let words = wordCount()
        return max(1, words / wordsPerMinute)
    }
    
    // MARK: - Path Extensions
    var deletingPathExtension: String {
        return (self as NSString).deletingPathExtension
    }
    
    var pathExtension: String {
        return (self as NSString).pathExtension
    }
    
    // MARK: - Sanitization
    func sanitizedForFileName() -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    func sanitizedForAPI() -> String {
        // 移除或替换可能导致API问题的字符
        return self
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Encoding
    func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }
    
    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Hashing
    func sha256() -> String {
        let data = Data(utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func md5() -> String {
        let data = Data(utf8)
        let hashed = Insecure.MD5.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Language Detection
    func detectLanguage() -> String {
        // 简单的中文检测
        let chineseRange = "\u{4e00}"..."\u{9fff}"
        let chineseCharacters = CharacterSet(charactersIn: chineseRange)
        
        let sampleText = String(prefix(500)) // 取前500个字符作为样本
        let chineseCount = sampleText.unicodeScalars.filter { chineseCharacters.contains($0) }.count
        let totalCount = sampleText.count
        
        if totalCount > 0 && Double(chineseCount) / Double(totalCount) > 0.3 {
            return "zh-Hans"
        }
        
        // 简单的日文检测
        let hiraganaRange = "\u{3040}"..."\u{309f}"
        let katakanaRange = "\u{30a0}"..."\u{30ff}"
        let japaneseCharacters = CharacterSet(charactersIn: hiraganaRange).union(CharacterSet(charactersIn: katakanaRange))
        
        let japaneseCount = sampleText.unicodeScalars.filter { japaneseCharacters.contains($0) }.count
        if Double(japaneseCount) / Double(totalCount) > 0.1 {
            return "ja"
        }
        
        // 简单的韩文检测
        let koreanRange = "\u{ac00}"..."\u{d7af}"
        let koreanCharacters = CharacterSet(charactersIn: koreanRange)
        
        let koreanCount = sampleText.unicodeScalars.filter { koreanCharacters.contains($0) }.count
        if Double(koreanCount) / Double(totalCount) > 0.1 {
            return "ko"
        }
        
        // 默认返回英文
        return "en"
    }
    
    // MARK: - Text Formatting
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
    
    func removingDiacritics() -> String {
        return folding(options: .diacriticInsensitive, locale: .current)
    }
    
    // MARK: - Chapter Title Processing
    func extractChapterTitle() -> String {
        // 移除章节编号前缀
        let patterns = [
            #"^第[一二三四五六七八九十\d]+章\s*"#,
            #"^Chapter\s+\d+\s*[:\-\.]?\s*"#,
            #"^\d+\.\s*"#,
            #"^[一二三四五六七八九十]+、\s*"#
        ]
        
        var title = self
        for pattern in patterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func isChapterTitle() -> Bool {
        let patterns = [
            #"^第[一二三四五六七八九十\d]+章"#,
            #"^Chapter\s+\d+"#,
            #"^第[一二三四五六七八九十\d]+节"#,
            #"^\d+\."#,
            #"^[一二三四五六七八九十]+、"#
        ]
        
        return patterns.contains { pattern in
            range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    // MARK: - URL Processing
    var isValidURL: Bool {
        return URL(string: self) != nil
    }
    
    func toURL() -> URL? {
        return URL(string: self)
    }
    
    // MARK: - JSON Processing
    func toDictionary() -> [String: Any]? {
        guard let data = data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    // MARK: - Localization
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(_ args: CVarArg...) -> String {
        return String(format: localized, arguments: args)
    }
}

// MARK: - Substring Extensions
extension Substring {
    var string: String {
        return String(self)
    }
}

// MARK: - Array of Strings Extensions
extension Array where Element == String {
    func joined(separator: String = ", ", lastSeparator: String = " 和 ") -> String {
        guard count > 1 else {
            return first ?? ""
        }
        
        if count == 2 {
            return "\(self[0])\(lastSeparator)\(self[1])"
        }
        
        let initial = dropLast().joined(separator: separator)
        return "\(initial)\(lastSeparator)\(last!)"
    }
}

