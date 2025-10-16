#!/bin/sh
set -e

# 环境变量默认值
export DB_PATH=${DB_PATH:-/app/data/database.db}
export ASSETS_PATH=${ASSETS_PATH:-/app/data/assets}
export DOMAIN=${DOMAIN:-localhost}

echo "正在启动服务，配置信息如下："
echo "- 数据库路径: ${DB_PATH}"
echo "- 资源路径: ${ASSETS_PATH}"
echo "- 域名: ${DOMAIN}"

# 创建必要的目录
mkdir -p /app/data
mkdir -p ${ASSETS_PATH}/imgs
mkdir -p ${ASSETS_PATH}/uploads
mkdir -p /app/data/nginx

# 检测SSL证书是否存在
SSL_AVAILABLE=false
if [ -f "/app/data/ssl/fullchain.crt"] && [ -f "/app/data/ssl/privkey.key" ]; then
    SSL_AVAILABLE=true
    echo "检测到SSL证书，将启用HTTPS"
else
    echo "未检测到SSL证书，将仅使用HTTP"
fi

# 动态生成Nginx配置
cat > /app/data/nginx/nginx.conf << EOF
# HTTP服务器
server {
    listen 80;
    server_name ${DOMAIN};
    
    $(if [ "$SSL_AVAILABLE" = true ]; then 
        echo "    # 如果SSL可用，重定向到HTTPS"
        echo "    return 301 https://\$host\$request_uri;"
        echo "}"
        echo ""
        echo "# HTTPS服务器"
        echo "server {"
        echo "    listen 443 ssl;"
        echo "    server_name ${DOMAIN};"
        echo ""
        echo "    # SSL配置"
        echo "    ssl_certificate /app/data/ssl/fullchain.crt;"
        echo "    ssl_certificate_key /app/data/ssl/privkey.key;"
        echo "    ssl_protocols TLSv1.2 TLSv1.3;"
        echo "    ssl_prefer_server_ciphers on;"
        echo "    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;"
        echo "    ssl_session_timeout 1d;"
        echo "    ssl_session_cache shared:SSL:10m;"
        echo "    ssl_session_tickets off;"
        echo ""
        echo "    # 安全头部"
        echo "    add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;"
        echo "    add_header X-Content-Type-Options nosniff;"
        echo "    add_header X-Frame-Options SAMEORIGIN;"
        echo "    add_header X-XSS-Protection \"1; mode=block\";"
    else 
        echo "    # HTTP配置"
    fi)
    
    # CORS代理端点
    location = /proxy {
        proxy_pass http://127.0.0.1:8000/proxy;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 处理大型响应
        proxy_buffer_size 16k;
        proxy_buffers 8 32k;
        proxy_busy_buffers_size 64k;
        
        # 超时设置
        proxy_connect_timeout 15s;
        proxy_read_timeout 45s;
        proxy_send_timeout 15s;
        proxy_ssl_server_name on;
    }
    
    # API请求 - 代理到Go后端
    location /app/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
    
    # 静态资源
    location /static/ {
        alias /app/frontend/dist/;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
    }
    
    # 资源文件
    location /assets/ {
        alias ${ASSETS_PATH}/;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
    }
    
    # 特定文件
    location = /favicon.ico {
        alias /app/frontend/dist/favicon.ico;
    }
    
    location = /robots.txt {
        alias /app/frontend/dist/robots.txt;
    }
    
    location = /sitemap.xml {
        alias /app/frontend/dist/sitemap.xml;
    }
    
    # 前端应用
    location / {
        root /app/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    # 限制上传大小
    client_max_body_size 50M;
}
EOF

# 链接Nginx配置
ln -sf /app/data/nginx/nginx.conf /etc/nginx/conf.d/default.conf

# 启动后端服务
echo "启动后端服务..."
cd /app
chmod +x /app/gobackend/app
/app/gobackend/app &

# 等待后端服务启动
sleep 3

# 启动nginx
echo "启动nginx服务..."
nginx -g "daemon off;"
