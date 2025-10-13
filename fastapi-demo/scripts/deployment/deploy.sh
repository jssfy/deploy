#!/bin/bash
# 双服务监控系统部署脚本

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

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 检查配置文件
check_configs() {
    log_info "检查配置文件..."
    
    local config_files=(
        "docker-compose.yml"
        "configs/prometheus_config.yml"
        "configs/alert_rules.yml"
        "configs/Dockerfile"
        "configs/requirements_monitoring.txt"
    )
    
    for file in "${config_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "配置文件不存在: $file"
            exit 1
        fi
    done
    
    log_success "配置文件检查通过"
}

# 构建应用镜像
build_app() {
    log_info "构建应用镜像..."
    
    if docker build -t fastapi-demo-app -f configs/Dockerfile .; then
        log_success "应用镜像构建成功"
    else
        log_error "应用镜像构建失败"
        exit 1
    fi
}

# 启动服务
start_services() {
    log_info "启动监控服务..."
    
    if docker-compose up -d; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        exit 1
    fi
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    local services=(
        "app:38000"
        "prometheus:9090"
        "grafana:3000"
    )
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        log_info "等待 $name 服务启动..."
        
        local max_attempts=30
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if docker-compose exec $name curl -f http://localhost:$port/health 2>/dev/null || \
               docker-compose exec $name curl -f http://localhost:$port/api/health 2>/dev/null || \
               docker-compose exec $name curl -f http://localhost:$port 2>/dev/null; then
                log_success "$name 服务已就绪"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "$name 服务启动超时"
                exit 1
            fi
            
            sleep 2
            ((attempt++))
        done
    done
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    # 检查容器状态
    if docker-compose ps | grep -q "Up"; then
        log_success "所有容器运行正常"
    else
        log_error "部分容器未正常运行"
        docker-compose ps
        exit 1
    fi
    
    # 检查Prometheus目标
    sleep 5
    if curl -s http://localhost:9090/api/v1/targets | grep -q "up"; then
        log_success "Prometheus目标监控正常"
    else
        log_warning "Prometheus目标监控异常"
    fi
    
    # 检查Grafana
    if curl -s http://localhost:3000/api/health | grep -q "ok"; then
        log_success "Grafana服务正常"
    else
        log_warning "Grafana服务异常"
    fi
}

# 显示访问信息
show_access_info() {
    log_success "部署完成！"
    echo ""
    echo "🌐 服务访问地址："
    echo "  应用服务:     http://localhost:38000"
    echo "  API文档:      http://localhost:38000/docs"
    echo "  健康检查:     http://localhost:38000/health"
    echo "  监控指标:     http://localhost:38000/metrics"
    echo ""
    echo "📊 监控服务："
    echo "  Prometheus:   http://localhost:9090"
    echo "  Grafana:      http://localhost:3000 (admin/admin)"
    echo ""
    echo "🔧 管理命令："
    echo "  查看状态:     docker-compose ps"
    echo "  查看日志:     docker-compose logs -f"
    echo "  停止服务:     docker-compose stop"
    echo "  重启服务:     docker-compose restart"
    echo ""
    echo "📚 文档位置："
    echo "  快速开始:     docs/QUICK_START.md"
    echo "  监控指南:     docs/MONITORING_GUIDE.md"
    echo "  设计文档:     docs/monitoring_design.md"
}

# 主函数
main() {
    echo "🚀 双服务监控系统部署脚本"
    echo "=========================="
    
    # 切换到脚本目录的父目录
    cd "$(dirname "$0")/../.."
    
    check_dependencies
    check_configs
    build_app
    start_services
    wait_for_services
    verify_deployment
    show_access_info
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"
