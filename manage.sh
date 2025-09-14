#!/bin/bash

# Smart Paste URL 一键管理脚本
# 用于启动、停止和管理服务端和客户端

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

# PID文件
SERVER_PID_FILE="$PROJECT_ROOT/.server.pid"
CLIENT_PID_FILE="$PROJECT_ROOT/.client.pid"

# 显示帮助信息
show_help() {
    echo -e "${CYAN}Smart Paste URL 管理脚本${NC}"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  ./manage.sh [命令]"
    echo ""
    echo -e "${YELLOW}可用命令:${NC}"
    echo -e "  ${GREEN}start-server${NC}    启动服务端"
    echo -e "  ${GREEN}start-client${NC}    启动客户端"
    echo -e "  ${GREEN}start${NC}           同时启动服务端和客户端"
    echo -e "  ${GREEN}stop-server${NC}     停止服务端"
    echo -e "  ${GREEN}stop-client${NC}     停止客户端"
    echo -e "  ${GREEN}stop${NC}            停止所有服务"
    echo -e "  ${GREEN}restart${NC}         重启所有服务"
    echo -e "  ${GREEN}status${NC}          查看服务状态"
    echo -e "  ${GREEN}logs-server${NC}     查看服务端日志"
    echo -e "  ${GREEN}logs-client${NC}     查看客户端日志"
    echo -e "  ${GREEN}install${NC}         安装依赖"
    echo -e "  ${GREEN}health${NC}          健康检查"
    echo -e "  ${GREEN}help${NC}            显示此帮助信息"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  ./manage.sh start          # 启动所有服务"
    echo "  ./manage.sh stop           # 停止所有服务"
    echo "  ./manage.sh status         # 查看状态"
}

# 检查进程是否运行
is_process_running() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# 启动服务端
start_server() {
    echo -e "${BLUE}启动服务端...${NC}"
    
    if is_process_running "$SERVER_PID_FILE"; then
        echo -e "${YELLOW}服务端已在运行中${NC}"
        return
    fi
    
    if [ ! -d "$SERVER_DIR" ]; then
        echo -e "${RED}错误: 服务端目录不存在: $SERVER_DIR${NC}"
        return 1
    fi
    
    cd "$SERVER_DIR"
    
    # 检查依赖
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}安装服务端依赖...${NC}"
        npm install
    fi
    
    # 启动服务端
    nohup npm start > "$PROJECT_ROOT/server.log" 2>&1 &
    echo $! > "$SERVER_PID_FILE"
    
    sleep 2
    
    if is_process_running "$SERVER_PID_FILE"; then
        echo -e "${GREEN}✓ 服务端启动成功 (PID: $(cat "$SERVER_PID_FILE"))${NC}"
    else
        echo -e "${RED}✗ 服务端启动失败${NC}"
        return 1
    fi
}

# 启动客户端
start_client() {
    echo -e "${BLUE}启动客户端...${NC}"
    
    if is_process_running "$CLIENT_PID_FILE"; then
        echo -e "${YELLOW}客户端已在运行中${NC}"
        return
    fi
    
    if [ ! -d "$CLIENT_DIR" ]; then
        echo -e "${RED}错误: 客户端目录不存在: $CLIENT_DIR${NC}"
        return 1
    fi
    
    cd "$CLIENT_DIR"
    
    # 检查Python环境
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}错误: 未找到python3${NC}"
        return 1
    fi
    
    # 安装依赖
    if [ -f "requirements.txt" ]; then
        echo -e "${YELLOW}检查客户端依赖...${NC}"
        if command -v pip3 &> /dev/null; then
            pip3 install -r requirements.txt --user > /dev/null 2>&1
        elif python3 -c "import pip" 2>/dev/null; then
            python3 -m pip install -r requirements.txt --user > /dev/null 2>&1
        fi
    fi
    
    # 启动客户端
    nohup python3 monitor.py > "$PROJECT_ROOT/client.log" 2>&1 &
    echo $! > "$CLIENT_PID_FILE"
    
    sleep 2
    
    if is_process_running "$CLIENT_PID_FILE"; then
        echo -e "${GREEN}✓ 客户端启动成功 (PID: $(cat "$CLIENT_PID_FILE"))${NC}"
    else
        echo -e "${RED}✗ 客户端启动失败${NC}"
        return 1
    fi
}

# 停止服务端
stop_server() {
    echo -e "${BLUE}停止服务端...${NC}"
    
    if is_process_running "$SERVER_PID_FILE"; then
        local pid=$(cat "$SERVER_PID_FILE")
        kill "$pid"
        rm -f "$SERVER_PID_FILE"
        echo -e "${GREEN}✓ 服务端已停止${NC}"
    else
        echo -e "${YELLOW}服务端未运行${NC}"
    fi
}

# 停止客户端
stop_client() {
    echo -e "${BLUE}停止客户端...${NC}"
    
    if is_process_running "$CLIENT_PID_FILE"; then
        local pid=$(cat "$CLIENT_PID_FILE")
        kill "$pid"
        rm -f "$CLIENT_PID_FILE"
        echo -e "${GREEN}✓ 客户端已停止${NC}"
    else
        echo -e "${YELLOW}客户端未运行${NC}"
    fi
}

# 查看服务状态
show_status() {
    echo -e "${CYAN}=== Smart Paste URL 服务状态 ===${NC}"
    echo ""
    
    echo -e "${BLUE}服务端状态:${NC}"
    if is_process_running "$SERVER_PID_FILE"; then
        local pid=$(cat "$SERVER_PID_FILE")
        echo -e "  状态: ${GREEN}运行中${NC} (PID: $pid)"
        echo -e "  端口: 3000"
        echo -e "  日志: $PROJECT_ROOT/server.log"
    else
        echo -e "  状态: ${RED}已停止${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}客户端状态:${NC}"
    if is_process_running "$CLIENT_PID_FILE"; then
        local pid=$(cat "$CLIENT_PID_FILE")
        echo -e "  状态: ${GREEN}运行中${NC} (PID: $pid)"
        echo -e "  配置: $CLIENT_DIR/config.json"
        echo -e "  日志: $PROJECT_ROOT/client.log"
    else
        echo -e "  状态: ${RED}已停止${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}系统信息:${NC}"
    echo -e "  项目目录: $PROJECT_ROOT"
    echo -e "  Python版本: $(python3 --version 2>/dev/null || echo '未找到')"
    echo -e "  Node.js版本: $(node --version 2>/dev/null || echo '未找到')"
}

# 安装依赖
install_deps() {
    echo -e "${BLUE}安装项目依赖...${NC}"
    
    # 安装服务端依赖
    if [ -d "$SERVER_DIR" ]; then
        echo -e "${YELLOW}安装服务端依赖...${NC}"
        cd "$SERVER_DIR"
        npm install
    fi
    
    # 安装客户端依赖
    if [ -d "$CLIENT_DIR" ] && [ -f "$CLIENT_DIR/requirements.txt" ]; then
        echo -e "${YELLOW}安装客户端依赖...${NC}"
        cd "$CLIENT_DIR"
        # 尝试使用 pip3，如果不存在则使用 python3 -m pip
        if command -v pip3 &> /dev/null; then
            pip3 install -r requirements.txt --user
        elif python3 -c "import pip" 2>/dev/null; then
            python3 -m pip install -r requirements.txt --user
        else
            echo -e "${YELLOW}pip 未安装，跳过客户端依赖安装${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
}

# 健康检查
health_check() {
    echo -e "${BLUE}执行健康检查...${NC}"
    
    # 检查服务端
    if is_process_running "$SERVER_PID_FILE"; then
        echo -e "${GREEN}✓ 服务端进程运行正常${NC}"
        
        # 检查HTTP接口
        if command -v curl &> /dev/null; then
            if curl -s http://localhost:3000/health > /dev/null; then
                echo -e "${GREEN}✓ 服务端API响应正常${NC}"
            else
                echo -e "${YELLOW}⚠ 服务端API无响应${NC}"
            fi
        fi
    else
        echo -e "${RED}✗ 服务端未运行${NC}"
    fi
    
    # 检查客户端
    if is_process_running "$CLIENT_PID_FILE"; then
        echo -e "${GREEN}✓ 客户端进程运行正常${NC}"
    else
        echo -e "${RED}✗ 客户端未运行${NC}"
    fi
    
    # 检查必要的命令
    echo ""
    echo -e "${BLUE}系统检查:${NC}"
    
    if command -v node &> /dev/null; then
        echo -e "${GREEN}✓ Node.js: $(node --version)${NC}"
    else
        echo -e "${RED}✗ Node.js 未安装${NC}"
    fi
    
    if command -v npm &> /dev/null; then
        echo -e "${GREEN}✓ npm: $(npm --version)${NC}"
    else
        echo -e "${RED}✗ npm 未安装${NC}"
    fi
    
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✓ Python3: $(python3 --version)${NC}"
    else
        echo -e "${RED}✗ Python3 未安装${NC}"
    fi
}

# 查看日志
show_server_logs() {
    if [ -f "$PROJECT_ROOT/server.log" ]; then
        tail -f "$PROJECT_ROOT/server.log"
    else
        echo -e "${YELLOW}服务端日志文件不存在${NC}"
    fi
}

show_client_logs() {
    if [ -f "$PROJECT_ROOT/client.log" ]; then
        tail -f "$PROJECT_ROOT/client.log"
    else
        echo -e "${YELLOW}客户端日志文件不存在${NC}"
    fi
}

# 主程序
case "${1:-help}" in
    "start-server")
        start_server
        ;;
    "start-client")
        start_client
        ;;
    "start")
        start_server
        sleep 1
        start_client
        echo ""
        show_status
        ;;
    "stop-server")
        stop_server
        ;;
    "stop-client")
        stop_client
        ;;
    "stop")
        stop_server
        stop_client
        ;;
    "restart")
        echo -e "${BLUE}重启所有服务...${NC}"
        stop_server
        stop_client
        sleep 2
        start_server
        sleep 1
        start_client
        echo ""
        show_status
        ;;
    "status")
        show_status
        ;;
    "logs-server")
        show_server_logs
        ;;
    "logs-client")
        show_client_logs
        ;;
    "install")
        install_deps
        ;;
    "health")
        health_check
        ;;
    "help"|*)
        show_help
        ;;
esac