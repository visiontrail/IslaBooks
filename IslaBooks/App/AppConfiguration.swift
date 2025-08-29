import Foundation
import Combine

@MainActor
class AppConfiguration: ObservableObject {
    static let shared = AppConfiguration()
    
    // MARK: - App Settings
    @Published var isDarkModeEnabled: Bool = false
    @Published var preferredLanguage: String = "zh-Hans"
    @Published var isFirstLaunch: Bool = true
    
    // MARK: - Reading Settings  
    @Published var fontSize: Double = 16.0
    @Published var lineSpacing: Double = 1.2
    @Published var fontFamily: String = "System"
    @Published var nightModeEnabled: Bool = false
    
    // MARK: - AI Settings
    @Published var aiModel: String = "gpt-3.5-turbo"
    @Published var maxContextParagraphs: Int = 2
    @Published var aiResponseMode: AIResponseMode = .balanced
    
    // MARK: - Privacy Settings
    @Published var cloudSyncEnabled: Bool = true
    @Published var analyticsEnabled: Bool = false
    @Published var crashReportingEnabled: Bool = true
    
    // MARK: - API Configuration
    let apiBaseURL = "https://api.islabooks.com"
    let maxConcurrentAIRequests = 3
    let cacheSize = 100 * 1024 * 1024  // 100MB
    let syncInterval: TimeInterval = 300  // 5分钟
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSettings()
        observeSettingsChanges()
    }
    
    private func loadSettings() {
        isDarkModeEnabled = userDefaults.bool(forKey: "isDarkModeEnabled")
        preferredLanguage = userDefaults.string(forKey: "preferredLanguage") ?? "zh-Hans"
        isFirstLaunch = userDefaults.bool(forKey: "isFirstLaunch") 
        
        fontSize = userDefaults.double(forKey: "fontSize") != 0 ? userDefaults.double(forKey: "fontSize") : 16.0
        lineSpacing = userDefaults.double(forKey: "lineSpacing") != 0 ? userDefaults.double(forKey: "lineSpacing") : 1.2
        fontFamily = userDefaults.string(forKey: "fontFamily") ?? "System"
        nightModeEnabled = userDefaults.bool(forKey: "nightModeEnabled")
        
        let aiModelString = userDefaults.string(forKey: "aiModel") ?? "gpt-3.5-turbo"
        aiModel = aiModelString
        maxContextParagraphs = userDefaults.integer(forKey: "maxContextParagraphs") != 0 ? userDefaults.integer(forKey: "maxContextParagraphs") : 2
        
        if let modeRawValue = userDefaults.object(forKey: "aiResponseMode") as? String,
           let mode = AIResponseMode(rawValue: modeRawValue) {
            aiResponseMode = mode
        }
        
        cloudSyncEnabled = userDefaults.bool(forKey: "cloudSyncEnabled")
        analyticsEnabled = userDefaults.bool(forKey: "analyticsEnabled")
        crashReportingEnabled = userDefaults.bool(forKey: "crashReportingEnabled")
    }
    
    private func observeSettingsChanges() {
        // 监听设置变化并自动保存
        $isDarkModeEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "isDarkModeEnabled")
            }
            .store(in: &cancellables)
        
        $preferredLanguage
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "preferredLanguage")
            }
            .store(in: &cancellables)
        
        $fontSize
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "fontSize")
            }
            .store(in: &cancellables)
        
        $lineSpacing
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "lineSpacing")
            }
            .store(in: &cancellables)
        
        $fontFamily
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "fontFamily")
            }
            .store(in: &cancellables)
        
        $nightModeEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "nightModeEnabled")
            }
            .store(in: &cancellables)
        
        $aiModel
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "aiModel")
            }
            .store(in: &cancellables)
        
        $maxContextParagraphs
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "maxContextParagraphs")
            }
            .store(in: &cancellables)
        
        $aiResponseMode
            .sink { [weak self] value in
                self?.userDefaults.set(value.rawValue, forKey: "aiResponseMode")
            }
            .store(in: &cancellables)
        
        $cloudSyncEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "cloudSyncEnabled")
            }
            .store(in: &cancellables)
        
        $analyticsEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "analyticsEnabled")
            }
            .store(in: &cancellables)
        
        $crashReportingEnabled
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "crashReportingEnabled")
            }
            .store(in: &cancellables)
    }
    
    func completeFirstLaunch() {
        isFirstLaunch = false
        userDefaults.set(false, forKey: "isFirstLaunch")
    }
    
    func resetToDefaults() {
        // 重置所有设置为默认值
        isDarkModeEnabled = false
        fontSize = 16.0
        lineSpacing = 1.2
        fontFamily = "System"
        nightModeEnabled = false
        aiModel = "gpt-3.5-turbo"
        maxContextParagraphs = 2
        aiResponseMode = .balanced
        cloudSyncEnabled = true
        analyticsEnabled = false
        crashReportingEnabled = true
    }
}

enum AIResponseMode: String, CaseIterable {
    case rigorous = "rigorous"
    case balanced = "balanced" 
    case concise = "concise"
    
    var displayName: String {
        switch self {
        case .rigorous:
            return "严谨模式"
        case .balanced:
            return "平衡模式"
        case .concise:
            return "简洁模式"
        }
    }
    
    var description: String {
        switch self {
        case .rigorous:
            return "更详细的引用和解释"
        case .balanced:
            return "平衡详细程度和简洁性"
        case .concise:
            return "简洁明了的回答"
        }
    }
}

