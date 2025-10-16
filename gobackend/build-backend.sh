#!/bin/bash
set -e

# Go后端构建脚本 - 用于Docker多阶段构建
# 功能：下载依赖、配置构建环境、编译Go应用

echo "===== 开始Go后端构建流程 ====="

# 设置默认参数
build_mode="production"
output_binary="./output/app"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --dev)
      build_mode="development"
      shift
      ;;
    --output)
      output_binary="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 创建输出目录
output_dir=$(dirname "$output_binary")
mkdir -p "$output_dir"

# 设置Go环境变量
export CGO_ENABLED=1  # SQLite需要CGO
export GOOS=linux

# 下载依赖
echo "===== 下载Go依赖 ====="
go mod tidy
go mod download

# 根据构建模式设置构建标志
if [ "$build_mode" = "production" ]; then
  echo "===== 生产模式构建 ====="
  build_flags="-ldflags='-s -w'"
else
  echo "===== 开发模式构建 ====="
  build_flags="-tags=debug"
fi

# 编译应用
echo "===== 编译Go应用 ====="
echo "输出文件: $output_binary"

# 执行构建命令
eval "go build $build_flags -o '$output_binary' ./cmd/api"

# 复制webp工具（如果需要）
if [ -d "./cmd/webp" ]; then
  echo "===== 编译WebP工具 ====="
  webp_binary="${output_binary}_webp"
  eval "go build $build_flags -o '$webp_binary' ./cmd/webp"
  echo "WebP工具已编译: $webp_binary"
fi

# 显示编译信息
echo "===== 构建信息 ====="
echo "Go版本: $(go version)"
echo "构建模式: $build_mode"
echo "文件大小: $(du -h "$output_binary" | cut -f1)"
echo "文件权限: $(ls -la "$output_binary" | awk '{print $1}')"

# 设置执行权限
chmod +x "$output_binary"

echo "===== Go后端构建完成 ====="
echo "可执行文件位于: $output_binary"
echo "===== 构建流程结束 ====="