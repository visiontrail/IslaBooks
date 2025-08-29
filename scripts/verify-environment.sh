#!/bin/bash

# IslaBooks iOS 开发环境验证脚本
# 版本: v1.0.0
# 用途: 验证iOS开发环境是否正确配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 图标定义
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"

echo -e "${BLUE}🚀 IslaBooks iOS 开发环境验证${NC}"
echo "========================================"
echo ""

# 检查计数器
total_checks=0
passed_checks=0
warnings=0

# 检查函数
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${CHECK} $1 已安装"
        ((passed_checks++))
        return 0
    else
        echo -e "${CROSS} $1 未找到"
        return 1
    fi
    ((total_checks++))
}

check_version() {
    local cmd="$1"
    local expected="$2"
    local actual=$($cmd 2>/dev/null || echo "未安装")
    
    echo -e "${INFO} $cmd 版本: $actual"
    
    if [[ "$actual" == "未安装" ]]; then
        echo -e "${CROSS} $cmd 未安装"
        return 1
    else
        echo -e "${CHECK} $cmd 已安装"
        ((passed_checks++))
        return 0
    fi
}

# 1. 检查系统信息
echo -e "${BLUE}📱 系统信息检查${NC}"
echo "----------------------------------------"
((total_checks++))

# macOS版本检查
macos_version=$(sw_vers -productVersion)
echo -e "${INFO} macOS 版本: $macos_version"

# 检查是否满足最低要求 (macOS 13.0+)
if [[ $(echo "$macos_version" | cut -d. -f1) -ge 13 ]]; then
    echo -e "${CHECK} macOS 版本满足要求 (≥13.0)"
    ((passed_checks++))
else
    echo -e "${CROSS} macOS 版本过低，需要 13.0 或更高版本"
fi

# 芯片架构检查
arch=$(uname -m)
echo -e "${INFO} 芯片架构: $arch"
if [[ "$arch" == "arm64" ]]; then
    echo -e "${CHECK} Apple Silicon (M1/M2) 架构"
elif [[ "$arch" == "x86_64" ]]; then
    echo -e "${CHECK} Intel 架构"
else
    echo -e "${WARNING} 未知架构: $arch"
    ((warnings++))
fi
((passed_checks++))

echo ""

# 2. 检查存储空间
echo -e "${BLUE}💾 存储空间检查${NC}"
echo "----------------------------------------"
((total_checks++))

available_space=$(df -h / | awk 'NR==2{print $4}' | sed 's/Gi//;s/G//')
echo -e "${INFO} 可用存储空间: ${available_space}GB"

if (( $(echo "$available_space >= 50" | bc -l) )); then
    echo -e "${CHECK} 存储空间充足 (≥50GB)"
    ((passed_checks++))
else
    echo -e "${CROSS} 存储空间不足，建议至少50GB可用空间"
fi

echo ""

# 3. 检查Xcode安装
echo -e "${BLUE}🔨 Xcode 环境检查${NC}"
echo "----------------------------------------"

# 检查Xcode是否安装
((total_checks++))
if [ -d "/Applications/Xcode.app" ]; then
    echo -e "${CHECK} Xcode 已安装"
    ((passed_checks++))
    
    # 检查Xcode版本
    if command -v xcodebuild &> /dev/null; then
        xcode_version=$(xcodebuild -version | head -n1)
        echo -e "${INFO} $xcode_version"
        
        # 检查版本号是否满足要求 (15.0+)
        version_number=$(echo "$xcode_version" | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
        if (( $(echo "$version_number >= 15.0" | bc -l) )); then
            echo -e "${CHECK} Xcode 版本满足要求 (≥15.0)"
        else
            echo -e "${WARNING} Xcode 版本可能过低，建议使用 15.0 或更高版本"
            ((warnings++))
        fi
    fi
else
    echo -e "${CROSS} Xcode 未安装"
fi

# 检查命令行工具
((total_checks++))
if xcode-select -p &> /dev/null; then
    xcode_path=$(xcode-select -p)
    echo -e "${CHECK} Xcode 命令行工具已安装"
    echo -e "${INFO} 路径: $xcode_path"
    ((passed_checks++))
else
    echo -e "${CROSS} Xcode 命令行工具未安装"
    echo -e "${INFO} 运行: xcode-select --install"
fi

echo ""

# 4. 检查iOS模拟器
echo -e "${BLUE}📱 iOS 模拟器检查${NC}"
echo "----------------------------------------"
((total_checks++))

if command -v xcrun &> /dev/null; then
    # 检查可用的模拟器
    simulators=$(xcrun simctl list devices available | grep iPhone | head -5)
    if [ -n "$simulators" ]; then
        echo -e "${CHECK} iOS 模拟器可用"
        echo -e "${INFO} 可用的模拟器 (前5个):"
        echo "$simulators" | while read line; do
            echo -e "  📱 $line"
        done
        ((passed_checks++))
    else
        echo -e "${CROSS} 没有找到可用的iOS模拟器"
    fi
else
    echo -e "${CROSS} xcrun 命令不可用"
fi

echo ""

# 5. 检查开发工具
echo -e "${BLUE}🛠️  开发工具检查${NC}"
echo "----------------------------------------"

# Git检查
((total_checks++))
if check_command "git"; then
    git_version=$(git --version)
    echo -e "${INFO} $git_version"
    
    # 检查Git配置
    git_name=$(git config --global user.name 2>/dev/null || echo "未配置")
    git_email=$(git config --global user.email 2>/dev/null || echo "未配置")
    
    if [[ "$git_name" != "未配置" ]] && [[ "$git_email" != "未配置" ]]; then
        echo -e "${CHECK} Git 用户信息已配置"
        echo -e "${INFO} 用户: $git_name ($git_email)"
    else
        echo -e "${WARNING} Git 用户信息未配置"
        echo -e "${INFO} 建议运行:"
        echo -e "  git config --global user.name \"Your Name\""
        echo -e "  git config --global user.email \"your.email@example.com\""
        ((warnings++))
    fi
fi

# Homebrew检查（可选）
((total_checks++))
if check_command "brew"; then
    brew_version=$(brew --version | head -n1)
    echo -e "${INFO} $brew_version"
else
    echo -e "${INFO} Homebrew 未安装 (可选，但推荐安装以管理开发工具)"
fi

# SwiftLint检查（可选）
((total_checks++))
if check_command "swiftlint"; then
    swiftlint_version=$(swiftlint version)
    echo -e "${INFO} SwiftLint 版本: $swiftlint_version"
else
    echo -e "${INFO} SwiftLint 未安装 (可选，但推荐用于代码规范检查)"
    echo -e "${INFO} 安装命令: brew install swiftlint"
fi

echo ""

# 6. 网络连接检查
echo -e "${BLUE}🌐 网络连接检查${NC}"
echo "----------------------------------------"
((total_checks++))

# 检查到Apple服务器的连接
if ping -c 1 developer.apple.com &> /dev/null; then
    echo -e "${CHECK} Apple Developer 网站连接正常"
    ((passed_checks++))
else
    echo -e "${CROSS} 无法连接到 Apple Developer 网站"
fi

echo ""

# 7. 项目目录检查
echo -e "${BLUE}📁 项目目录检查${NC}"
echo "----------------------------------------"

project_dir="$HOME/Desktop/workspace/code/SelfProject/IslaProject/IslaBooks"
if [ -d "$project_dir" ]; then
    echo -e "${CHECK} 项目目录存在: $project_dir"
    
    # 检查是否有Xcode项目文件
    if [ -f "$project_dir/IslaBooks.xcodeproj/project.pbxproj" ]; then
        echo -e "${CHECK} Xcode 项目文件存在"
    else
        echo -e "${INFO} Xcode 项目文件不存在（如果还未创建项目，这是正常的）"
    fi
else
    echo -e "${INFO} 项目目录不存在（将在创建项目时自动创建）"
fi

echo ""

# 总结报告
echo -e "${BLUE}📊 验证总结${NC}"
echo "========================================"

echo -e "${INFO} 总检查项: $total_checks"
echo -e "${CHECK} 通过检查: $passed_checks"
echo -e "${WARNING} 警告项目: $warnings"

failed_checks=$((total_checks - passed_checks))
if [ $failed_checks -gt 0 ]; then
    echo -e "${CROSS} 失败检查: $failed_checks"
fi

# 计算成功率
success_rate=$((passed_checks * 100 / total_checks))
echo -e "${INFO} 成功率: $success_rate%"

echo ""

# 根据结果给出建议
if [ $success_rate -ge 80 ]; then
    echo -e "${GREEN}🎉 恭喜！您的开发环境基本配置完成，可以开始iOS开发！${NC}"
    
    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}💡 建议处理上述警告项以获得更好的开发体验${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🚀 下一步建议:${NC}"
    echo "1. 在Xcode中创建新的iOS项目"
    echo "2. 配置Apple Developer账号"
    echo "3. 设置CloudKit容器"
    echo "4. 开始编写第一行代码！"
    
elif [ $success_rate -ge 60 ]; then
    echo -e "${YELLOW}⚠️  您的开发环境基本可用，但建议先解决失败的检查项${NC}"
    echo ""
    echo -e "${BLUE}🔧 建议优先处理:${NC}"
    echo "1. 安装缺失的必要工具（Xcode、命令行工具等）"
    echo "2. 检查系统版本和存储空间"
    echo "3. 配置开发工具"
    
else
    echo -e "${RED}❌ 您的开发环境需要进一步配置${NC}"
    echo ""
    echo -e "${BLUE}🔧 必须处理的问题:${NC}"
    echo "1. 安装Xcode和命令行工具"
    echo "2. 确保系统满足最低要求"
    echo "3. 检查网络连接"
    echo "4. 参考详细的搭建指南: docs/development-setup-guide.md"
fi

echo ""
echo -e "${BLUE}📚 更多帮助:${NC}"
echo "- 详细搭建指南: docs/development-setup-guide.md"
echo "- 技术设计文档: docs/technical-design.md"
echo "- 需求文档: docs/requirements.md"

echo ""
echo -e "${BLUE}🐛 如果遇到问题:${NC}"
echo "1. 查看搭建指南中的常见问题解决方案"
echo "2. 检查Apple Developer文档"
echo "3. 重新运行此脚本检查修复效果"

exit 0
