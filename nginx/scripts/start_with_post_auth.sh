#!/bin/bash

# 使用 OpenResty 启动支持 POST 鉴权的 Nginx

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 启动支持 POST 鉴权的 Nginx (OpenResty) ===${NC}"
echo ""

# 检查 Docker
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}错误: Docker未运行或无法访问${NC}"
    exit 1
fi

# 停止现有容器
if docker ps -a --format "{{.Names}}" | grep -q "^nginx-proxy$"; then
    echo -e "${YELLOW}停止现有容器...${NC}"
    docker stop nginx-proxy 2>/dev/null || true
    docker rm nginx-proxy 2>/dev/null || true
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}使用配置:${NC}"
echo "  配置文件: $NGINX_DIR/config/nginx_auth_request_post.conf"
echo "  鉴权服务: localhost:8888/auth/api_key"
echo "  后端服务: localhost:8000"
echo ""

# 启动容器
echo -e "${BLUE}启动 OpenResty 容器...${NC}"
docker run -d --name nginx-proxy \
  -p 80:80 \
  -v "$NGINX_DIR/config/nginx_auth_request_post.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro" \
  -v "$NGINX_DIR/config/proxy_with_auth.conf:/etc/nginx/proxy_with_auth.conf:ro" \
  -v "$NGINX_DIR/html:/usr/share/nginx/html:ro" \
  -v "$NGINX_DIR/logs:/var/log/nginx" \
  --restart unless-stopped \
  openresty/openresty:alpine

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 容器启动成功！${NC}"
    echo ""
    echo -e "${BLUE}容器信息:${NC}"
    echo "  容器名称: nginx-proxy"
    echo "  HTTP端口: 80"
    echo "  访问地址: http://localhost"
    echo ""
    echo -e "${YELLOW}测试命令:${NC}"
    echo "  curl http://localhost/health"
    echo "  curl -H 'Authorization: Bearer test-key' http://localhost/api/test"
    echo ""
    echo -e "${YELLOW}查看日志:${NC}"
    echo "  docker logs -f nginx-proxy"
else
    echo -e "${RED}❌ 容器启动失败${NC}"
    exit 1
fi
