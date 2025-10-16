FROM nginx:latest
WORKDIR /app

# 安装必要的运行时依赖
#RUN apt-get update && apt-get install -y ca-certificates tzdata webp && rm -rf /var/lib/apt/lists/* 
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tzdata && rm -rf /var/lib/apt/lists/* && apt-get clean

# 设置时区
ENV TZ=Asia/Shanghai

# 设置默认环境变量
ENV DB_PATH=/app/data/database.db
ENV ASSETS_PATH=/app/data/assets

# 保持原始目录结构
COPY frontend /app/frontend
COPY gobackend /app/gobackend

# 复制启动脚本
COPY start.sh /app/
RUN chmod +x /app/start.sh

# 创建必要的目录
RUN mkdir -p /app/data

# 暴露端口
EXPOSE 80 443

# 设置卷挂载点
VOLUME ["/app/data"]

# 设置启动命令
CMD ["/app/start.sh"]
