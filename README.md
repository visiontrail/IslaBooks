# IslaBooks iOS 应用

把每本书变成一位可对话的导师：获取、阅读、理解与交流，一站式完成。

## 项目概述

IslaBooks 是一款AI驱动的电子书阅读应用，专为iOS/iPadOS设计。应用支持本地ePub和文本文件导入，提供智能摘要、AI问答、个性化推荐等功能，帮助用户更好地理解和探索书籍内容。

## 技术栈

### 客户端
- **开发语言**: Swift 5.9+
- **UI框架**: SwiftUI + UIKit (复杂组件)
- **最低支持**: iOS 16.0 / iPadOS 16.0
- **数据持久化**: Core Data + CloudKit
- **文件处理**: Foundation + UniformTypeIdentifiers
- **网络请求**: URLSession + Combine
- **文档解析**: 自定义解析器基于ZIPFoundation

### 主要依赖
- ZIPFoundation (ePub文件处理)
- CloudKit (数据同步)
- CombineExt (响应式编程扩展)
- SwiftUI (用户界面)

## 项目结构

```
IslaBooks/
├── App/                          # 应用入口
│   ├── IslaBooks.swift          # 主应用文件
│   └── AppConfiguration.swift   # 应用配置
├── Features/                     # 功能模块
│   ├── Discovery/               # 发现模块
│   │   ├── Views/              # 推荐/书单界面
│   │   └── ViewModels/         # 业务逻辑
│   ├── Library/                # 书架模块
│   │   ├── Views/              # 书架/导入界面
│   │   └── ViewModels/         # 业务逻辑
│   └── Settings/               # 设置模块
├── Core/                        # 核心层
│   ├── Data/                   # 数据层
│   │   └── CoreData/           # Core Data模型
│   ├── Network/                # 网络层
│   ├── Services/               # 核心服务
│   └── Utils/                  # 工具类
└── Resources/                   # 资源文件
    ├── Assets.xcassets         # 图片资源
    └── Info.plist             # 配置文件
```

## 核心功能

### 1. 本地导入
- 支持从"文件"App导入ePub和纯文本文件
- 自动解析书籍元数据（标题、作者、语言等）
- 生成章节目录和阅读进度

### 2. AI增强阅读
- **智能摘要**: 自动生成章节和全书摘要
- **AI问答**: 基于选区和上下文的智能问答
- **翻译解释**: 实时翻译和概念解释
- **引用标注**: 所有AI回答包含原文引用

### 3. 数据同步
- 使用iCloud/CloudKit自动同步
- 支持跨设备同步阅读进度、书签、笔记
- 提供本地存储选项

### 4. 隐私保护
- 最小化数据采集
- 支持数据导出和删除
- 遵守Apple隐私指南

## 快速开始

### 🚀 全新环境快速搭建

如果您是第一次设置iOS开发环境，我们提供了完整的自动化配置：

```bash
# 1. 克隆项目
git clone <repository-url>
cd IslaBooks

# 2. 运行快速配置脚本
./scripts/quick-setup.sh

# 3. 验证环境配置
./scripts/verify-environment.sh
```

**📚 详细指南**: 查看 [开发环境搭建指南](docs/development-setup-guide.md) 获取完整的分步说明。

### 环境要求
- **操作系统**: macOS 13.0+ (Ventura)
- **开发工具**: Xcode 15.0+
- **iOS SDK**: iOS 16.0+ 
- **开发语言**: Swift 5.9+
- **存储空间**: 至少 50GB 可用空间

### 安装步骤

#### 方法一：自动化安装（推荐）
```bash
# 1. 克隆项目
git clone <repository-url>
cd IslaBooks

# 2. 运行环境验证
./scripts/verify-environment.sh

# 3. 如果环境未完全配置，运行快速配置
./scripts/quick-setup.sh
```

#### 方法二：手动安装
1. **安装Xcode**
   - 从App Store下载Xcode 15+
   - 安装命令行工具: `xcode-select --install`

2. **安装依赖**
   项目使用Swift Package Manager管理依赖，Xcode会自动下载所需的包。

3. **配置CloudKit**
   - 在Apple Developer Console创建CloudKit容器
   - 容器标识符: `iCloud.com.islabooks.app`
   - 在Xcode中配置Signing & Capabilities

4. **构建运行**
   ```bash
   # 在Xcode中打开项目
   open IslaBooks.xcodeproj
   
   # 或使用便捷脚本
   ./scripts/build.sh
   ```

### 配置说明

#### Info.plist 关键配置
- 文档类型支持 (ePub, 纯文本)
- CloudKit使用说明
- 权限描述 (文档访问、相册访问等)
- App Transport Security

#### Capabilities 设置
- ✅ CloudKit
- ✅ iCloud Documents
- ✅ Background Modes (background-processing, background-fetch)
- ✅ Associated Domains (Universal Links)
- ✅ Push Notifications

#### Build Settings
- **最低部署目标**: iOS 16.0
- **支持设备**: iPhone + iPad
- **Swift语言版本**: 5.9

## 开发指南

### 代码规范
- 使用SwiftLint进行代码规范检查
- 遵循Apple Swift编码约定
- 使用MVVM架构模式

### 测试

#### 使用便捷脚本（推荐）
```bash
# 运行完整测试套件
./scripts/test.sh

# 构建项目
./scripts/build.sh

# 验证开发环境
./scripts/verify-environment.sh
```

#### 使用Xcode命令行
```bash
# 运行单元测试
xcodebuild test -project IslaBooks.xcodeproj -scheme IslaBooks -destination 'platform=iOS Simulator,name=iPhone 15'

# 运行UI测试
xcodebuild test -project IslaBooks.xcodeproj -scheme IslaBooks -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'

# 代码规范检查
swiftlint
```

### 调试
- 使用Xcode Instruments进行性能分析
- Core Data调试使用 `-com.apple.CoreData.SQLDebug 1`
- CloudKit调试使用Console.app查看日志

## App Store 发布

### 合规清单
- [x] Info.plist权限描述完整
- [x] 隐私清单配置
- [x] CloudKit权限配置
- [x] 文档类型关联
- [x] App Transport Security配置
- [x] 支持深色模式
- [x] 多分辨率资源

### 提交前检查
1. 功能稳定性测试
2. 内存泄漏检查
3. 网络异常处理测试
4. 权限请求流程测试
5. 数据删除功能测试

## 版本计划

### v0.1 MVP
- [x] 项目初始化和基础配置
- [ ] 本地文件导入功能
- [ ] ePub解析和渲染
- [ ] 基础阅读器功能
- [ ] AI摘要功能
- [ ] iCloud同步基础功能

### v0.2
- [ ] 个性化推荐
- [ ] 完整的CloudKit同步
- [ ] 阅读统计

### v0.3
- [ ] 理解诊断测验
- [ ] 学习建议
- [ ] 高级AI功能

## 贡献指南

1. Fork项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 文档导航

### 📖 开发文档
- **[开发环境搭建指南](docs/development-setup-guide.md)** - 完整的Xcode环境配置教程
- **[技术设计文档](docs/technical-design.md)** - 系统架构和技术选型
- **[需求规格说明书](docs/requirements.md)** - 项目需求和功能说明

### 🛠️ 开发工具
- **[环境验证脚本](scripts/verify-environment.sh)** - 检查开发环境是否正确配置
- **[快速配置脚本](scripts/quick-setup.sh)** - 自动化基础环境配置
- **[测试脚本](scripts/test.sh)** - 运行完整测试套件
- **[构建脚本](scripts/build.sh)** - 项目构建和编译

### 📋 检查清单
- [ ] 开发环境配置完成
- [ ] Apple Developer账号设置
- [ ] CloudKit容器配置
- [ ] 项目编译成功
- [ ] 测试运行通过

## 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 联系方式

- 项目维护者: 郭亮
- 邮箱: [your-email@example.com]
- 项目链接: [https://github.com/yourusername/IslaBooks](https://github.com/yourusername/IslaBooks)

## 致谢

- Apple CoreData 和 CloudKit 团队
- SwiftUI 社区
- ZIPFoundation 开源项目
- 所有测试用户和贡献者

---

**注意**: 这是一个正在开发中的项目，某些功能可能尚未完全实现。请查看项目的Issues页面了解当前状态和已知问题。