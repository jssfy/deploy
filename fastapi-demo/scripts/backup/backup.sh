#!/bin/bash
# 监控系统数据备份脚本

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

# 配置
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="monitoring_backup_$TIMESTAMP"

# 显示帮助信息
show_help() {
    echo "监控系统数据备份脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -d, --dir DIR  指定备份目录 (默认: ./backups)"
    echo "  -n, --name NAME 指定备份名称 (默认: monitoring_backup_TIMESTAMP)"
    echo "  -c, --compress 压缩备份文件"
    echo "  -v, --volumes  只备份数据卷"
    echo "  -f, --full     完整备份 (包括配置和数据)"
    echo ""
    echo "示例:"
    echo "  $0                    # 默认备份"
    echo "  $0 -c                 # 压缩备份"
    echo "  $0 -d /tmp/backups    # 指定备份目录"
    echo "  $0 -v                 # 只备份数据卷"
}

# 创建备份目录
create_backup_dir() {
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    
    if [[ ! -d "$backup_path" ]]; then
        mkdir -p "$backup_path"
        log_success "创建备份目录: $backup_path"
    fi
    
    echo "$backup_path"
}

# 备份数据卷
backup_volumes() {
    local backup_path="$1"
    local volumes_dir="$backup_path/volumes"
    
    log_info "备份数据卷..."
    mkdir -p "$volumes_dir"
    
    local volumes=(
        "fastapi-demo_prometheus_data"
        "fastapi-demo_grafana_data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log_info "备份数据卷: $volume"
            
            if docker run --rm \
                -v "$volume":/data \
                -v "$volumes_dir":/backup \
                alpine tar czf "/backup/${volume}.tar.gz" -C /data .; then
                log_success "数据卷 $volume 备份完成"
            else
                log_error "数据卷 $volume 备份失败"
                return 1
            fi
        else
            log_warning "数据卷 $volume 不存在"
        fi
    done
}

# 备份配置文件
backup_configs() {
    local backup_path="$1"
    local configs_dir="$backup_path/configs"
    
    log_info "备份配置文件..."
    mkdir -p "$configs_dir"
    
    local config_files=(
        "docker-compose.yml"
        "configs/prometheus_config.yml"
        "configs/alert_rules.yml"
        "configs/Dockerfile"
        "configs/requirements_monitoring.txt"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$configs_dir/"
            log_success "配置文件 $file 备份完成"
        else
            log_warning "配置文件 $file 不存在"
        fi
    done
}

# 备份脚本文件
backup_scripts() {
    local backup_path="$1"
    local scripts_dir="$backup_path/scripts"
    
    log_info "备份脚本文件..."
    
    if [[ -d "scripts" ]]; then
        cp -r "scripts" "$scripts_dir"
        log_success "脚本文件备份完成"
    else
        log_warning "脚本目录不存在"
    fi
}

# 备份文档文件
backup_docs() {
    local backup_path="$1"
    local docs_dir="$backup_path/docs"
    
    log_info "备份文档文件..."
    
    if [[ -d "docs" ]]; then
        cp -r "docs" "$docs_dir"
        log_success "文档文件备份完成"
    else
        log_warning "文档目录不存在"
    fi
}

# 生成备份信息
generate_backup_info() {
    local backup_path="$1"
    local info_file="$backup_path/backup_info.txt"
    
    log_info "生成备份信息..."
    
    cat > "$info_file" << EOF
监控系统备份信息
================

备份时间: $(date)
备份名称: $BACKUP_NAME
备份类型: $BACKUP_TYPE

系统信息:
- 主机名: $(hostname)
- 操作系统: $(uname -s)
- 内核版本: $(uname -r)
- Docker版本: $(docker --version 2>/dev/null || echo "未安装")
- Docker Compose版本: $(docker-compose --version 2>/dev/null || echo "未安装")

服务状态:
$(docker-compose ps 2>/dev/null || echo "服务未运行")

数据卷信息:
$(docker volume ls | grep fastapi-demo || echo "无相关数据卷")

备份内容:
- 数据卷: $(ls -la "$backup_path/volumes" 2>/dev/null | wc -l || echo "0") 个文件
- 配置文件: $(ls -la "$backup_path/configs" 2>/dev/null | wc -l || echo "0") 个文件
- 脚本文件: $(find "$backup_path/scripts" -type f 2>/dev/null | wc -l || echo "0") 个文件
- 文档文件: $(find "$backup_path/docs" -type f 2>/dev/null | wc -l || echo "0") 个文件

备份大小: $(du -sh "$backup_path" | cut -f1)
EOF
    
    log_success "备份信息已生成: $info_file"
}

# 压缩备份
compress_backup() {
    local backup_path="$1"
    local compressed_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    
    log_info "压缩备份文件..."
    
    if tar czf "$compressed_file" -C "$BACKUP_DIR" "$BACKUP_NAME"; then
        log_success "备份已压缩: $compressed_file"
        
        # 删除未压缩的目录
        rm -rf "$backup_path"
        
        echo "$compressed_file"
    else
        log_error "备份压缩失败"
        return 1
    fi
}

# 验证备份
verify_backup() {
    local backup_path="$1"
    
    log_info "验证备份完整性..."
    
    if [[ -d "$backup_path" ]]; then
        # 验证目录结构
        local required_dirs=("volumes" "configs")
        for dir in "${required_dirs[@]}"; do
            if [[ ! -d "$backup_path/$dir" ]]; then
                log_warning "缺少目录: $dir"
            fi
        done
        
        # 验证文件数量
        local volume_count=$(find "$backup_path/volumes" -name "*.tar.gz" 2>/dev/null | wc -l)
        local config_count=$(find "$backup_path/configs" -name "*.yml" -o -name "*.txt" -o -name "Dockerfile" 2>/dev/null | wc -l)
        
        log_success "备份验证完成"
        log_info "  数据卷文件: $volume_count 个"
        log_info "  配置文件: $config_count 个"
    else
        log_error "备份目录不存在"
        return 1
    fi
}

# 清理旧备份
cleanup_old_backups() {
    local backup_dir="$1"
    local keep_days=7
    
    log_info "清理 $keep_days 天前的旧备份..."
    
    if [[ -d "$backup_dir" ]]; then
        find "$backup_dir" -name "monitoring_backup_*" -type d -mtime +$keep_days -exec rm -rf {} \; 2>/dev/null || true
        find "$backup_dir" -name "monitoring_backup_*.tar.gz" -type f -mtime +$keep_days -delete 2>/dev/null || true
        log_success "旧备份清理完成"
    fi
}

# 主函数
main() {
    local BACKUP_TYPE="full"
    local COMPRESS=false
    local VOLUMES_ONLY=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -n|--name)
                BACKUP_NAME="$2"
                shift 2
                ;;
            -c|--compress)
                COMPRESS=true
                shift
                ;;
            -v|--volumes)
                BACKUP_TYPE="volumes"
                VOLUMES_ONLY=true
                shift
                ;;
            -f|--full)
                BACKUP_TYPE="full"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "💾 监控系统数据备份脚本"
    echo "========================"
    
    # 切换到脚本目录的父目录
    cd "$(dirname "$0")/../.."
    
    # 创建备份目录
    local backup_path=$(create_backup_dir)
    
    # 执行备份
    case $BACKUP_TYPE in
        "volumes")
            backup_volumes "$backup_path"
            ;;
        "full")
            backup_volumes "$backup_path"
            backup_configs "$backup_path"
            backup_scripts "$backup_path"
            backup_docs "$backup_path"
            ;;
    esac
    
    # 生成备份信息
    generate_backup_info "$backup_path"
    
    # 验证备份
    verify_backup "$backup_path"
    
    # 压缩备份（如果需要）
    if [[ "$COMPRESS" == "true" ]]; then
        backup_path=$(compress_backup "$backup_path")
    fi
    
    # 清理旧备份
    cleanup_old_backups "$BACKUP_DIR"
    
    # 显示结果
    log_success "备份完成！"
    echo ""
    echo "📁 备份位置: $backup_path"
    echo "📊 备份大小: $(du -sh "$backup_path" | cut -f1)"
    echo "📅 备份时间: $(date)"
    echo ""
    echo "💡 恢复备份:"
    echo "  scripts/backup/restore.sh $backup_path"
}

# 错误处理
trap 'log_error "备份过程中发生错误"; exit 1' ERR

# 执行主函数
main "$@"
