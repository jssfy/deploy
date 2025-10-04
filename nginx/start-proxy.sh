#!/bin/bash

# 简化版Nginx代理启动脚本
# 使用现有配置文件启动代理容器

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
CONTAINER_NAME="nginx-proxy"
HOST_PORT=80
CONTAINER_PORT=80
CONFIG_DIR="./config"
HTML_DIR="./html"
LOGS_DIR="./logs"
HOST_NETWORK=false

# 显示帮助信息
show_help() {
    echo -e "${BLUE}简化版Nginx代理启动脚本${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -n, --name NAME        容器名称 (默认: nginx-proxy)"
    echo "  -p, --port PORT        主机端口 (默认: 80)"
    echo "  -d, --detach           后台运行容器"
    echo "  -f, --force            强制重新创建容器"
    echo "  --host-network         使用host网络模式"
    echo "  --help                 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -d"
    echo "  $0 -n my-proxy -p 8080 -d"
}

# 解析命令行参数
parse_args() {
    DETACH_MODE=false
    FORCE_RECREATE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            -p|--port)
                HOST_PORT="$2"
                shift 2
                ;;
            -d|--detach)
                DETACH_MODE=true
                shift
                ;;
            -f|--force)
                FORCE_RECREATE=true
                shift
                ;;
            --host-network)
                HOST_NETWORK=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知参数 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查Docker
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}错误: Docker未运行或无法访问${NC}"
        exit 1
    fi
}

# 检查配置文件
check_config_files() {
    echo -e "${BLUE}检查配置文件...${NC}"
    
    if [ ! -f "$CONFIG_DIR/nginx.conf" ]; then
        echo -e "${RED}❌ 配置文件不存在: $CONFIG_DIR/nginx.conf${NC}"
        echo "请先创建配置文件或使用 start-nginx-proxy.sh --create-config"
        exit 1
    fi
    
    if [ ! -f "$CONFIG_DIR/proxy.conf" ]; then
        echo -e "${RED}❌ 代理配置文件不存在: $CONFIG_DIR/proxy.conf${NC}"
        echo "请先创建配置文件或使用 start-nginx-proxy.sh --create-config"
        exit 1
    fi
    
    # 检查SSL证书文件
    if [ ! -f "$CONFIG_DIR/19720390_www.yeanhua.asia_nginx/www.yeanhua.asia.pem" ]; then
        echo -e "${RED}❌ SSL证书文件不存在: $CONFIG_DIR/19720390_www.yeanhua.asia_nginx/www.yeanhua.asia.pem${NC}"
        exit 1
    fi
    
    if [ ! -f "$CONFIG_DIR/19720390_www.yeanhua.asia_nginx/www.yeanhua.asia.key" ]; then
        echo -e "${RED}❌ SSL私钥文件不存在: $CONFIG_DIR/19720390_www.yeanhua.asia_nginx/www.yeanhua.asia.key${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 配置文件检查通过${NC}"
    echo "  nginx.conf: $CONFIG_DIR/nginx.conf"
    echo "  proxy.conf: $CONFIG_DIR/proxy.conf"
    echo "  SSL证书: $CONFIG_DIR/19720390_www.yeanhua.asia_nginx/"
}

# 检查端口
check_port() {
    if netstat -tuln | grep -q ":$HOST_PORT "; then
        echo -e "${YELLOW}警告: 端口 $HOST_PORT 已被占用${NC}"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 创建目录
create_directories() {
    mkdir -p "$HTML_DIR"
    mkdir -p "$LOGS_DIR"
}

# 停止现有容器
stop_existing_container() {
    if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo -e "${YELLOW}发现现有容器: $CONTAINER_NAME${NC}"
        
        if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
            echo -e "${BLUE}停止容器: $CONTAINER_NAME${NC}"
            docker stop "$CONTAINER_NAME"
        fi
        
        echo -e "${BLUE}删除容器: $CONTAINER_NAME${NC}"
        docker rm "$CONTAINER_NAME"
    fi
}

# 启动容器
start_container() {
    echo -e "${BLUE}启动Nginx代理容器...${NC}"
    
    # 构建docker run命令
    DOCKER_CMD="docker run"
    
    if [ "$DETACH_MODE" = true ]; then
        DOCKER_CMD="$DOCKER_CMD -d"
    else
        DOCKER_CMD="$DOCKER_CMD -it"
    fi
    
    DOCKER_CMD="$DOCKER_CMD --name $CONTAINER_NAME"
    
    if [ "$HOST_NETWORK" = true ]; then
        DOCKER_CMD="$DOCKER_CMD --network host"
    else
        DOCKER_CMD="$DOCKER_CMD -p $HOST_PORT:$CONTAINER_PORT"
        DOCKER_CMD="$DOCKER_CMD -p 443:443"
    fi
    DOCKER_CMD="$DOCKER_CMD -v $(pwd)/$CONFIG_DIR/nginx.conf:/etc/nginx/nginx.conf:ro"
    DOCKER_CMD="$DOCKER_CMD -v $(pwd)/$CONFIG_DIR/proxy.conf:/etc/nginx/proxy.conf:ro"
    DOCKER_CMD="$DOCKER_CMD -v $(pwd)/$CONFIG_DIR/19720390_www.yeanhua.asia_nginx:/etc/nginx/ssl:ro"
    DOCKER_CMD="$DOCKER_CMD -v $(pwd)/$HTML_DIR:/usr/share/nginx/html:ro"
    DOCKER_CMD="$DOCKER_CMD -v $(pwd)/$LOGS_DIR:/var/log/nginx"
    DOCKER_CMD="$DOCKER_CMD --restart unless-stopped"
    DOCKER_CMD="$DOCKER_CMD nginx:1.23.2"
    
    echo -e "${BLUE}执行命令: $DOCKER_CMD${NC}"
    eval "$DOCKER_CMD"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Nginx代理容器启动成功！${NC}"
        echo ""
        echo -e "${BLUE}📋 容器信息:${NC}"
        echo "  容器名称: $CONTAINER_NAME"
        if [ "$HOST_NETWORK" = true ]; then
            echo "  网络模式: host"
            echo "  访问地址: http://localhost"
            echo "  HTTPS地址: https://localhost"
        else
            echo "  HTTP端口: $HOST_PORT"
            echo "  HTTPS端口: 443"
            echo "  访问地址: http://localhost:$HOST_PORT"
            echo "  HTTPS地址: https://localhost"
        fi
        echo ""
        
        if [ "$DETACH_MODE" = true ]; then
            echo -e "${YELLOW}💡 容器在后台运行，使用以下命令查看日志:${NC}"
            echo "  docker logs $CONTAINER_NAME"
            echo ""
            echo -e "${YELLOW}💡 停止容器:${NC}"
            echo "  docker stop $CONTAINER_NAME"
        fi
        
        echo -e "${YELLOW}💡 测试代理:${NC}"
        echo "  curl http://localhost:$HOST_PORT/health"
        echo "  curl https://localhost/health"
        echo "  curl http://localhost:$HOST_PORT/proxy-status"
        echo "  curl https://localhost/proxy-status"
    else
        echo -e "${RED}❌ 容器启动失败${NC}"
        exit 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}=== 简化版Nginx代理启动脚本 ===${NC}"
    echo ""
    
    # 解析命令行参数
    parse_args "$@"
    
    # 检查Docker
    check_docker
    
    # 检查配置文件
    check_config_files
    
    # 检查端口
    check_port
    
    # 创建目录
    create_directories
    
    # 如果需要强制重新创建或容器已存在，则停止现有容器
    if [ "$FORCE_RECREATE" = true ] || docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        stop_existing_container
    fi
    
    # 启动容器
    start_container
}

# 执行主函数
main "$@"


