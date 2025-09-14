# Smart Paste URL

自动图片上传服务，监控剪贴板中的图片并上传到服务器，基于hash去重，自动将分享链接替换到剪贴板。

## 功能特性

- 🎯 **自动监控**：实时监控剪贴板中的图片变化
- 🔄 **智能去重**：基于MD5 hash避免重复上传相同图片
- 📋 **剪贴板集成**：自动将上传后的URL替换到剪贴板
- ⚡ **快速分享**：通过URL直接访问和分享图片
- 🌐 **HTTP API**：RESTful API支持多种客户端
- 💾 **持久存储**：SQLite数据库存储元数据

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

## 快速开始

### 远程服务器已部署 🎉

服务器已部署在：`http://104.225.151.25:34214`

- 健康检查: http://104.225.151.25:34214/health
- 上传接口: POST http://104.225.151.25:34214/upload
- 检查接口: GET http://104.225.151.25:34214/check/{hash}
- 图片接口: GET http://104.225.151.25:34214/image/{hash}

### 启动客户端

**方法1：使用启动脚本**
```bash
cd client
python3 start_client.py
```

**方法2：直接运行客户端**
```bash
cd client  
pip3 install Pillow pyperclip requests
python3 monitor.py
```

### 本地服务器部署（可选）

```bash
cd server
npm install
npm start
```

### 3. 使用方法

1. 复制任意图片到剪贴板
2. 客户端自动检测并上传到服务器
3. 剪贴板自动替换为分享链接
4. 粘贴链接即可分享图片

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

## 开发

### 启动开发模式

服务端：
```bash
cd server
npm install
npm run dev  # 使用 nodemon 自动重载
```

客户端：
```bash
cd client
pip install -r requirements.txt
python monitor.py
```

### 测试

```bash
# 测试服务器健康状态
curl http://localhost:3000/health

# 查看已上传的图片
curl http://localhost:3000/images
```

## License

MIT