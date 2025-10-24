#!/bin/bash

# 构建基于Ubuntu的Docker镜像脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
IMAGE_NAME="memsys-ubuntu"
TAG="v0.1.0"
DOCKERFILE="Dockerfile.ubuntu"

# 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -n, --name NAME       镜像名称 (默认: memsys-ubuntu)"
    echo "  -t, --tag TAG         镜像标签 (默认: latest)"
    echo "  -f, --file FILE       Dockerfile路径 (默认: Dockerfile.ubuntu)"
    echo "  --simple              使用简化版本 (Dockerfile.ubuntu.simple)"
    echo "  --no-cache            不使用构建缓存"
    echo "  --build-only          只构建，不运行"
    echo "  --run-only            只运行，不构建"
    echo "  -h, --help            显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  UV_INDEX_TANKA_USERNAME    Tanka仓库用户名"
    echo "  UV_INDEX_TANKA_PASSWORD    Tanka仓库密码"
    echo ""
    echo "示例:"
    echo "  $0                                    # 构建并运行"
    echo "  $0 --build-only                      # 只构建"
    echo "  $0 --run-only                        # 只运行"
    echo "  $0 --simple                          # 使用简化版本"
    echo "  $0 -n my-memsys -t v1.0             # 自定义名称和标签"
}

# 解析命令行参数
BUILD_ARGS=""
BUILD_ONLY=false
RUN_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -f|--file)
            DOCKERFILE="$2"
            shift 2
            ;;
        --simple)
            DOCKERFILE="Dockerfile.ubuntu.simple"
            shift
            ;;
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --run-only)
            RUN_ONLY=true
            shift
            ;;
        -h|--help)
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

FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker未安装或不在PATH中${NC}"
    exit 1
fi

# 检查Dockerfile是否存在
if [[ ! -f "$DOCKERFILE" ]]; then
    echo -e "${RED}错误: Dockerfile '$DOCKERFILE' 不存在${NC}"
    exit 1
fi

# 构建镜像
build_image() {
    echo -e "${BLUE}🔨 开始构建Docker镜像...${NC}"
    echo -e "${YELLOW}镜像名称: ${FULL_IMAGE_NAME}${NC}"
    echo -e "${YELLOW}Dockerfile: ${DOCKERFILE}${NC}"
    
    # 构建参数
    DOCKER_BUILD_ARGS=""
    
    # 添加Tanka仓库认证信息
    if [[ -n "$UV_INDEX_TANKA_USERNAME" ]]; then
        DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg UV_INDEX_TANKA_USERNAME=$UV_INDEX_TANKA_USERNAME"
    fi
    
    if [[ -n "$UV_INDEX_TANKA_PASSWORD" ]]; then
        DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg UV_INDEX_TANKA_PASSWORD=$UV_INDEX_TANKA_PASSWORD"
    fi
    
    # 执行构建 (使用项目根目录作为构建上下文)
    docker build \
        -f "$DOCKERFILE" \
        -t "$FULL_IMAGE_NAME" \
        $DOCKER_BUILD_ARGS \
        $BUILD_ARGS \
        ..
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ 镜像构建成功: ${FULL_IMAGE_NAME}${NC}"
    else
        echo -e "${RED}❌ 镜像构建失败${NC}"
        exit 1
    fi
}

# 运行容器
run_container() {
    echo -e "${BLUE}🚀 启动Docker容器...${NC}"
    
    # 检查镜像是否存在
    if ! docker image inspect "$FULL_IMAGE_NAME" &> /dev/null; then
        echo -e "${RED}错误: 镜像 '$FULL_IMAGE_NAME' 不存在，请先构建镜像${NC}"
        exit 1
    fi
    
    # 运行容器
    docker run \
        --rm \
        -it \
        -p 1995:1995 \
        --name "memsys-ubuntu-container" \
        "$FULL_IMAGE_NAME"
}

# 主逻辑
main() {
    echo -e "${GREEN}🐳 Memsys Ubuntu Docker 构建脚本${NC}"
    echo "================================"
    
    if [[ "$RUN_ONLY" == true ]]; then
        run_container
    elif [[ "$BUILD_ONLY" == true ]]; then
        build_image
    else
        build_image
        echo ""
        echo -e "${YELLOW}构建完成，是否立即运行容器? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            run_container
        else
            echo -e "${BLUE}💡 要运行容器，请使用: $0 --run-only${NC}"
        fi
    fi
}

# 执行主函数
main
