#!/bin/bash

# GoComicMosaic buildah构建脚本
# 此脚本将Dockerfile.full的功能转换为buildah命令序列

set -e

echo "开始使用buildah构建GoComicMosaic镜像..."

# 设置变量
IMAGE_NAME="gocomicmosaic:latest"
CONTAINER_NAME="gocomicmosaic-builder"

# 清理可能存在的旧构建
buildah rm -a 2>/dev/null || true
buildah rmi -a 2>/dev/null || true

# 创建前端构建容器
echo "创建前端构建容器..."
frontend_container=$(buildah from --name frontend-builder node:18-alpine)
buildah config --workingdir /app/frontend $frontend_container

# 复制前端文件并构建
echo "复制前端文件并构建..."
buildah copy $frontend_container frontend/package*.json .
buildah run $frontend_container npm install --legacy-peer-deps
buildah copy $frontend_container frontend/ .
# 直接执行前端构建命令，不使用外部脚本
buildah run $frontend_container npm run build

# 创建后端构建容器
echo "创建后端构建容器..."
backend_container=$(buildah from --name backend-builder docker.io/library/golang:1.22-alpine)

# 安装构建依赖
echo "安装后端构建依赖..."
buildah run $backend_container apk update
buildah run $backend_container apk add --no-cache gcc musl-dev sqlite-dev git

# 配置环境
buildah config --workingdir /app/gobackend $backend_container
buildah config --env CGO_ENABLED=1 $backend_container

# 复制后端文件并构建
echo "复制后端文件并构建..."
buildah copy $backend_container gobackend/go.mod gobackend/go.sum .
buildah run $backend_container go mod download
buildah copy $backend_container gobackend/ .
# 直接执行后端构建命令，不使用外部脚本
buildah run $backend_container -- sh -c 'mkdir -p ./output && export CGO_ENABLED=1 && export GOOS=linux && go mod tidy && go build -ldflags="-s -w" -o ./output/app ./cmd/api'

# 复制并重命名WebP工具
buildah run $backend_container sh -c 'if [ -f "./output/app_webp" ]; then cp ./output/app_webp ./output/webp_converter; fi'

# 创建最终容器
echo "创建最终容器..."
final_container=$(buildah from --name $CONTAINER_NAME docker.io/library/nginx:alpine-perl)
buildah config --workingdir /app $final_container

# 安装运行时依赖
echo "安装运行时依赖..."
buildah run $final_container apk update
buildah run $final_container apk add --no-cache ca-certificates tzdata sqlite-libs
buildah run $final_container rm -rf /var/cache/apk/*

# 设置环境变量
buildah config --env TZ=Asia/Shanghai $final_container
buildah config --env DB_PATH=/app/data/database.db $final_container
buildah config --env ASSETS_PATH=/app/data/assets $final_container
buildah config --env DOMAIN=localhost $final_container

# 从前端构建容器复制构建产物
echo "复制构建产物..."
buildah copy --from=$frontend_container $final_container /app/frontend/dist /app/frontend/dist

# 从后端构建容器复制二进制文件
buildah copy --from=$backend_container $final_container /app/gobackend/output/app /app/gobackend/

# 复制启动脚本
buildah copy $final_container ./start.sh /app/
buildah run $final_container chmod +x /app/start.sh

# 创建必要的目录
buildah run $final_container mkdir -p /app/data /app/data/imgs /app/data/uploads /app/data/nginx /app/data/ssl

# 配置端口
buildah config --port 80 --port 443 $final_container

# 设置卷挂载点
buildah config --volume /app/data $final_container

# 设置启动命令
buildah config --cmd ["/app/start.sh"] $final_container

# 提交镜像
echo "提交镜像 $IMAGE_NAME..."
buildah commit $final_container $IMAGE_NAME

# 清理中间容器
echo "清理中间容器..."
buildah rm $frontend_container $backend_container $final_container

echo "构建完成！镜像名称: $IMAGE_NAME"
echo "使用方法: podman run -p 80:80 -p 443:443 -v ./data:/app/data $IMAGE_NAME"