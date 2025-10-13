#!/bin/bash
# 监控系统数据恢复脚本

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
    echo "监控系统数据恢复脚本"
    echo ""
    echo "用法: $0 [选项] <备份路径>"
    echo ""
    echo "参数:"
    echo "  <备份路径>    备份文件或目录的路径"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -f, --force    强制恢复（覆盖现有数据）"
    echo "  -v, --volumes  只恢复数据卷"
    echo "  -c, --configs  只恢复配置文件"
    echo ""
    echo "示例:"
    echo "  $0 ./backups/monitoring_backup_20231010_120000"
    echo "  $0 ./backups/monitoring_backup_20231010_120000.tar.gz"
    echo "  $0 -v ./backups/monitoring_backup_20231010_120000"
}

# 检查备份文件
check_backup() {
    local backup_path="$1"
    
    if [[ ! -e "$backup_path" ]]; then
        log_error "备份文件不存在: $backup_path"
        exit 1
    fi
    
    # 如果是压缩文件，先解压
    if [[ "$backup_path" == *.tar.gz ]]; then
        log_info "检测到压缩备份文件，正在解压..."
        
        local extract_dir="./temp_restore_$(date +%s)"
        mkdir -p "$extract_dir"
        
        if tar xzf "$backup_path" -C "$extract_dir"; then
            backup_path="$extract_dir/$(basename "$backup_path" .tar.gz)"
            log_success "备份文件解压完成: $backup_path"
        else
            log_error "备份文件解压失败"
            exit 1
        fi
    fi
    
    # 检查备份目录结构
    if [[ ! -d "$backup_path" ]]; then
        log_error "备份目录不存在: $backup_path"
        exit 1
    fi
    
    echo "$backup_path"
}

# 显示备份信息
show_backup_info() {
    local backup_path="$1"
    local info_file="$backup_path/backup_info.txt"
    
    if [[ -f "$info_file" ]]; then
        log_info "备份信息:"
        echo "=========="
        cat "$info_file"
        echo ""
    else
        log_warning "未找到备份信息文件"
    fi
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

# 恢复数据卷
restore_volumes() {
    local backup_path="$1"
    local volumes_dir="$backup_path/volumes"
    
    if [[ ! -d "$volumes_dir" ]]; then
        log_warning "数据卷备份目录不存在: $volumes_dir"
        return 0
    fi
    
    log_info "恢复数据卷..."
    
    # 删除现有数据卷
    local volumes=(
        "fastapi-demo_prometheus_data"
        "fastapi-demo_grafana_data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log_info "删除现有数据卷: $volume"
            docker volume rm "$volume" || log_warning "删除数据卷失败: $volume"
        fi
    done
    
    # 恢复数据卷
    for volume_file in "$volumes_dir"/*.tar.gz; do
        if [[ -f "$volume_file" ]]; then
            local volume_name=$(basename "$volume_file" .tar.gz)
            log_info "恢复数据卷: $volume_name"
            
            # 创建新的数据卷
            docker volume create "$volume_name"
            
            # 恢复数据
            if docker run --rm \
                -v "$volume_name":/data \
                -v "$volumes_dir":/backup \
                alpine tar xzf "/backup/$(basename "$volume_file")" -C /data; then
                log_success "数据卷 $volume_name 恢复完成"
            else
                log_error "数据卷 $volume_name 恢复失败"
                return 1
            fi
        fi
    done
}

# 恢复配置文件
restore_configs() {
    local backup_path="$1"
    local configs_dir="$backup_path/configs"
    
    if [[ ! -d "$configs_dir" ]]; then
        log_warning "配置文件备份目录不存在: $configs_dir"
        return 0
    fi
    
    log_info "恢复配置文件..."
    
    # 备份当前配置文件
    local current_backup_dir="./config_backup_$(date +%s)"
    mkdir -p "$current_backup_dir"
    
    local config_files=(
        "docker-compose.yml"
        "configs/prometheus_config.yml"
        "configs/alert_rules.yml"
        "configs/Dockerfile"
        "configs/requirements_monitoring.txt"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$current_backup_dir/"
            log_info "备份当前配置文件: $file"
        fi
    done
    
    # 恢复配置文件
    for file in "$configs_dir"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            cp "$file" "./$filename"
            log_success "配置文件 $filename 恢复完成"
        fi
    done
    
    log_info "当前配置文件已备份到: $current_backup_dir"
}

# 恢复脚本文件
restore_scripts() {
    local backup_path="$1"
    local scripts_dir="$backup_path/scripts"
    
    if [[ ! -d "$scripts_dir" ]]; then
        log_warning "脚本文件备份目录不存在: $scripts_dir"
        return 0
    fi
    
    log_info "恢复脚本文件..."
    
    # 备份当前脚本
    if [[ -d "scripts" ]]; then
        local current_backup_dir="./scripts_backup_$(date +%s)"
        cp -r "scripts" "$current_backup_dir"
        log_info "当前脚本已备份到: $current_backup_dir"
    fi
    
    # 恢复脚本
    if [[ -d "$scripts_dir/scripts" ]]; then
        cp -r "$scripts_dir/scripts" ./
        log_success "脚本文件恢复完成"
    fi
}

# 恢复文档文件
restore_docs() {
    local backup_path="$1"
    local docs_dir="$backup_path/docs"
    
    if [[ ! -d "$docs_dir" ]]; then
        log_warning "文档文件备份目录不存在: $docs_dir"
        return 0
    fi
    
    log_info "恢复文档文件..."
    
    # 备份当前文档
    if [[ -d "docs" ]]; then
        local current_backup_dir="./docs_backup_$(date +%s)"
        cp -r "docs" "$current_backup_dir"
        log_info "当前文档已备份到: $current_backup_dir"
    fi
    
    # 恢复文档
    if [[ -d "$docs_dir/docs" ]]; then
        cp -r "$docs_dir/docs" ./
        log_success "文档文件恢复完成"
    fi
}

# 启动服务
start_services() {
    log_info "启动监控服务..."
    
    if docker-compose up -d; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        return 1
    fi
    
    # 等待服务就绪
    log_info "等待服务就绪..."
    sleep 10
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "所有服务运行正常"
    else
        log_warning "部分服务可能未正常运行"
        docker-compose ps
    fi
}

# 验证恢复
verify_restore() {
    log_info "验证恢复结果..."
    
    echo ""
    echo "📊 恢复验证:"
    echo "============"
    
    # 检查服务状态
    local healthy_services=0
    local total_services=3
    
    if docker-compose ps | grep -q "app.*Up"; then
        ((healthy_services++))
        log_success "应用服务: 运行中"
    else
        log_error "应用服务: 未运行"
    fi
    
    if docker-compose ps | grep -q "prometheus.*Up"; then
        ((healthy_services++))
        log_success "Prometheus: 运行中"
    else
        log_error "Prometheus: 未运行"
    fi
    
    if docker-compose ps | grep -q "grafana.*Up"; then
        ((healthy_services++))
        log_success "Grafana: 运行中"
    else
        log_error "Grafana: 未运行"
    fi
    
    # 检查数据卷
    local volume_count=$(docker volume ls | grep fastapi-demo | wc -l)
    log_info "数据卷数量: $volume_count"
    
    # 检查Prometheus目标
    sleep 5
    if curl -s http://localhost:9090/api/v1/targets > /dev/null 2>&1; then
        log_success "Prometheus目标监控: 正常"
    else
        log_warning "Prometheus目标监控: 异常"
    fi
    
    local health_percentage=$((healthy_services * 100 / total_services))
    if [[ $health_percentage -eq 100 ]]; then
        log_success "恢复验证: 成功 ($health_percentage%)"
    else
        log_warning "恢复验证: 部分成功 ($health_percentage%)"
    fi
}

# 清理临时文件
cleanup_temp() {
    local temp_dir="$1"
    
    if [[ -d "$temp_dir" ]]; then
        log_info "清理临时文件..."
        rm -rf "$temp_dir"
        log_success "临时文件清理完成"
    fi
}

# 主函数
main() {
    local FORCE=false
    local VOLUMES_ONLY=false
    local CONFIGS_ONLY=false
    local backup_path=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--volumes)
                VOLUMES_ONLY=true
                shift
                ;;
            -c|--configs)
                CONFIGS_ONLY=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                backup_path="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$backup_path" ]]; then
        log_error "请指定备份路径"
        show_help
        exit 1
    fi
    
    echo "🔄 监控系统数据恢复脚本"
    echo "========================"
    
    # 切换到脚本目录的父目录
    cd "$(dirname "$0")/../.."
    
    # 检查备份文件
    backup_path=$(check_backup "$backup_path")
    
    # 显示备份信息
    show_backup_info "$backup_path"
    
    # 确认操作
    if [[ "$FORCE" != "true" ]]; then
        echo ""
        log_warning "⚠️  警告: 此操作将覆盖现有数据！"
        read -p "确认继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            cleanup_temp "$backup_path"
            exit 0
        fi
    fi
    
    # 停止服务
    stop_services
    
    # 执行恢复
    if [[ "$VOLUMES_ONLY" == "true" ]]; then
        restore_volumes "$backup_path"
    elif [[ "$CONFIGS_ONLY" == "true" ]]; then
        restore_configs "$backup_path"
    else
        restore_volumes "$backup_path"
        restore_configs "$backup_path"
        restore_scripts "$backup_path"
        restore_docs "$backup_path"
    fi
    
    # 启动服务
    start_services
    
    # 验证恢复
    verify_restore
    
    # 清理临时文件
    cleanup_temp "$backup_path"
    
    # 显示结果
    log_success "恢复完成！"
    echo ""
    echo "🌐 服务访问地址："
    echo "  应用服务: http://localhost:38000"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3000"
}

# 错误处理
trap 'log_error "恢复过程中发生错误"; exit 1' ERR

# 执行主函数
main "$@"
