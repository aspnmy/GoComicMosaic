# GoComicMosaicAV
一款开源影视资源共建平台，不同用户可以自由提交资源信息(标题、类型、简介、图片、资源链接)，像马赛克一样，由多方贡献拼凑成完整资源。 集成网盘搜索、分季分集剧集信息查看、在线点播(支持采集解析和自定义爬虫)等功能

# 集成了小姐姐搜刮器
方便搜刮更彻底
小姐姐搜刮器基于这个项目https://github.com/Yuukiy/JavSP.git

如果喜欢，点个star  

---

## Docker一键部署

```
docker run -d --name dongman \
  -p 80:80 -p 443:443 \
  -v /your/local/path:/app/data \
  -e DOMAIN=your-domain.com \
  2011820123/gcm:latest
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
勾选了小姐姐搜刮器，默认只从小姐姐搜刮器中搜索元素。如果同时存在正常资源和小姐姐，应该只在小姐姐资源中启用这个搜刮器
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


## 新增点播源汇总
管理员后台可以设置点播源汇总，汇总的json点播源可以被影视仓、TVBOX等各种空壳应用加载



