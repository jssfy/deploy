#!/bin/bash
# 监控系统状态检查脚本

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

# 检查服务状态
check_service_status() {
    log_info "检查服务状态..."
    
    local services=(
        "app:38000:应用服务"
        "prometheus:9090:Prometheus"
        "grafana:3000:Grafana"
    )
    
    echo ""
    echo "📊 服务状态:"
    echo "============"
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        local desc=$(echo $service | cut -d: -f3)
        
        if docker-compose ps | grep -q "$name.*Up"; then
            log_success "$desc ($name) - 运行中"
        else
            log_error "$desc ($name) - 未运行"
        fi
    done
}

# 检查Prometheus目标
check_prometheus_targets() {
    log_info "检查Prometheus监控目标..."
    
    echo ""
    echo "🎯 Prometheus监控目标:"
    echo "====================="
    
    if curl -s http://localhost:9090/api/v1/targets > /dev/null 2>&1; then
        local targets=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job) (\(.labels.instance)) - \(.health)"' 2>/dev/null || echo "无法解析目标数据")
        
        if [[ -n "$targets" ]]; then
            echo "$targets" | while read -r line; do
                if [[ "$line" == *"up"* ]]; then
                    log_success "$line"
                else
                    log_error "$line"
                fi
            done
        else
            log_warning "未找到监控目标"
        fi
    else
        log_error "无法连接到Prometheus"
    fi
}

# 检查指标数据
check_metrics() {
    log_info "检查指标数据..."
    
    echo ""
    echo "📈 关键指标:"
    echo "============"
    
    # 检查HTTP请求总数
    local http_requests=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq -r '.data.result | length' 2>/dev/null || echo "0")
    if [[ "$http_requests" -gt 0 ]]; then
        log_success "HTTP请求指标: $http_requests 个时间序列"
    else
        log_warning "HTTP请求指标: 无数据"
    fi
    
    # 检查消息消费指标
    local messages=$(curl -s "http://localhost:9090/api/v1/query?query=messages_consumed_total" | jq -r '.data.result | length' 2>/dev/null || echo "0")
    if [[ "$messages" -gt 0 ]]; then
        log_success "消息消费指标: $messages 个时间序列"
    else
        log_warning "消息消费指标: 无数据"
    fi
    
    # 检查队列深度
    local queue_depth=$(curl -s "http://localhost:9090/api/v1/query?query=queue_depth" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    if [[ "$queue_depth" != "N/A" ]]; then
        log_success "队列深度: $queue_depth"
    else
        log_warning "队列深度: 无数据"
    fi
}

# 检查系统资源
check_system_resources() {
    log_info "检查系统资源..."
    
    echo ""
    echo "💻 系统资源:"
    echo "============"
    
    # 检查Docker容器资源使用
    if command -v docker &> /dev/null; then
        local container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep fastapi-demo || echo "无数据")
        if [[ "$container_stats" != "无数据" ]]; then
            echo "$container_stats"
        else
            log_warning "无法获取容器资源使用情况"
        fi
    fi
    
    # 检查磁盘使用
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ "$disk_usage" -lt 80 ]]; then
        log_success "磁盘使用率: ${disk_usage}%"
    else
        log_warning "磁盘使用率: ${disk_usage}% (较高)"
    fi
}

# 检查数据卷
check_volumes() {
    log_info "检查数据卷..."
    
    echo ""
    echo "💾 数据卷状态:"
    echo "============="
    
    local volumes=(
        "fastapi-demo_prometheus_data"
        "fastapi-demo_grafana_data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            local size=$(docker system df -v | grep "$volume" | awk '{print $3}' 2>/dev/null || echo "未知")
            log_success "$volume: 存在 (大小: $size)"
        else
            log_warning "$volume: 不存在"
        fi
    done
}

# 生成健康报告
generate_health_report() {
    log_info "生成健康报告..."
    
    echo ""
    echo "📋 健康报告摘要:"
    echo "================"
    
    local healthy_services=0
    local total_services=3
    
    # 检查服务健康状态
    if docker-compose ps | grep -q "app.*Up"; then
        ((healthy_services++))
    fi
    if docker-compose ps | grep -q "prometheus.*Up"; then
        ((healthy_services++))
    fi
    if docker-compose ps | grep -q "grafana.*Up"; then
        ((healthy_services++))
    fi
    
    local health_percentage=$((healthy_services * 100 / total_services))
    
    if [[ $health_percentage -eq 100 ]]; then
        log_success "系统健康度: $health_percentage% (优秀)"
    elif [[ $health_percentage -ge 66 ]]; then
        log_warning "系统健康度: $health_percentage% (良好)"
    else
        log_error "系统健康度: $health_percentage% (需要关注)"
    fi
    
    echo "  运行服务: $healthy_services/$total_services"
    echo "  检查时间: $(date)"
}

# 主函数
main() {
    echo "🔍 双服务监控系统状态检查"
    echo "=========================="
    
    # 切换到脚本目录的父目录
    cd "$(dirname "$0")/../.."
    
    check_service_status
    check_prometheus_targets
    check_metrics
    check_system_resources
    check_volumes
    generate_health_report
    
    echo ""
    echo "🌐 快速访问:"
    echo "  应用服务: http://localhost:38000"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3000"
}

# 执行主函数
main "$@"
