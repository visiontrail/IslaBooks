import Foundation

class DataExportService {
    static let shared = DataExportService()
    
    private init() {}
    
    func exportAllUserData() async throws {
        // 委托给DataDeletionService的导出功能
        let exportURL = try await DataDeletionService.shared.exportUserData()
        
        // 显示分享界面
        await MainActor.run {
            presentShareSheet(for: exportURL)
        }
    }
    
    @MainActor
    private func presentShareSheet(for url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // iPad支持
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
}

import UIKit

