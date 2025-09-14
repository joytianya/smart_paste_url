#!/bin/bash

# Smart Paste URL 配置助手
# 帮助用户快速配置服务端和客户端的域名设置

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$PROJECT_ROOT/server"
CLIENT_DIR="$PROJECT_ROOT/client"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}    Smart Paste URL 配置助手${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 检查必要文件是否存在
check_files() {
    local missing_files=()
    
    if [ ! -f "$SERVER_DIR/server.js" ]; then
        missing_files+=("server/server.js")
    fi
    
    if [ ! -f "$CLIENT_DIR/config.json" ]; then
        missing_files+=("client/config.json")
    fi
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}✗ 缺少必要文件:${NC}"
        for file in "${missing_files[@]}"; do
            echo -e "  - $file"
        done
        echo ""
        echo -e "${YELLOW}请确保在项目根目录运行此脚本${NC}"
        exit 1
    fi
}

# 显示当前配置
show_current_config() {
    echo -e "${BLUE}📋 当前配置:${NC}"
    echo ""
    
    # 服务端配置
    if [ -f "$SERVER_DIR/server.js" ]; then
        local server_url=$(grep "const baseUrl" "$SERVER_DIR/server.js" | sed -n "s/.*process\.env\.BASE_URL || \`\(.*\)\`/\1/p")
        if [ -z "$server_url" ]; then
            server_url=$(grep "const baseUrl" "$SERVER_DIR/server.js" | sed -n 's/.*`\(.*\)`/\1/p')
        fi
        echo -e "  ${GREEN}服务端域名:${NC} $server_url"
    fi
    
    # 客户端配置
    if [ -f "$CLIENT_DIR/config.json" ]; then
        local client_url=$(grep '"server_url"' "$CLIENT_DIR/config.json" | sed 's/.*"server_url": *"\([^"]*\)".*/\1/')
        echo -e "  ${GREEN}客户端服务器:${NC} $client_url"
    fi
    
    echo ""
}

# 获取用户输入的域名
get_domain() {
    echo -e "${YELLOW}🌐 请输入你的域名配置:${NC}"
    echo ""
    echo -e "示例格式:"
    echo -e "  - https://paste.yourdomain.com"
    echo -e "  - https://img.example.org"
    echo -e "  - http://localhost:8886 (仅用于本地测试)"
    echo ""
    
    while true; do
        read -p "请输入完整的域名 (包括 http:// 或 https://): " domain
        
        # 验证域名格式
        if [[ $domain =~ ^https?://[a-zA-Z0-9.-]+([:/][a-zA-Z0-9.-]*)?$ ]]; then
            echo -e "${GREEN}✓ 域名格式正确: $domain${NC}"
            break
        else
            echo -e "${RED}✗ 域名格式错误，请重新输入${NC}"
            echo -e "${YELLOW}正确格式: https://your-domain.com${NC}"
        fi
    done
    
    DOMAIN="$domain"
}

# 更新服务端配置
update_server_config() {
    echo -e "${BLUE}🔧 更新服务端配置...${NC}"
    
    local server_file="$SERVER_DIR/server.js"
    local backup_file="$server_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 创建备份
    cp "$server_file" "$backup_file"
    echo -e "${YELLOW}  已创建备份: $(basename $backup_file)${NC}"
    
    # 更新BASE_URL
    if grep -q "const baseUrl.*process.env.BASE_URL" "$server_file"; then
        # 替换包含环境变量的行
        sed -i "s|const baseUrl = process.env.BASE_URL.*|const baseUrl = process.env.BASE_URL \|\| \`$DOMAIN\`;|" "$server_file"
    else
        # 替换简单的baseUrl行
        sed -i "s|const baseUrl = .*|const baseUrl = \`$DOMAIN\`;|" "$server_file"
    fi
    
    echo -e "${GREEN}  ✓ 服务端域名已更新为: $DOMAIN${NC}"
}

# 更新客户端配置
update_client_config() {
    echo -e "${BLUE}🔧 更新客户端配置...${NC}"
    
    local config_file="$CLIENT_DIR/config.json"
    local backup_file="$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 创建备份
    cp "$config_file" "$backup_file"
    echo -e "${YELLOW}  已创建备份: $(basename $backup_file)${NC}"
    
    # 更新server_url
    sed -i "s|\"server_url\": *\"[^\"]*\"|\"server_url\": \"$DOMAIN\"|" "$config_file"
    
    echo -e "${GREEN}  ✓ 客户端服务器地址已更新为: $DOMAIN${NC}"
}

# 验证配置
verify_config() {
    echo -e "${BLUE}🔍 验证配置...${NC}"
    
    # 检查服务端配置
    local server_url=$(grep "const baseUrl" "$SERVER_DIR/server.js" | sed -n 's/.*`\(.*\)`/\1/p')
    
    # 检查客户端配置  
    local client_url=$(grep '"server_url"' "$CLIENT_DIR/config.json" | sed 's/.*"server_url": *"\([^"]*\)".*/\1/')
    
    if [ "$server_url" = "$DOMAIN" ] && [ "$client_url" = "$DOMAIN" ]; then
        echo -e "${GREEN}  ✓ 配置验证成功！服务端和客户端域名一致${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 配置验证失败${NC}"
        echo -e "    服务端: $server_url"
        echo -e "    客户端: $client_url"
        echo -e "    预期: $DOMAIN"
        return 1
    fi
}

# 生成Nginx配置
generate_nginx_config() {
    echo ""
    echo -e "${BLUE}📝 生成Nginx配置建议:${NC}"
    echo ""
    
    # 从域名中提取hostname
    local hostname=$(echo "$DOMAIN" | sed 's|https\?://||' | sed 's|/.*||')
    local is_https=$(echo "$DOMAIN" | grep -q "^https" && echo "true" || echo "false")
    
    echo -e "${YELLOW}建议的Nginx配置 (/etc/nginx/sites-available/smart-paste):${NC}"
    echo ""
    
    if [ "$is_https" = "true" ]; then
        cat << EOF
server {
    listen 80;
    server_name $hostname;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $hostname;

    # SSL 证书配置
    ssl_certificate /etc/letsencrypt/live/$hostname/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$hostname/privkey.pem;

    # 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_session_cache shared:SSL:10m;

    location / {
        proxy_pass http://localhost:8886;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    client_max_body_size 10M;
}
EOF
    else
        cat << EOF
server {
    listen 80;
    server_name $hostname;

    location / {
        proxy_pass http://localhost:8886;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    client_max_body_size 10M;
}
EOF
    fi
    
    echo ""
    echo -e "${YELLOW}SSL证书获取建议 (如使用HTTPS):${NC}"
    echo "sudo certbot --nginx -d $hostname"
}

# 显示后续步骤
show_next_steps() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           配置完成！${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}📋 后续步骤:${NC}"
    echo ""
    echo -e "${YELLOW}1. 启动服务端:${NC}"
    echo "   ./manage.sh start-server"
    echo ""
    echo -e "${YELLOW}2. 配置Nginx (如果使用):${NC}"
    echo "   sudo nano /etc/nginx/sites-available/smart-paste"
    echo "   sudo ln -s /etc/nginx/sites-available/smart-paste /etc/nginx/sites-enabled/"
    echo "   sudo nginx -t && sudo systemctl restart nginx"
    echo ""
    echo -e "${YELLOW}3. 启动客户端:${NC}"
    echo "   ./manage.sh start-client"
    echo ""
    echo -e "${YELLOW}4. 测试服务:${NC}"
    echo "   curl $DOMAIN/health"
    echo ""
    echo -e "${GREEN}🎉 现在可以复制图片到剪贴板测试功能了！${NC}"
}

# 主程序
main() {
    check_files
    show_current_config
    
    echo -e "${YELLOW}是否要更新域名配置? (y/N):${NC}"
    read -p "" confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        get_domain
        echo ""
        
        update_server_config
        update_client_config
        echo ""
        
        if verify_config; then
            if [[ $DOMAIN =~ ^https:// ]]; then
                generate_nginx_config
            fi
            show_next_steps
        else
            echo -e "${RED}配置失败，请检查文件权限或手动配置${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}配置未更改${NC}"
        echo ""
        echo -e "${YELLOW}如需手动配置:${NC}"
        echo -e "  服务端: 编辑 $SERVER_DIR/server.js"
        echo -e "  客户端: 编辑 $CLIENT_DIR/config.json"
    fi
}

# 运行主程序
main "$@"