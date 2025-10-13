#!/bin/bash
# 双服务监控系统卸载脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "双服务监控系统卸载脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --volumes  同时删除数据卷（会丢失所有数据）"
    echo "  -i, --images   同时删除Docker镜像"
    echo "  -a, --all      完全清理（包括数据卷和镜像）"
    echo ""
    echo "示例:"
    echo "  $0              # 只停止和删除容器"
    echo "  $0 -v           # 删除容器和数据卷"
    echo "  $0 -a           # 完全清理"
}

# 停止服务
stop_services() {
    log_info "停止监控服务..."
    
    if docker-compose down; then
        log_success "服务已停止"
    else
        log_warning "停止服务时出现警告"
    fi
}

# 删除数据卷
remove_volumes() {
    log_info "删除数据卷..."
    
    local volumes=(
        "fastapi-demo_prometheus_data"
        "fastapi-demo_grafana_data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            if docker volume rm "$volume"; then
                log_success "数据卷 $volume 已删除"
            else
                log_error "删除数据卷 $volume 失败"
            fi
        else
            log_info "数据卷 $volume 不存在"
        fi
    done
}

# 删除镜像
remove_images() {
    log_info "删除Docker镜像..."
    
    local images=(
        "fastapi-demo-app"
        "prom/prometheus:latest"
        "grafana/grafana:latest"
    )
    
    for image in "${images[@]}"; do
        if docker images | grep -q "$image"; then
            if docker rmi "$image"; then
                log_success "镜像 $image 已删除"
            else
                log_warning "删除镜像 $image 失败（可能正在使用）"
            fi
        else
            log_info "镜像 $image 不存在"
        fi
    done
}

# 清理未使用的资源
cleanup_unused() {
    log_info "清理未使用的Docker资源..."
    
    # 清理未使用的容器
    if docker container prune -f; then
        log_success "未使用的容器已清理"
    fi
    
    # 清理未使用的网络
    if docker network prune -f; then
        log_success "未使用的网络已清理"
    fi
    
    # 清理未使用的镜像
    if docker image prune -f; then
        log_success "未使用的镜像已清理"
    fi
}

# 显示清理结果
show_cleanup_result() {
    log_success "清理完成！"
    echo ""
    echo "📊 清理结果："
    echo "  容器: 已停止并删除"
    echo "  网络: 已删除"
    
    if [[ "$REMOVE_VOLUMES" == "true" ]]; then
        echo "  数据卷: 已删除（数据已丢失）"
    else
        echo "  数据卷: 已保留"
    fi
    
    if [[ "$REMOVE_IMAGES" == "true" ]]; then
        echo "  镜像: 已删除"
    else
        echo "  镜像: 已保留"
    fi
    
    echo ""
    echo "💡 提示："
    echo "  - 如需重新部署，请运行 scripts/deployment/deploy.sh"
    echo "  - 如需完全清理，请使用 -a 参数"
    echo "  - 数据卷包含所有监控数据，删除后无法恢复"
}

# 主函数
main() {
    local REMOVE_VOLUMES=false
    local REMOVE_IMAGES=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--volumes)
                REMOVE_VOLUMES=true
                shift
                ;;
            -i|--images)
                REMOVE_IMAGES=true
                shift
                ;;
            -a|--all)
                REMOVE_VOLUMES=true
                REMOVE_IMAGES=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "🧹 双服务监控系统卸载脚本"
    echo "=========================="
    
    # 切换到脚本目录的父目录
    cd "$(dirname "$0")/../.."
    
    # 确认操作
    if [[ "$REMOVE_VOLUMES" == "true" ]]; then
        echo ""
        log_warning "⚠️  警告: 将删除所有监控数据！"
        read -p "确认继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
    
    stop_services
    
    if [[ "$REMOVE_VOLUMES" == "true" ]]; then
        remove_volumes
    fi
    
    if [[ "$REMOVE_IMAGES" == "true" ]]; then
        remove_images
    fi
    
    cleanup_unused
    show_cleanup_result
}

# 错误处理
trap 'log_error "卸载过程中发生错误"; exit 1' ERR

# 执行主函数
main "$@"
