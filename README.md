# GoComicMosaic
一款开源影视资源共建平台，不同用户可以自由提交资源信息(标题、类型、简介、图片、资源链接)，像马赛克一样，由多方贡献拼凑成完整资源。 集成网盘搜索、分季分集剧集信息查看、在线点播(支持采集解析和自定义爬虫)等功能

## 项目结构

```
GoComicMosaic/
├── frontend/            # 前端应用（Vue.js）
│   ├── build-frontend.sh    # 前端构建脚本
│   └── Dockerfile.multistage # 前端多阶段构建Dockerfile
├── gobackend/           # 后端服务（Go语言）
│   ├── build-backend.sh     # 后端构建脚本
│   └── Dockerfile.multistage # 后端多阶段构建Dockerfile
├── Dockerfile.full      # 完整应用多阶段构建Dockerfile
├── build-with-buildah.sh # Buildah构建脚本
├── start.sh             # 应用启动脚本
└── .gitignore           # Git忽略文件配置
```


如果喜欢，点个star  

---

## 构建说明

### 使用Docker构建

#### 完整应用构建

```bash
docker build -t gocomicmosaic -f Dockerfile.full .
```

#### 单独构建前端

```bash
cd frontend
docker build -t gocomicmosaic-frontend -f Dockerfile.multistage .
```

#### 单独构建后端

```bash
cd gobackend
docker build -t gocomicmosaic-backend -f Dockerfile.multistage .
```

### 使用Buildah构建

```bash
./build-with-buildah.sh
```

## 使用Docker Compose部署

项目提供了多种Docker Compose配置文件，以适应不同的部署需求：

### 1. 标准构建部署（推荐）

使用项目中的源代码进行构建并部署：

```bash
docker-compose up -d
```

这将使用 `docker-compose.yml` 和 `docker-compose.override.yml`（开发环境）文件。在生产环境中，您可以忽略override文件：

```bash
docker-compose -f docker-compose.yml up -d
```

### 2. 使用预构建镜像快速部署

如果您不想构建镜像，也可以使用预构建的镜像直接部署：

```bash
docker-compose -f docker-compose-standalone.yml up -d
```

### 3. 自定义部署参数

可以通过环境变量或修改docker-compose文件来自定义部署参数：

```bash
# 通过环境变量设置DOMAIN
export DOMAIN=your-domain.com
docker-compose up -d
```

## Docker一键部署（传统方式）

如果您仍然想使用传统的docker run命令：

```bash
docker run -d --name dongman \
  -p 80:80 -p 443:443 \
  -v /your/local/path:/app/data \
  -e DOMAIN=your-domain.com \
  2011820123/gcm:latest
```

## 运行应用

### 使用Docker运行自定义构建镜像

```bash
docker run -d \
  -p 80:80 \
  -p 443:443 \
  -v ./data:/app/data \
  --name gocomicmosaic \
  gocomicmosaic:latest
```

### 使用Podman运行

```bash
podman run -d \
  -p 80:80 \
  -p 443:443 \
  -v ./data:/app/data \
  --name gocomicmosaic \
  gocomicmosaic:latest

### 使用Docker Compose管理应用

```bash
# 启动应用
docker-compose up -d

# 查看应用日志
docker-compose logs -f

# 停止应用
docker-compose down

# 重新构建并启动
docker-compose up -d --build

# 查看容器状态
docker-compose ps
```

## 环境变量

- `DB_PATH`: 数据库文件路径（默认：`/app/data/database.db`）
- `ASSETS_PATH`: 资源文件路径（默认：`/app/data/assets`）
- `DOMAIN`: 应用域名（默认：`localhost`）
- `TZ`: 时区设置（默认：`Asia/Shanghai`）

## 开发说明

### 前端开发

```bash
cd frontend
npm install
npm run dev
```

### 后端开发

```bash
cd gobackend
go mod tidy
go run ./cmd/api
```

如需启用HTTPS，需要在挂载目录中放置SSL证书：

1. 创建SSL证书目录：
   ```bash
   mkdir -p /your/local/path/ssl
   ```

2. 复制证书文件（必须使用这些文件名）：
   ```bash
   cp /path/to/your/fullchain.pem /your/local/path/ssl/
   cp /path/to/your/privkey.pem /your/local/path/ssl/
   ```


## 首页
![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/1.jpg)

## 详情页


点击「盘搜」按钮，一键搜索各种网盘资源

![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/pansou.gif)

点击「剧集探索」按钮，可以查看分季分集信息  
![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/30.gif)

可以一键生成分享海报和链接
![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/29.gif)

一键在线点播

![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/dianbo.gif)

也可以直接在`https://域名/streams`页面点播，支持采集解析和自定义爬虫

![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/streams.gif)



## 全面支持管理后台设置网站信息和采集解析源
目前美漫共建官网内置30条数据源  
![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/26.gif)

## 支持外挂在线播放数据源(自定义爬虫)
会写爬虫的用户可以自己添加数据源，更加灵活。参考[外接数据源开发者文档](https://github.com/fish2018/GoComicMosaic/blob/main/docs/%E5%A4%96%E6%8E%A5%E6%95%B0%E6%8D%AE%E6%BA%90%E5%BC%80%E5%8F%91%E6%96%87%E6%A1%A3.md)，提供[爬虫示例及模板](https://github.com/fish2018/GoComicMosaic/tree/main/docs/%E5%A4%96%E6%8E%A5%E6%95%B0%E6%8D%AE%E6%BA%90%E7%A4%BA%E4%BE%8B%E5%8F%8A%E6%A8%A1%E6%9D%BF)  
![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/27.gif)

## 提交资源
这个才是资源共建平台的核心，点击右上角的'提交资源'，用户可以随意提交自己喜欢的动漫资源，如果网站还不存该美漫时，会是一个新建资源的表单，需要填写中文名、英文名、类型、简介等基础信息。提交后，要等管理员在后台审批完才会在首页显示

### 提交-新建资源

支持从TMDB搜索、预览、一键导入资源
![image|690x397](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/28.gif)

### 提交-补充资源
顾名思义，就是对已经存在的动漫资源补充一些信息，主要是图片、资源链接
补充提交有2个入口，一个是右上角的'提交资源'，搜索已经存在的动漫名，然后选择确认即可
![image|690x396](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/10.jpg)  

![补充资源|690x392](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/11.gif)

从资源详情页点击'补充资源'按钮，不用自己再搜索选择了，自动绑定对应的动漫
![详情页补充|690x392](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/12.gif)

## 管理控制台
主要用于审批用户提交的资源

![image|690x398](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/14.jpg)

审批用户提交的资源
![后台审批|690x391](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/15.gif)

## 资源编辑(管理员权限)
管理员在动漫详情页面，可以进行编辑，修改中英文标题、简介、类型、图片增删、海报设置、修改添加资源链接等
![image|690x365](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/16.jpg)  
![image|690x303](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/17.jpg)  

![详情编辑|690x391](https://raw.githubusercontent.com/fishforks/imgs/refs/heads/main/gcm/18.gif)






