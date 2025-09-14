# Smart Paste URL 部署指南

## 远程服务器部署

### 1. 上传代码到服务器
```bash
# 压缩项目文件
tar -czf smart_paste_url.tar.gz server/ package*.json

# 上传到服务器
scp smart_paste_url.tar.gz user@104.225.151.25:/path/to/deployment/

# 在服务器上解压
ssh user@104.225.151.25
cd /path/to/deployment/
tar -xzf smart_paste_url.tar.gz
```

### 2. 服务器环境配置
```bash
# 安装依赖
cd server
npm install

# 设置环境变量（重要！）
export BASE_URL="http://104.225.151.25:34214"

# 启动服务
npm start
```

### 3. 使用PM2管理服务（推荐）
```bash
# 安装PM2
npm install -g pm2

# 启动服务
BASE_URL="http://104.225.151.25:34214" pm2 start server.js --name smart-paste-url

# 保存PM2配置
pm2 save
pm2 startup
```

### 4. 验证部署
```bash
# 检查健康状态
curl http://104.225.151.25:34214/health

# 应该返回：
# {"status":"ok","timestamp":"2024-01-01T00:00:00.000Z"}
```

## 当前问题诊断

### 问题现象
- 客户端显示上传成功，但返回 `http://localhost:34214/image/...` 
- 远程服务器 `http://104.225.151.25:34214` 返回502错误

### 解决方案
1. **确保远程服务器正在运行**：
   - 检查服务器上的Node.js进程
   - 确认端口34214正在监听
   - 检查防火墙设置

2. **设置正确的BASE_URL**：
   ```bash
   export BASE_URL="http://104.225.151.25:34214"
   node server.js
   ```

3. **重启远程服务**：
   ```bash
   # 停止旧进程
   pkill -f "node server.js"
   
   # 启动新版本
   BASE_URL="http://104.225.151.25:34214" node server.js
   ```

## 客户端配置验证

当前客户端配置文件 `client/config.json`：
```json
{
  "server_url": "http://104.225.151.25:34214",
  "check_interval": 1.0,
  "supported_formats": [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"],
  "max_file_size": 10485760
}
```

## 部署检查清单

- [ ] 远程服务器已更新到最新代码
- [ ] 设置了正确的BASE_URL环境变量
- [ ] 端口34214在服务器上可访问
- [ ] 防火墙允许34214端口
- [ ] 服务器进程正常运行
- [ ] 健康检查接口响应正常