#!/bin/bash

# 检查 Nginx 请求头的脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 检查 Nginx 请求头信息 ===${NC}"
echo ""

# 检查容器
if ! docker ps --format "{{.Names}}" | grep -q "^nginx-proxy$"; then
    echo -e "${RED}❌ Nginx容器未运行${NC}"
    exit 1
fi

echo -e "${BLUE}方法1: 使用调试端点（推荐）${NC}"
echo ""
echo -e "${YELLOW}测试调试端点 /debug/headers...${NC}"
echo ""

# 测试调试端点
RESPONSE=$(curl -s -H "Authorization: Bearer test-key" http://localhost/debug/headers 2>/dev/null)

if [ $? -eq 0 ] && echo "$RESPONSE" | grep -q "auth_info"; then
    echo -e "${GREEN}✅ 调试端点响应成功${NC}"
    echo ""
    echo -e "${BLUE}响应内容（格式化）：${NC}"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
else
    echo -e "${YELLOW}⚠️  调试端点可能未配置或需要认证${NC}"
    echo "响应: $RESPONSE"
fi

echo ""
echo -e "${BLUE}方法2: 查看日志文件${NC}"
echo ""

# 查看请求头日志
if docker exec nginx-proxy test -f /var/log/nginx/headers.log 2>/dev/null; then
    echo -e "${GREEN}✅ 找到请求头日志${NC}"
    echo ""
    echo -e "${YELLOW}最近的请求头日志（最后10行）：${NC}"
    docker exec nginx-proxy tail -10 /var/log/nginx/headers.log 2>/dev/null || echo "无法读取日志"
else
    echo -e "${YELLOW}⚠️  请求头日志文件不存在${NC}"
    echo "可能需要重新加载配置或重启容器"
fi

echo ""
echo -e "${BLUE}方法3: 查看错误日志（包含 Lua 调试信息）${NC}"
echo ""

if docker exec nginx-proxy test -f /var/log/nginx/error.log 2>/dev/null; then
    echo -e "${YELLOW}最近的错误日志（最后10行）：${NC}"
    docker exec nginx-proxy tail -10 /var/log/nginx/error.log 2>/dev/null | grep -i "auth\|header\|lua" || echo "无相关日志"
else
    echo -e "${YELLOW}⚠️  错误日志文件不存在${NC}"
fi

echo ""
echo -e "${BLUE}方法4: 使用后端服务查看请求头${NC}"
echo ""
echo -e "${YELLOW}如果后端服务有调试端点，可以查看实际收到的请求头：${NC}"
echo "  curl -H 'Authorization: Bearer test-key' http://localhost/api/debug/headers"
echo ""

echo -e "${BLUE}=== 如何查看转发给下游的请求头 ===${NC}"
echo ""
echo -e "${YELLOW}选项1: 使用 tcpdump 抓包${NC}"
echo "  docker exec nginx-proxy tcpdump -i any -A -s 0 'tcp port 8000'"
echo ""
echo -e "${YELLOW}选项2: 在后端服务中打印请求头${NC}"
echo "  在后端服务中添加日志，打印所有收到的请求头"
echo ""
echo -e "${YELLOW}选项3: 使用代理工具（如 mitmproxy）${NC}"
echo "  在 nginx 和后端服务之间添加代理，查看实际请求"
echo ""

echo -e "${BLUE}=== 快速测试命令 ===${NC}"
echo ""
echo "# 测试调试端点"
echo "curl -H 'Authorization: Bearer test-key' http://localhost/debug/headers | python3 -m json.tool"
echo ""
echo "# 查看请求头日志"
echo "docker exec nginx-proxy tail -f /var/log/nginx/headers.log"
echo ""
echo "# 查看所有日志"
echo "docker logs -f nginx-proxy"
