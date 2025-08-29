import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appConfiguration: AppConfiguration
    @StateObject private var syncService = SyncService()
    @State private var showingDataDeletion = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // 阅读设置
                Section("阅读设置") {
                    NavigationLink("显示设置") {
                        DisplaySettingsView()
                    }
                    
                    NavigationLink("AI助手设置") {
                        AISettingsView()
                    }
                }
                
                // 数据与隐私
                Section("数据与隐私") {
                    HStack {
                        Text("iCloud同步")
                        Spacer()
                        Toggle("", isOn: $appConfiguration.cloudSyncEnabled)
                    }
                    
                    HStack {
                        Text("分析数据")
                        Spacer()
                        Toggle("", isOn: $appConfiguration.analyticsEnabled)
                    }
                    
                    Button("导出数据") {
                        exportUserData()
                    }
                    
                    Button("删除所有数据") {
                        showingDataDeletion = true
                    }
                    .foregroundColor(.red)
                }
                
                // 通用设置
                Section("通用") {
                    HStack {
                        Text("语言")
                        Spacer()
                        Text(languageDisplayName)
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("通知设置") {
                        NotificationSettingsView()
                    }
                }
                
                // 关于
                Section("关于") {
                    Button("关于IslaBooks") {
                        showingAbout = true
                    }
                    
                    Button("隐私政策") {
                        openPrivacyPolicy()
                    }
                    
                    Button("服务条款") {
                        openTermsOfService()
                    }
                    
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .confirmationDialog(
                "删除所有数据",
                isPresented: $showingDataDeletion,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    deleteAllData()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("此操作将永久删除您的所有数据，包括书籍、阅读进度、笔记等。此操作无法撤销。")
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
    
    private var languageDisplayName: String {
        switch appConfiguration.preferredLanguage {
        case "zh-Hans":
            return "简体中文"
        case "zh-Hant":
            return "繁體中文"
        case "en":
            return "English"
        default:
            return "简体中文"
        }
    }
    
    private func exportUserData() {
        // 实现数据导出功能
        Task {
            do {
                try await DataExportService.shared.exportAllUserData()
                // 显示成功提示
            } catch {
                // 显示错误提示
            }
        }
    }
    
    private func deleteAllData() {
        Task {
            do {
                try await DataDeletionService.shared.deleteAllUserData()
                // 显示成功提示并重启应用
            } catch {
                // 显示错误提示
            }
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://islabooks.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: "https://islabooks.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}

struct DisplaySettingsView: View {
    @EnvironmentObject var appConfiguration: AppConfiguration
    
    var body: some View {
        List {
            Section("字体") {
                HStack {
                    Text("字体大小")
                    Spacer()
                    Text("\(Int(appConfiguration.fontSize))pt")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $appConfiguration.fontSize,
                    in: 12...24,
                    step: 1
                )
                
                HStack {
                    Text("行间距")
                    Spacer()
                    Text(String(format: "%.1f", appConfiguration.lineSpacing))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $appConfiguration.lineSpacing,
                    in: 1.0...2.0,
                    step: 0.1
                )
            }
            
            Section("主题") {
                HStack {
                    Text("夜间模式")
                    Spacer()
                    Toggle("", isOn: $appConfiguration.nightModeEnabled)
                }
                
                HStack {
                    Text("跟随系统")
                    Spacer()
                    Toggle("", isOn: $appConfiguration.isDarkModeEnabled)
                }
            }
        }
        .navigationTitle("显示设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AISettingsView: View {
    @EnvironmentObject var appConfiguration: AppConfiguration
    
    var body: some View {
        List {
            Section("AI模型") {
                Picker("选择模型", selection: $appConfiguration.aiModel) {
                    Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
                    Text("GPT-4").tag("gpt-4")
                    Text("Claude-3").tag("claude-3")
                }
                .pickerStyle(.menu)
            }
            
            Section("回答设置") {
                Picker("回答模式", selection: $appConfiguration.aiResponseMode) {
                    ForEach(AIResponseMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.menu)
                
                HStack {
                    Text("上下文段落数")
                    Spacer()
                    Text("\(appConfiguration.maxContextParagraphs)")
                        .foregroundColor(.secondary)
                }
                
                Stepper(
                    "上下文段落数",
                    value: $appConfiguration.maxContextParagraphs,
                    in: 1...5
                )
                .labelsHidden()
            }
            
            Section(footer: Text("AI功能需要网络连接，可能产生费用。您可以在设置中随时关闭。")) {
                EmptyView()
            }
        }
        .navigationTitle("AI助手设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView: View {
    @State private var readingReminders = true
    @State private var aiSummaryNotifications = true
    @State private var updateNotifications = false
    
    var body: some View {
        List {
            Section("阅读提醒") {
                HStack {
                    Text("每日阅读提醒")
                    Spacer()
                    Toggle("", isOn: $readingReminders)
                }
                
                if readingReminders {
                    DatePicker(
                        "提醒时间",
                        selection: .constant(Date()),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
            
            Section("AI助手") {
                HStack {
                    Text("摘要完成通知")
                    Spacer()
                    Toggle("", isOn: $aiSummaryNotifications)
                }
            }
            
            Section("应用更新") {
                HStack {
                    Text("更新通知")
                    Spacer()
                    Toggle("", isOn: $updateNotifications)
                }
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                
                VStack(spacing: 8) {
                    Text("IslaBooks")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("版本 1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Text("把每本书变成一位可对话的导师")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("感谢使用IslaBooks！")
                        .font(.headline)
                    
                    Text("IslaBooks 是一款AI驱动的电子书阅读应用，致力于提供智能的阅读体验。通过AI助手，您可以更好地理解和探索书籍内容。")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 关闭About页面
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppConfiguration())
}

