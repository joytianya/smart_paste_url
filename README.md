# Smart Paste URL

🚀 智能图片上传服务 - 监控剪贴板自动上传图片，基于hash去重，一键分享

自动图片上传服务，监控剪贴板中的图片并上传到服务器，基于hash去重，自动将分享链接替换到剪贴板。

## 🎯 功能特性

- 🎯 **自动监控**：实时监控剪贴板中的图片变化
- 🔄 **智能去重**：基于MD5 hash避免重复上传相同图片
- 📋 **剪贴板集成**：自动将上传后的URL替换到剪贴板
- ⚡ **快速分享**：通过URL直接访问和分享图片
- 🌐 **HTTP API**：RESTful API支持多种客户端
- 💾 **持久存储**：SQLite数据库存储元数据
- 🛠️ **一键管理**：提供完整的管理脚本，支持启动、停止、状态查看
- 🔍 **健康检查**：内置系统健康检查和日志管理

## 系统架构

```
┌─────────────────┐         ┌──────────────────┐
│   客户端监控器    │  HTTP   │    服务器 API     │
│                 │ ──────> │                  │
│ 1. 监控剪贴板    │         │ 1. 接收上传       │
│ 2. 计算 MD5     │         │ 2. 检查 hash     │
│ 3. 上传图片      │ <────── │ 3. 存储图片       │
│ 4. 更新剪贴板    │  URL    │ 4. 返回 URL      │
└─────────────────┘         └──────────────────┘
```

## 🚀 快速开始

### 方式一：本地快速体验

使用管理脚本可以在本地快速启动服务：

```bash
# 克隆项目
git clone https://github.com/joytianya/smart_paste_url.git
cd smart_paste_url

# 一键启动所有服务（服务端 + 客户端）
./manage.sh start

# 查看服务状态
./manage.sh status
```

本地服务将在 `http://localhost:8886` 运行，客户端会自动连接到本地服务器。

### 方式二：生产环境部署（推荐）

如果你已经准备好**域名**和**服务器**，建议部署自己的服务：

#### 🔧 配置要求

**前提条件：**
- ✅ 拥有一个域名（如：`paste.yourdomain.com`）
- ✅ 一台服务器（VPS/云服务器）
- ✅ 域名已解析到服务器IP
- ✅ 服务器已安装Node.js 16+和Python 3.7+

#### 📋 一键部署步骤

**1. 服务器端部署**
```bash
# 在服务器上执行
git clone https://github.com/joytianya/smart_paste_url.git
cd smart_paste_url

# 安装依赖
./manage.sh install

# 配置服务端域名（重要）
cd server
# 编辑 server.js，修改第11行的 BASE_URL
# 将 https://smart-paste.matrixtools.me 改为你的域名
nano server.js  # 或使用 vim/其他编辑器

# 启动服务端
cd ..
./manage.sh start-server
```

**2. 配置域名和HTTPS**

使用Nginx配置反向代理和SSL证书：

```nginx
# /etc/nginx/sites-available/smart-paste
server {
    listen 80;
    server_name paste.yourdomain.com;  # 替换为你的域名
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name paste.yourdomain.com;  # 替换为你的域名

    # SSL 证书配置（使用 Let's Encrypt 或其他证书）
    ssl_certificate /path/to/your/certificate.pem;
    ssl_certificate_key /path/to/your/private.key;

    # 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_session_cache shared:SSL:10m;

    location / {
        proxy_pass http://localhost:8886;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 大文件上传支持
    client_max_body_size 10M;
}
```

```bash
# 启用站点并重启Nginx
sudo ln -s /etc/nginx/sites-available/smart-paste /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# 获取免费SSL证书（Let's Encrypt）
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d paste.yourdomain.com  # 替换为你的域名
```

**3. 客户端配置**

在任何需要使用的机器上：

```bash
# 克隆项目（如果还没有）
git clone https://github.com/joytianya/smart_paste_url.git
cd smart_paste_url

# 配置客户端连接到你的服务器
cd client
nano config.json  # 编辑配置文件
```

`client/config.json` 配置示例：
```json
{
  "server_url": "https://paste.yourdomain.com",  
  "check_interval": 1.0,
  "supported_formats": [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"],
  "max_file_size": 10485760
}
```

```bash
# 启动客户端
./manage.sh start-client
```

#### ⚡ 快速配置脚本

为了简化配置过程，我们提供了配置助手：

```bash
# 在项目根目录运行配置助手
./configure.sh
# 会提示输入域名并自动更新配置文件
```

#### 🔒 安全配置建议

**1. 防火墙配置**
```bash
# 开放必要端口
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS  
sudo ufw enable

# 确保8886端口仅本地访问（由Nginx代理）
sudo ufw deny 8886
```

**2. 系统服务配置**
```bash
# 创建systemd服务文件
sudo tee /etc/systemd/system/smart-paste-url.service > /dev/null <<EOF
[Unit]
Description=Smart Paste URL Service
After=network.target

[Service]
Type=simple
User=ubuntu  # 替换为你的用户名
WorkingDirectory=/path/to/smart_paste_url  # 替换为项目路径
ExecStart=/path/to/smart_paste_url/manage.sh start-server
ExecStop=/path/to/smart_paste_url/manage.sh stop-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable smart-paste-url
sudo systemctl start smart-paste-url
```

**3. 日志监控**
```bash
# 设置日志轮转
sudo tee /etc/logrotate.d/smart-paste-url > /dev/null <<EOF
/path/to/smart_paste_url/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 ubuntu ubuntu
}
EOF
```

> ⚠️ **重要提示：**
> - 确保服务端的 `BASE_URL` 和客户端的 `server_url` 完全一致
> - 建议使用HTTPS以确保数据传输安全
> - 定期备份上传的图片和数据库文件
> - 监控磁盘空间使用情况

### 手动启动方式

**启动客户端**
```bash
cd client
python3 start_client.py
# 或
pip3 install Pillow pyperclip requests
python3 monitor.py
```

**启动服务端**
```bash
cd server
npm install
npm start
```

### 使用方法

1. 复制任意图片到剪贴板
2. 客户端自动检测并上传到服务器
3. 剪贴板自动替换为分享链接
4. 粘贴链接即可分享图片

## 🛠️ 管理脚本使用

管理脚本 `manage.sh` 提供了完整的项目管理功能：

### 基本命令

```bash
./manage.sh help           # 显示帮助信息
./manage.sh start          # 启动所有服务
./manage.sh stop           # 停止所有服务
./manage.sh restart        # 重启所有服务
./manage.sh status         # 查看服务状态
```

### 单独管理

```bash
./manage.sh start-server   # 仅启动服务端
./manage.sh start-client   # 仅启动客户端
./manage.sh stop-server    # 仅停止服务端
./manage.sh stop-client    # 仅停止客户端
```

### 维护和监控

```bash
./manage.sh install        # 安装所有依赖
./manage.sh health         # 健康检查
./manage.sh logs-server    # 查看服务端日志
./manage.sh logs-client    # 查看客户端日志
```

## API 接口

### 上传图片
```
POST /upload
Content-Type: multipart/form-data

参数:
- image: 图片文件

返回:
{
  "success": true,
  "exists": false,
  "hash": "abc123...",
  "url": "http://localhost:3000/image/abc123",
  "message": "File uploaded successfully"
}
```

### 检查图片是否存在
```
GET /check/:hash

返回:
{
  "exists": true,
  "url": "http://localhost:3000/image/abc123",
  "filename": "abc123.png",
  "uploaded_at": "2024-01-01T00:00:00.000Z"
}
```

### 获取图片
```
GET /image/:hash

返回: 图片文件（二进制）
```

### 获取所有图片列表
```
GET /images

返回:
[
  {
    "hash": "abc123...",
    "original_name": "screenshot.png",
    "size": 12345,
    "uploaded_at": "2024-01-01T00:00:00.000Z",
    "url": "http://localhost:3000/image/abc123"
  }
]
```

## 配置

### 客户端配置 (`client/config.json`)

```json
{
  "server_url": "http://localhost:3000",
  "check_interval": 1.0,
  "supported_formats": [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"],
  "max_file_size": 10485760
}
```

### 服务器配置

- 端口：3000（可在 `server.js` 中修改）
- 上传目录：`server/uploads/`
- 数据库：`server/database.db`
- 文件大小限制：10MB

## 技术栈

### 服务端
- Node.js + Express
- SQLite3 数据库
- Multer 文件上传
- 内置 crypto 模块（MD5 hash）

### 客户端  
- Python 3
- Pillow (图片处理)
- pyperclip (剪贴板操作)
- requests (HTTP请求)

## 安全说明

- 支持的图片格式：PNG、JPG、JPEG、GIF、BMP、WebP
- 文件大小限制：10MB
- 基于MD5 hash的去重机制
- 自动缓存控制（1年）

## 故障排除

### 客户端无法连接服务器
1. 确认服务器正在运行
2. 检查防火墙设置
3. 确认端口3000未被占用

### 图片无法上传
1. 检查图片格式是否支持
2. 确认图片大小未超过10MB
3. 检查网络连接

### 剪贴板监控不工作
1. 确认系统权限（macOS需要授权访问剪贴板）
2. 检查Python依赖是否正确安装
3. 尝试手动复制图片测试

## 📦 部署方案

### 本地部署

**系统要求：**
- Node.js 16+ 
- Python 3.7+
- npm/pip

**一键部署：**
```bash
git clone <repository-url>
cd smart_paste_url
./manage.sh install  # 安装所有依赖
./manage.sh start     # 启动所有服务
```

### 生产环境部署

#### 服务器部署

**1. 环境准备**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nodejs npm python3 python3-pip

# CentOS/RHEL
sudo yum install nodejs npm python3 python3-pip
```

**2. 项目部署**
```bash
git clone <repository-url>
cd smart_paste_url

# 安装依赖
./manage.sh install

# 配置服务端
cd server
# 修改 server.js 中的端口配置（如需要）

# 启动服务
cd ..
./manage.sh start-server
```

**3. 配置反向代理（可选）**

Nginx 配置示例：
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 大文件上传支持
    client_max_body_size 10M;
}
```

**4. 系统服务配置**

创建 systemd 服务文件：
```bash
sudo tee /etc/systemd/system/smart-paste-url.service > /dev/null <<EOF
[Unit]
Description=Smart Paste URL Service
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$PWD
ExecStart=$PWD/manage.sh start
ExecStop=$PWD/manage.sh stop
ExecReload=$PWD/manage.sh restart
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable smart-paste-url
sudo systemctl start smart-paste-url
```

#### Docker 部署

**创建 Dockerfile：**
```dockerfile
FROM node:16-alpine

WORKDIR /app

# 安装 Python
RUN apk add --no-cache python3 py3-pip

# 复制项目文件
COPY . .

# 安装依赖
RUN cd server && npm install
RUN cd client && pip3 install -r requirements.txt

# 暴露端口
EXPOSE 3000

# 启动服务
CMD ["./manage.sh", "start"]
```

**构建和运行：**
```bash
docker build -t smart-paste-url .
docker run -d -p 3000:3000 --name smart-paste-url smart-paste-url
```

### 客户端部署

#### Windows 客户端

**1. 安装 Python 环境**
- 下载并安装 Python 3.7+
- 确保 pip 可用

**2. 配置客户端**
```bash
cd client
pip install -r requirements.txt

# 修改配置文件
# 编辑 config.json，设置正确的服务器地址
```

**3. 创建启动脚本**
```batch
@echo off
cd /d "%~dp0client"
python monitor.py
pause
```

#### macOS/Linux 客户端

**自动启动配置**
```bash
# 创建启动脚本
cat > ~/start-smart-paste.sh << 'EOF'
#!/bin/bash
cd /path/to/smart_paste_url
./manage.sh start-client
EOF

chmod +x ~/start-smart-paste.sh

# 添加到启动项（Linux）
echo "@/home/username/start-smart-paste.sh" >> ~/.config/lxsession/LXDE-pi/autostart

# 添加到启动项（macOS）
# 使用 LaunchAgent 或添加到登录项
```

### 配置优化

#### 服务端优化

**性能配置**
```javascript
// server.js 优化配置
const express = require('express');
const app = express();

// 增加请求体大小限制
app.use(express.json({limit: '10mb'}));

// 启用 gzip 压缩
const compression = require('compression');
app.use(compression());

// 设置缓存头
app.use('/image', express.static('uploads', {
  maxAge: '1y',
  etag: true
}));
```

#### 客户端配置

**config.json 优化**
```json
{
  "server_url": "https://your-domain.com",
  "check_interval": 0.5,
  "supported_formats": [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"],
  "max_file_size": 10485760,
  "retry_times": 3,
  "timeout": 30
}
```

### 监控和日志

**日志管理**
```bash
# 查看实时日志
./manage.sh logs-server
./manage.sh logs-client

# 日志轮转配置
sudo tee /etc/logrotate.d/smart-paste-url > /dev/null <<EOF
/path/to/smart_paste_url/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
}
EOF
```

**健康检查**
```bash
# 定期健康检查
./manage.sh health

# 添加到 crontab
echo "*/5 * * * * /path/to/smart_paste_url/manage.sh health >> /var/log/smart-paste-health.log 2>&1" | crontab -
```

## 🛠️ 开发指南

### 开发环境设置

```bash
# 克隆项目
git clone <repository-url>
cd smart_paste_url

# 安装依赖
./manage.sh install

# 启动开发模式
cd server && npm run dev &  # 服务端热重载
cd client && python monitor.py  # 客户端
```

### 项目结构

```
smart_paste_url/
├── manage.sh           # 一键管理脚本
├── README.md          # 项目文档
├── deploy.md          # 部署说明
├── server/            # 服务端
│   ├── server.js      # 主服务文件
│   ├── package.json   # 依赖配置
│   ├── uploads/       # 图片存储目录
│   └── database.db    # SQLite 数据库
├── client/            # 客户端
│   ├── monitor.py     # 主监控程序
│   ├── config.json    # 配置文件
│   ├── requirements.txt # Python 依赖
│   └── start_client.py # 启动脚本
└── logs/              # 日志目录
    ├── server.log     # 服务端日志
    └── client.log     # 客户端日志
```

### API 测试

```bash
# 测试服务器健康状态
curl http://localhost:3000/health

# 测试图片上传
curl -X POST -F "image=@test.png" http://localhost:3000/upload

# 查看已上传的图片
curl http://localhost:3000/images
```

### 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📝 License

MIT License - 详见 [LICENSE](LICENSE) 文件