// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IslaBooks",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "IslaBooks",
            targets: ["IslaBooks"]
        ),
    ],
    dependencies: [
        // ZIP文件处理
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.16"),
        
        // Combine扩展
        .package(url: "https://github.com/CombineCommunity/CombineExt.git", from: "1.8.1"),
        
        // 网络请求和图片加载
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.9.1"),
        
        // JSON处理
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.7"),
        
        // 日志
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        
        // 异步扩展
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras.git", from: "1.1.0"),
        
        // UI工具
        .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "1.1.2"),
        
        // 性能监控（可选）
        .package(url: "https://github.com/microsoft/appcenter-sdk-apple.git", from: "5.0.4")
    ],
    targets: [
        .target(
            name: "IslaBooks",
            dependencies: [
                "ZIPFoundation",
                "CombineExt", 
                "Kingfisher",
                "AnyCodable",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "AppCenter", package: "appcenter-sdk-apple"),
                .product(name: "AppCenterAnalytics", package: "appcenter-sdk-apple"),
                .product(name: "AppCenterCrashes", package: "appcenter-sdk-apple")
            ],
            path: "IslaBooks"
        ),
        .testTarget(
            name: "IslaBooksTests",
            dependencies: ["IslaBooks"],
            path: "IslaBooksTests"
        )
    ]
)

