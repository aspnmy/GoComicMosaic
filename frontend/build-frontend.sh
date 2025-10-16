#!/bin/bash
set -e

# 前端构建脚本 - 用于Docker多阶段构建
# 功能：安装依赖、构建前端应用、生成站点地图

echo "===== 开始前端构建流程 ====="

# 设置npm镜像源（可选，加速依赖安装）
if [ -n "$NPM_REGISTRY" ]; then
  echo "使用指定的NPM镜像源: $NPM_REGISTRY"
  npm config set registry $NPM_REGISTRY
fi

# 安装依赖
echo "===== 安装项目依赖 ====="
npm install --legacy-peer-deps

# 构建前端应用
echo "===== 构建前端应用 ====="
npm run build

echo "===== 前端构建完成 ====="
echo "构建产物位于：$(pwd)/dist"
echo "===== 构建流程结束 ====="