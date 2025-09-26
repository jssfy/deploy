#!/bin/bash

# PostgreSQL 自动备份脚本
# 支持定时备份和手动备份

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

# 获取配置
get_config() {
    if [ ! -f ".env" ]; then
        log_error "未找到 .env 文件"
        exit 1
    fi
    
    export POSTGRES_DB=$(grep POSTGRES_DB .env | cut -d'=' -f2)
    export POSTGRES_USER=$(grep POSTGRES_USER .env | cut -d'=' -f2)
    export POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)
    export POSTGRES_HOST=$(grep POSTGRES_HOST .env | cut -d'=' -f2)
    export POSTGRES_PORT=$(grep POSTGRES_PORT .env | cut -d'=' -f2)
    export BACKUP_RETENTION_DAYS=$(grep BACKUP_RETENTION_DAYS .env | cut -d'=' -f2)
}

# 创建备份目录
create_backup_dir() {
    local backup_dir="/usr/data/backups/$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# 备份单个数据库
backup_database() {
    local db_name="$1"
    local backup_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${db_name}_backup_${timestamp}.sql"
    
    log_info "备份数据库: $db_name"
    
    # 执行备份
    docker compose exec -T postgres pg_dump \
        -U "$POSTGRES_USER" \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        --verbose \
        --clean \
        --no-owner \
        --no-privileges \
        "$db_name" > "$backup_file"
    
    if [ $? -eq 0 ]; then
        # 压缩备份文件
        gzip "$backup_file"
        log_success "数据库 $db_name 备份完成: ${backup_file}.gz"
        
        # 显示备份文件大小
        local file_size=$(du -h "${backup_file}.gz" | cut -f1)
        log_info "备份文件大小: $file_size"
        
        return 0
    else
        log_error "数据库 $db_name 备份失败"
        return 1
    fi
}

# 备份所有数据库
backup_all_databases() {
    local backup_dir=$(create_backup_dir)
    local success_count=0
    local total_count=0
    
    log_info "开始备份所有数据库..."
    
    # 获取所有数据库列表
    local databases=$(docker compose exec -T postgres psql -U "$POSTGRES_USER" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" | tr -d ' ')
    
    for db in $databases; do
        if [ -n "$db" ]; then
            total_count=$((total_count + 1))
            if backup_database "$db" "$backup_dir"; then
                success_count=$((success_count + 1))
            fi
        fi
    done
    
    log_info "备份完成: $success_count/$total_count 个数据库备份成功"
    
    # 清理旧备份
    cleanup_old_backups
}

# 清理旧备份
cleanup_old_backups() {
    if [ -n "$BACKUP_RETENTION_DAYS" ] && [ "$BACKUP_RETENTION_DAYS" -gt 0 ]; then
        log_info "清理 $BACKUP_RETENTION_DAYS 天前的备份文件..."
        find /usr/data/backups -name "*.sql.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true
        find /usr/data/backups -name "*.sql" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true
        log_success "旧备份清理完成"
    fi
}

# 恢复数据库
restore_database() {
    local backup_file="$1"
    local db_name="$2"
    
    if [ -z "$backup_file" ]; then
        log_error "请指定备份文件路径"
        echo "使用方法: $0 restore <备份文件路径> [数据库名]"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_file"
        exit 1
    fi
    
    # 如果没有指定数据库名，从文件名推断
    if [ -z "$db_name" ]; then
        db_name=$(basename "$backup_file" | sed 's/_backup_.*//')
    fi
    
    log_warning "此操作将覆盖数据库 $db_name，是否继续? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    log_info "恢复数据库: $db_name"
    
    # 检查文件是否压缩
    if [[ "$backup_file" == *.gz ]]; then
        # 解压并恢复
        gunzip -c "$backup_file" | docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$db_name"
    else
        # 直接恢复
        docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$db_name" < "$backup_file"
    fi
    
    if [ $? -eq 0 ]; then
        log_success "数据库 $db_name 恢复完成"
    else
        log_error "数据库 $db_name 恢复失败"
        exit 1
    fi
}

# 列出备份文件
list_backups() {
    log_info "备份文件列表:"
    if [ -d "/usr/data/backups" ]; then
        find /usr/data/backups -name "*.sql*" -type f -exec ls -lh {} \; | awk '{print $9, $5, $6, $7, $8}'
    else
        log_warning "备份目录不存在"
    fi
}

# 设置定时备份
setup_cron() {
    local script_path=$(realpath "$0")
    local cron_schedule=$(grep BACKUP_SCHEDULE .env | cut -d'=' -f2 | tr -d '"')
    
    if [ -z "$cron_schedule" ]; then
        cron_schedule="0 2 * * *"  # 默认每天凌晨2点
    fi
    
    log_info "设置定时备份任务..."
    
    # 检查是否已存在定时任务
    if crontab -l 2>/dev/null | grep -q "$script_path"; then
        log_warning "定时备份任务已存在"
        return 0
    fi
    
    # 添加定时任务
    (crontab -l 2>/dev/null; echo "$cron_schedule $script_path auto") | crontab -
    log_success "定时备份任务设置完成: $cron_schedule"
}

# 移除定时备份
remove_cron() {
    local script_path=$(realpath "$0")
    
    log_info "移除定时备份任务..."
    crontab -l 2>/dev/null | grep -v "$script_path" | crontab -
    log_success "定时备份任务已移除"
}

# 显示帮助信息
show_help() {
    echo "PostgreSQL 自动备份脚本"
    echo ""
    echo "使用方法: $0 [命令] [参数]"
    echo ""
    echo "可用命令:"
    echo "  backup                    - 备份所有数据库"
    echo "  backup <数据库名>         - 备份指定数据库"
    echo "  restore <备份文件> [数据库名] - 恢复数据库"
    echo "  list                      - 列出所有备份文件"
    echo "  cleanup                   - 清理旧备份文件"
    echo "  setup-cron                - 设置定时备份"
    echo "  remove-cron               - 移除定时备份"
    echo "  auto                      - 自动备份模式 (用于定时任务)"
    echo "  help                      - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 backup"
    echo "  $0 backup myapp"
    echo "  $0 restore backups/20231201/myapp_backup_20231201_120000.sql.gz"
    echo "  $0 list"
    echo "  $0 setup-cron"
}

# 主函数
main() {
    get_config
    
    case "${1:-help}" in
        backup)
            if [ -n "$2" ]; then
                # 备份指定数据库
                backup_dir=$(create_backup_dir)
                backup_database "$2" "$backup_dir"
                cleanup_old_backups
            else
                # 备份所有数据库
                backup_all_databases
            fi
            ;;
        restore)
            restore_database "$2" "$3"
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        setup-cron)
            setup_cron
            ;;
        remove-cron)
            remove_cron
            ;;
        auto)
            # 自动备份模式 (用于定时任务)
            backup_all_databases
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
