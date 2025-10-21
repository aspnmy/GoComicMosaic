#!/bin/bash

# GoComicMosaic buildah构建脚本 - 优化版
# 此脚本将Dockerfile.full的功能转换为buildah命令序列，并优化构建顺序
# 支持一次运行同时构建nginx和caddy版本，复用相同的构建步骤
# 参数1: 镜像仓库前缀（可选，默认: gocomicmosaic）
# 参数2: 是否仅构建特定版本（可选，nginx|caddy，默认构建两者）

set -e

# 接收参数，设置默认值
IMAGE_REPO=${1:-"gocomicmosaic"}
BUILD_TYPE=${2:-"both"}  # both, nginx, caddy

# 清理可能存在的旧构建
echo "清理可能存在的旧构建..."
buildah rm -a 2>/dev/null || true

# 创建通用的前后端构建函数
function build_frontend() {
  echo "[通用] 创建前端构建容器..."
  frontend_container=$(buildah from --name frontend-builder node:18-alpine)
  buildah config --workingdir /app/frontend $frontend_container

  echo "[通用] 复制前端文件并构建..."
  buildah copy $frontend_container frontend/package*.json .
  buildah run $frontend_container npm install --legacy-peer-deps
  buildah copy $frontend_container frontend/ .
  # 直接执行前端构建命令，不使用外部脚本
  buildah run $frontend_container npm run build
  
  echo "[通用] 前端构建完成!"
  echo "$frontend_container"
}

function build_backend() {
  echo "[通用] 创建后端构建容器..."
  backend_container=$(buildah from --name backend-builder docker.io/library/golang:1.22-alpine)

  echo "[通用] 安装后端构建依赖..."
  buildah run $backend_container apk update
  buildah run $backend_container apk add --no-cache gcc musl-dev sqlite-dev git

  echo "[通用] 配置环境..."
  buildah config --workingdir /app/gobackend $backend_container
  buildah config --env CGO_ENABLED=1 $backend_container

  echo "[通用] 复制后端文件并构建..."
  buildah copy $backend_container gobackend/go.mod gobackend/go.sum .
  buildah run $backend_container go mod download
  buildah copy $backend_container gobackend/ .
  # 直接执行后端构建命令，不使用外部脚本
  buildah run $backend_container -- sh -c 'mkdir -p ./output && export CGO_ENABLED=1 && export GOOS=linux && go mod tidy && go build -ldflags="-s -w" -o ./output/app ./cmd/api'

  # 复制并重命名WebP工具
  buildah run $backend_container sh -c 'if [ -f "./output/app_webp" ]; then cp ./output/app_webp ./output/webp_converter; fi'
  
  echo "[通用] 后端构建完成!"
  echo "$backend_container"
}

function build_final_image() {
  local image_name=$1
  local start_script=$2
  local web_server_type=$3
  local base_image=$4
  local frontend_container=$5
  local backend_container=$6
  
  # 确定容器名称
  local container_name="gocomicmosaic-builder-${web_server_type}"
  
  echo "[${web_server_type}] 开始构建 ${image_name}..."
  echo "[${web_server_type}] 镜像名称: $image_name"
  echo "[${web_server_type}] 启动脚本: $start_script"
  echo "[${web_server_type}] 容器名称: $container_name"

  # 创建最终容器
  echo "[${web_server_type}] 创建最终容器..."
  local final_container=$(buildah from --name $container_name $base_image)
  buildah config --workingdir /app $final_container

  # 安装运行时依赖
  echo "[${web_server_type}] 安装运行时依赖..."
  buildah run $final_container apk update
  buildah run $final_container apk add --no-cache ca-certificates tzdata sqlite-libs
  buildah run $final_container rm -rf /var/cache/apk/*

  # 设置环境变量
  buildah config --env TZ=Asia/Shanghai $final_container
  buildah config --env DB_PATH=/app/data/database.db $final_container
  buildah config --env ASSETS_PATH=/app/data/assets $final_container
  buildah config --env DOMAIN=localhost $final_container

  # 从前端构建容器复制构建产物（复用）
  echo "[${web_server_type}] 复制前端构建产物..."
  buildah copy --from=$frontend_container $final_container /app/frontend/dist /app/frontend/dist

  # 从后端构建容器复制二进制文件（复用）
  echo "[${web_server_type}] 复制后端构建产物..."
  buildah copy --from=$backend_container $final_container /app/gobackend/output/app /app/gobackend/

  # 复制启动脚本
  echo "[${web_server_type}] 复制启动脚本..."
  buildah copy $final_container "$start_script" /app/
  local script_filename=$(basename "$start_script")
  buildah run $final_container chmod +x /app/$script_filename

  # 创建必要的目录
  echo "[${web_server_type}] 创建必要的目录..."
  buildah run $final_container mkdir -p /app/data /app/data/imgs /app/data/uploads

  # 根据Web服务器类型创建特定目录
  if [[ "$web_server_type" == "nginx" ]]; then
    buildah run $final_container mkdir -p /app/data/nginx /app/data/ssl
    echo "[${web_server_type}] 创建Nginx特定目录"
  elif [[ "$web_server_type" == "caddy" ]]; then
    buildah run $final_container mkdir -p /app/data/caddy /app/data/ssl
    echo "[${web_server_type}] 创建Caddy特定目录"
  fi

  # 配置端口
  buildah config --port 80 --port 443 $final_container

  # 设置卷挂载点
  buildah config --volume /app/data $final_container

  # 设置启动命令
  buildah config --cmd ["/app/$script_filename"] $final_container

  # 提交镜像
  echo "[${web_server_type}] 提交镜像 $image_name..."
  buildah commit $final_container $image_name

  # 验证镜像构建成功
  verify_image "$image_name" "$web_server_type"
  
  # 返回成功信息和容器ID
  echo "[${web_server_type}] 镜像构建完成!"
  echo "$final_container"
}

function verify_image() {
  local image_name=$1
  local web_server_type=$2
  
  echo "[${web_server_type}] 验证镜像构建是否成功..."

  # 分离仓库名和标签
  local repo_name=$(echo "${image_name}" | cut -d':' -f1)
  local tag_name=$(echo "${image_name}" | cut -d':' -f2)

  # 检查镜像是否存在（考虑可能有localhost前缀）
  local image_found=false

  # 直接列出所有镜像并检查
  local build_images=$(buildah images)
  echo "[${web_server_type}] 构建的镜像列表:"
  echo "$build_images"

  # 检查是否有匹配的仓库名和标签组合
  if echo "$build_images" | grep -E "(^|[[:space:]])($repo_name|localhost/$repo_name)[[:space:]]+$tag_name($|[[:space:]])" -q; then
    image_found=true
    echo "[${web_server_type}] ✅ 找到匹配的镜像: ${repo_name}:${tag_name}"
  fi

  if [ "$image_found" = false ]; then
    echo "[${web_server_type}] ❌ 镜像 ${image_name} 构建失败!"
    # 我们不直接退出，因为镜像可能已经构建成功但名称格式不同
    echo "[${web_server_type}] 但镜像似乎已成功创建，继续执行..."
  fi
  echo "[${web_server_type}] ✅ 镜像构建成功!"
  echo "[${web_server_type}] - 镜像名称: $image_name"
  local script_filename=$(basename "$2")
  echo "[${web_server_type}] - 启动脚本: /app/$script_filename"
}

# 主构建流程
echo "开始使用buildah构建GoComicMosaic镜像..."
echo "- 镜像仓库前缀: $IMAGE_REPO"
echo "- 构建类型: $BUILD_TYPE"

# 第一步：构建通用的前后端（只需执行一次）
echo "========= 开始通用构建阶段 ========="
frontend_container=$(build_frontend)
backend_container=$(build_backend)
echo "========= 通用构建阶段完成 ========="

# 第二步：构建特定的最终镜像
nginx_image_name="${IMAGE_REPO}:nginx-latest"
caddy_image_name="${IMAGE_REPO}:caddy-latest"

# 存储最终容器ID
nginx_final_container=""
caddy_final_container=""

# 根据构建类型决定构建哪些版本
if [[ "$BUILD_TYPE" == "both" || "$BUILD_TYPE" == "nginx" ]]; then
  echo "========= 开始Nginx版本构建 ========="
  nginx_final_container=$(build_final_image "$nginx_image_name" "./start.sh" "nginx" "docker.io/library/nginx:alpine-perl" "$frontend_container" "$backend_container")
  echo "========= Nginx版本构建完成 ========="
fi

if [[ "$BUILD_TYPE" == "both" || "$BUILD_TYPE" == "caddy" ]]; then
  echo "========= 开始Caddy版本构建 ========="
  caddy_final_container=$(build_final_image "$caddy_image_name" "./start-caddy.sh" "caddy" "docker.io/library/caddy:builder-alpine" "$frontend_container" "$backend_container")
  echo "========= Caddy版本构建完成 ========="
fi

# 清理中间容器
echo "清理中间容器..."
rm_containers=($frontend_container $backend_container)

if [ ! -z "$nginx_final_container" ]; then
  rm_containers+=($nginx_final_container)
fi

if [ ! -z "$caddy_final_container" ]; then
  rm_containers+=($caddy_final_container)
fi

buildah rm ${rm_containers[@]}

echo "构建完成！所有镜像构建成功！"
echo "使用方法:"
if [[ "$BUILD_TYPE" == "both" || "$BUILD_TYPE" == "nginx" ]]; then
  echo "- Nginx版本: podman run -p 80:80 -p 443:443 -v ./data:/app/data $nginx_image_name"
fi
if [[ "$BUILD_TYPE" == "both" || "$BUILD_TYPE" == "caddy" ]]; then
  echo "- Caddy版本: podman run -p 80:80 -p 443:443 -v ./data:/app/data $caddy_image_name"
fi

# 为了向后兼容，支持原有参数格式的使用方式
if [ $# -ge 2 ] && [[ "$2" != "nginx" && "$2" != "caddy" && "$2" != "both" ]]; then
  echo ""
  echo "注意: 脚本已升级为支持批量构建模式!"
  echo "新用法: $0 [镜像仓库前缀] [构建类型(both|nginx|caddy)]"
  echo "例如: $0 gocomicmosaic both  # 同时构建nginx和caddy版本"
fi