#!/bin/bash

# IslaBooks iOS 开发环境快速配置脚本
# 版本: v1.0.0
# 用途: 自动化一些基础的开发环境配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 IslaBooks iOS 开发环境快速配置${NC}"
echo "============================================="
echo ""

# 确认用户意图
echo -e "${YELLOW}此脚本将帮助您自动配置一些基础的开发环境设置。${NC}"
echo "将要执行的操作："
echo "1. 创建项目目录结构"
echo "2. 配置Git仓库（如果还未配置）"
echo "3. 创建基础配置文件"
echo "4. 安装推荐的开发工具（可选）"
echo ""

read -p "是否继续？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消操作"
    exit 0
fi

echo ""

# 1. 创建项目目录结构
echo -e "${BLUE}📁 创建项目目录结构${NC}"
echo "----------------------------------------"

PROJECT_ROOT="$HOME/Desktop/workspace/code/SelfProject/IslaProject/IslaBooks"
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

# 创建标准目录结构
directories=(
    "docs"
    "scripts"
    "Resources"
    "Tests"
    ".github/workflows"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "✅ 创建目录: $dir"
    else
        echo -e "ℹ️  目录已存在: $dir"
    fi
done

echo ""

# 2. 配置Git仓库
echo -e "${BLUE}🔧 配置Git仓库${NC}"
echo "----------------------------------------"

if [ ! -d ".git" ]; then
    git init
    echo -e "✅ 初始化Git仓库"
else
    echo -e "ℹ️  Git仓库已存在"
fi

# 检查Git用户配置
git_name=$(git config --global user.name 2>/dev/null || echo "")
git_email=$(git config --global user.email 2>/dev/null || echo "")

if [ -z "$git_name" ] || [ -z "$git_email" ]; then
    echo -e "${YELLOW}⚠️  Git用户信息未配置${NC}"
    
    if [ -z "$git_name" ]; then
        read -p "请输入您的姓名: " user_name
        git config --global user.name "$user_name"
        echo -e "✅ 设置Git用户名: $user_name"
    fi
    
    if [ -z "$git_email" ]; then
        read -p "请输入您的邮箱: " user_email
        git config --global user.email "$user_email"
        echo -e "✅ 设置Git邮箱: $user_email"
    fi
else
    echo -e "✅ Git用户信息已配置: $git_name ($git_email)"
fi

echo ""

# 3. 创建.gitignore文件
echo -e "${BLUE}📝 创建配置文件${NC}"
echo "----------------------------------------"

if [ ! -f ".gitignore" ]; then
    cat > .gitignore << 'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
!*.xcworkspace/contents.xcworkspacedata
/*.gcno
**/xcshareddata/WorkspaceSettings.xcsettings

# Build generated
build/
DerivedData/

# Various settings
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/

# CocoaPods
Pods/

# Carthage
Carthage/Build/

# SwiftPM
.swiftpm/
Package.resolved

# macOS
.DS_Store

# Personal notes
notes.md
TODO.md

# Temporary files
*.tmp
*.log

# IDE
.vscode/
.idea/
EOF

    echo -e "✅ 创建.gitignore文件"
else
    echo -e "ℹ️  .gitignore文件已存在"
fi

# 创建SwiftLint配置文件
if [ ! -f ".swiftlint.yml" ]; then
    cat > .swiftlint.yml << 'EOF'
# SwiftLint配置文件
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - empty_string
  - force_unwrapping
  - implicitly_unwrapped_optional

included:
  - IslaBooks

excluded:
  - Carthage
  - Pods
  - build/
  - DerivedData/

line_length: 120
function_body_length: 100
type_body_length: 300

identifier_name:
  min_length: 2
  max_length: 40

# 自定义规则
custom_rules:
  pirates_beat_ninjas:
    name: "TODO和FIXME标记"
    regex: "(TODO|FIXME)"
    match_kinds:
      - comment
    message: "请处理TODO或FIXME标记"
    severity: warning
EOF

    echo -e "✅ 创建SwiftLint配置文件"
else
    echo -e "ℹ️  SwiftLint配置文件已存在"
fi

echo ""

# 4. 检查并安装开发工具
echo -e "${BLUE}🛠️  检查开发工具${NC}"
echo "----------------------------------------"

# 检查Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew 未安装${NC}"
    read -p "是否安装Homebrew？(推荐) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "安装Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo -e "✅ Homebrew安装完成"
    fi
else
    echo -e "✅ Homebrew已安装"
fi

# 检查SwiftLint
if ! command -v swiftlint &> /dev/null; then
    if command -v brew &> /dev/null; then
        echo -e "${YELLOW}SwiftLint 未安装${NC}"
        read -p "是否安装SwiftLint？(推荐) (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "安装SwiftLint..."
            brew install swiftlint
            echo -e "✅ SwiftLint安装完成"
        fi
    fi
else
    echo -e "✅ SwiftLint已安装"
fi

echo ""

# 5. 创建便捷脚本
echo -e "${BLUE}🔗 创建便捷脚本${NC}"
echo "----------------------------------------"

# 使脚本可执行
chmod +x scripts/*.sh 2>/dev/null || true

# 创建测试脚本别名
if [ ! -f "scripts/test.sh" ]; then
    cat > scripts/test.sh << 'EOF'
#!/bin/bash
# 运行项目测试的便捷脚本

PROJECT_NAME="IslaBooks"

echo "🧪 运行IslaBooks项目测试..."

# 检查项目是否存在
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo "❌ 项目文件不存在，请先创建Xcode项目"
    exit 1
fi

# 清理项目
echo "🧹 清理项目..."
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "$PROJECT_NAME"

# 运行单元测试
echo "🧪 运行单元测试..."
xcodebuild test \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -resultBundlePath TestResults

echo "✅ 测试完成！"
echo "📊 查看详细结果: open TestResults.xcresult"
EOF

    chmod +x scripts/test.sh
    echo -e "✅ 创建测试脚本: scripts/test.sh"
fi

# 创建构建脚本
if [ ! -f "scripts/build.sh" ]; then
    cat > scripts/build.sh << 'EOF'
#!/bin/bash
# 构建项目的便捷脚本

PROJECT_NAME="IslaBooks"

echo "🔨 构建IslaBooks项目..."

# 检查项目是否存在
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo "❌ 项目文件不存在，请先创建Xcode项目"
    exit 1
fi

# 清理项目
echo "🧹 清理项目..."
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "$PROJECT_NAME"

# 构建项目
echo "🔨 构建项目..."
xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -destination 'platform=iOS Simulator,name=iPhone 15'

echo "✅ 构建完成！"
EOF

    chmod +x scripts/build.sh
    echo -e "✅ 创建构建脚本: scripts/build.sh"
fi

echo ""

# 6. 创建开发文档
echo -e "${BLUE}📚 创建开发文档${NC}"
echo "----------------------------------------"

if [ ! -f "docs/getting-started.md" ]; then
    cat > docs/getting-started.md << 'EOF'
# IslaBooks 开发快速开始

## 环境验证

运行环境验证脚本：
```bash
./scripts/verify-environment.sh
```

## 项目构建

```bash
# 构建项目
./scripts/build.sh

# 运行测试
./scripts/test.sh
```

## 开发流程

1. 在Xcode中打开项目：`open IslaBooks.xcodeproj`
2. 选择目标设备（iPhone 15模拟器）
3. 按Cmd+R运行项目
4. 按Cmd+U运行测试

## 常用命令

```bash
# 代码规范检查
swiftlint

# Git提交
git add .
git commit -m "feat: 添加新功能"

# 查看项目状态
git status
```

## 项目结构

```
IslaBooks/
├── IslaBooks/          # 主要源代码
├── IslaBooks Tests/    # 单元测试
├── IslaBooks UITests/  # UI测试
├── docs/              # 文档
└── scripts/           # 构建脚本
```
EOF

    echo -e "✅ 创建快速开始文档"
else
    echo -e "ℹ️  快速开始文档已存在"
fi

echo ""

# 7. 提交到Git
echo -e "${BLUE}💾 提交配置到Git${NC}"
echo "----------------------------------------"

git add .
if git diff --staged --quiet; then
    echo -e "ℹ️  没有新的更改需要提交"
else
    git commit -m "chore: 初始化项目配置

- 添加.gitignore文件
- 添加SwiftLint配置
- 创建便捷脚本
- 添加开发文档"
    echo -e "✅ 配置已提交到Git"
fi

echo ""

# 完成总结
echo -e "${GREEN}🎉 快速配置完成！${NC}"
echo "============================================="
echo ""
echo -e "${BLUE}📋 已完成的配置:${NC}"
echo "✅ 创建项目目录结构"
echo "✅ 配置Git仓库和用户信息"
echo "✅ 创建.gitignore和SwiftLint配置"
echo "✅ 创建便捷脚本（test.sh, build.sh）"
echo "✅ 创建开发文档"

if command -v brew &> /dev/null; then
    echo "✅ Homebrew可用"
fi

if command -v swiftlint &> /dev/null; then
    echo "✅ SwiftLint可用"
fi

echo ""
echo -e "${BLUE}🚀 下一步操作:${NC}"
echo "1. 运行环境验证: ./scripts/verify-environment.sh"
echo "2. 在Xcode中创建新项目"
echo "3. 配置Apple Developer账号"
echo "4. 设置CloudKit容器"
echo "5. 开始编码！"

echo ""
echo -e "${BLUE}📚 参考文档:${NC}"
echo "- 详细搭建指南: docs/development-setup-guide.md"
echo "- 快速开始: docs/getting-started.md"
echo "- 技术设计: docs/technical-design.md"

echo ""
echo -e "${YELLOW}💡 提示: 如果遇到问题，请查看docs/development-setup-guide.md中的常见问题解决方案${NC}"
