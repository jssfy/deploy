#!/bin/bash

# Prometheus查询测试脚本
# 用于测试和验证Prometheus查询语句

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

# Prometheus API基础URL
PROMETHEUS_URL="http://localhost:9090"

# 检查Prometheus是否运行
check_prometheus() {
    log_info "检查Prometheus服务状态..."
    
    if ! curl -s "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null; then
        log_error "Prometheus服务不可访问，请确保服务正在运行"
        exit 1
    fi
    
    log_success "Prometheus服务正常运行"
}

# 执行查询并格式化输出
execute_query() {
    local query="$1"
    local description="$2"
    
    log_info "查询: $description"
    log_info "语句: $query"
    
    local response=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=$(echo "$query" | sed 's/ /%20/g')")
    
    if echo "$response" | jq -e '.data.result | length > 0' > /dev/null; then
        echo "$response" | jq -r '.data.result[] | "  \(.metric | to_entries | map("\(.key)=\(.value)") | join(", ")): \(.value[1])"'
        log_success "查询成功"
    else
        log_warning "查询无结果或指标不存在"
    fi
    
    echo ""
}

# 基础健康检查查询
test_basic_queries() {
    log_info "=== 基础健康检查查询 ==="
    
    execute_query "up" "服务健康状态"
    execute_query "up{job=\"dual-service-app\"}" "双服务应用健康状态"
    execute_query "avg(up) * 100" "服务健康率百分比"
}

# HTTP请求指标查询
test_http_queries() {
    log_info "=== HTTP请求指标查询 ==="
    
    execute_query "http_requests_total" "HTTP请求总数"
    execute_query "sum by (endpoint) (http_requests_total)" "按接口分组的请求数"
    execute_query "sum by (status_code) (http_requests_total)" "按状态码分组的请求数"
    execute_query "rate(http_requests_total[5m])" "请求速率 (QPS)"
    execute_query "sum by (endpoint) (rate(http_requests_total[5m]))" "按接口的请求速率"
}

# 延迟指标查询
test_latency_queries() {
    log_info "=== 延迟指标查询 ==="
    
    execute_query "rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])" "平均延迟"
    execute_query "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))" "95%延迟"
    execute_query "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))" "99%延迟"
}

# 系统资源查询
test_system_queries() {
    log_info "=== 系统资源查询 ==="
    
    execute_query "process_resident_memory_bytes / 1024 / 1024" "内存使用量 (MB)"
    execute_query "rate(process_cpu_seconds_total[5m]) * 100" "CPU使用率"
    execute_query "process_open_fds" "文件描述符使用数"
    execute_query "process_threads" "线程数"
}

# 业务指标查询
test_business_queries() {
    log_info "=== 业务指标查询 ==="
    
    execute_query "search_requests_total" "检索请求总数"
    execute_query "write_requests_total" "写入请求总数"
    execute_query "rate(search_requests_total[5m])" "检索请求速率"
    execute_query "rate(write_requests_total[5m])" "写入请求速率"
}

# 消息队列查询
test_queue_queries() {
    log_info "=== 消息队列查询 ==="
    
    execute_query "queue_depth" "队列深度"
    execute_query "messages_consumed_total" "消息消费总数"
    execute_query "rate(messages_consumed_total[5m])" "消息消费速率"
    execute_query "histogram_quantile(0.95, rate(message_processing_duration_seconds_bucket[5m]))" "消息处理延迟"
}

# 错误率查询
test_error_queries() {
    log_info "=== 错误率查询 ==="
    
    execute_query "http_4xx_errors_total" "4xx错误总数"
    execute_query "http_5xx_errors_total" "5xx错误总数"
    execute_query "rate(http_4xx_errors_total[5m])" "4xx错误速率"
    execute_query "rate(http_5xx_errors_total[5m])" "5xx错误速率"
}

# 时间范围查询
test_time_queries() {
    log_info "=== 时间范围查询 ==="
    
    execute_query "increase(http_requests_total[1h])" "过去1小时请求数"
    execute_query "increase(http_requests_total[1d])" "过去1天请求数"
    execute_query "time() - service_start_time_seconds" "服务运行时长 (秒)"
    execute_query "(time() - service_start_time_seconds) / 3600" "服务运行时长 (小时)"
}

# 聚合查询
test_aggregation_queries() {
    log_info "=== 聚合查询 ==="
    
    execute_query "sum(http_requests_total)" "总请求数"
    execute_query "avg(http_request_duration_seconds)" "平均延迟"
    execute_query "max(queue_depth)" "最大队列深度"
    execute_query "count(http_requests_total)" "指标数量"
}

# 条件查询
test_conditional_queries() {
    log_info "=== 条件查询 ==="
    
    execute_query "http_requests_total{endpoint=\"/metrics\"}" "metrics接口请求数"
    execute_query "http_requests_total{status_code=\"200\"}" "200状态码请求数"
    execute_query "http_requests_total{endpoint=~\"/search|/write\"}" "搜索或写入接口请求数"
}

# 告警查询
test_alert_queries() {
    log_info "=== 告警查询 ==="
    
    execute_query "rate(http_5xx_errors_total[5m]) / rate(http_requests_total[5m]) > 0.1" "高错误率告警 (>10%)"
    execute_query "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2" "高延迟告警 (>2秒)"
    execute_query "queue_depth > 10000" "队列积压告警 (>10000)"
    execute_query "up == 0" "服务不健康告警"
}

# 仪表板查询
test_dashboard_queries() {
    log_info "=== 仪表板查询 ==="
    
    execute_query "sum(rate(http_requests_total[5m]))" "总QPS"
    execute_query "avg(rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]))" "平均延迟"
    execute_query "sum(rate(http_5xx_errors_total[5m])) / sum(rate(http_requests_total[5m])) * 100" "错误率百分比"
    execute_query "avg(up) * 100" "服务健康率"
}

# 主函数
main() {
    log_info "开始Prometheus查询测试..."
    echo ""
    
    # 检查Prometheus服务
    check_prometheus
    echo ""
    
    # 执行各类查询测试
    test_basic_queries
    test_http_queries
    test_latency_queries
    test_system_queries
    test_business_queries
    test_queue_queries
    test_error_queries
    test_time_queries
    test_aggregation_queries
    test_conditional_queries
    test_alert_queries
    test_dashboard_queries
    
    log_success "所有查询测试完成！"
    echo ""
    log_info "提示: 您可以在Prometheus Web界面 (http://localhost:9090) 中使用这些查询语句"
    log_info "更多查询示例请参考: docs/PROMETHEUS_QUERIES.md"
}

# 检查依赖
if ! command -v curl &> /dev/null; then
    log_error "curl命令未找到，请安装curl"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq命令未找到，请安装jq"
    exit 1
fi

# 运行主函数
main "$@"
