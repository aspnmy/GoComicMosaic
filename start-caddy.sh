#!/bin/sh
set -e

# 环境变量默认值
export DB_PATH=${DB_PATH:-/app/data/database.db}
export ASSETS_PATH=${ASSETS_PATH:-/app/data/assets}
export DOMAIN=${DOMAIN:-localhost}

# 可选的Caddy配置环境变量
export ACME_EMAIL=${ACME_EMAIL:-}
# 设置为true可以使用Caddy的测试CA
export USE_TEST_CA=${USE_TEST_CA:-false}
# 设置为true可以禁用自动HTTPS
export DISABLE_HTTPS=${DISABLE_HTTPS:-false}

echo "正在启动服务，配置信息如下："
echo "- 数据库路径: ${DB_PATH}"
echo "- 资源路径: ${ASSETS_PATH}"
echo "- 域名: ${DOMAIN}"
if [ -n "${ACME_EMAIL}" ]; then
    echo "- ACME邮箱: ${ACME_EMAIL}"
fi
if [ "${USE_TEST_CA}" = true ]; then
    echo "- 使用测试CA进行证书颁发"
fi
if [ "${DISABLE_HTTPS}" = true ]; then
    echo "- 已禁用HTTPS，仅使用HTTP"
fi

# 创建必要的目录
mkdir -p /app/data
mkdir -p ${ASSETS_PATH}/imgs
mkdir -p ${ASSETS_PATH}/uploads
mkdir -p /app/data/caddy

# 动态生成Caddy配置
cat > /app/data/caddy/Caddyfile << EOF
${DOMAIN} {
    # 配置Caddy的根目录为前端应用
    root * /app/frontend/dist
    try_files {path} {path}/ /index.html
    
    # 静态资源缓存设置
    handle_path /static/* {
        root * /app/frontend/dist
        file_server
        header Cache-Control "public, max-age=2592000"
    }
    
    # 资源文件处理
    handle_path /assets/* {
        root * ${ASSETS_PATH}
        file_server
        header Cache-Control "public, max-age=2592000"
    }
    
    # API请求 - 代理到Go后端
    handle_path /app/* {
        reverse_proxy http://127.0.0.1:8000
        header_down -Server
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
    }
    
    # CORS代理端点
    handle /proxy {
        reverse_proxy http://127.0.0.1:8000/proxy
        header_down -Server
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        
        # 处理大型响应的缓冲区设置
        reverse_proxy.buffers 8 16k
        reverse_proxy.busy_buffers_size 64k
        
        # 超时设置
        reverse_proxy.timeouts {
            connect 15s
            read 45s
            write 15s
        }
    }
    
    # 特定文件处理
    handle /favicon.ico {
        root * /app/frontend/dist
        file_server
    }
    
    handle /robots.txt {
        root * /app/frontend/dist
        file_server
    }
    
    handle /sitemap.xml {
        root * /app/frontend/dist
        file_server
    }
    
    # 限制上传大小
    request_body {
        max_size 50MB
    }
    
    # 安全头部
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
    }
    
    # HTTPS相关配置
    $(if [ "${DISABLE_HTTPS}" != true ]; then
        echo "    # 配置ACME邮箱（用于证书更新通知）"
        if [ -n "${ACME_EMAIL}" ]; then
            echo "    email ${ACME_EMAIL}"
        fi
        
        echo "    # 自动HTTPS配置"
        if [ "${USE_TEST_CA}" = true ]; then
            echo "    tls internal {}"
        else
            echo "    tls {}"
        fi
        
        echo "    # HSTS头部（仅在HTTPS模式下）"
        echo "    header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always"
    else
        echo "    # 禁用HTTPS"
        echo "    tls off"
    fi)
}
EOF

# 启动后端服务
echo "启动后端服务..."
cd /app
chmod +x /app/gobackend/app
/app/gobackend/app &

# 等待后端服务启动
sleep 3

# 启动Caddy
echo "启动Caddy服务..."
# 设置Caddy数据目录
export CADDY_DATA_DIR="/app/data/caddy"
export CADDY_CONFIG="/app/data/caddy/Caddyfile"

# 运行Caddy服务，使用配置文件
caddy run --config "${CADDY_CONFIG}" --adapter caddyfile