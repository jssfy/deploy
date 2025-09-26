#!/bin/bash

# PostgreSQL Docker 部署脚本
# 使用方法: ./deploy.sh [start|stop|restart|status|logs|backup|restore]

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

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
}

# 检查环境配置文件
check_env() {
    if [ ! -f ".env" ]; then
        log_warning "未找到 .env 文件，正在从 env.example 创建..."
        if [ -f "env.example" ]; then
            cp env.example .env
            log_success "已创建 .env 文件，请根据需要修改配置"
        else
            log_error "未找到 env.example 文件"
            exit 1
        fi
    fi
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    sudo mkdir -p /home/data/postgres
    sudo mkdir -p /home/data/pgadmin
    sudo mkdir -p /usr/data/backups
    sudo mkdir -p logs
    
    # 设置目录权限
    sudo chown -R 999:999 /home/data/postgres
    sudo chown -R 5050:5050 /home/data/pgadmin
    sudo chmod -R 755 /usr/data/backups
    
    log_success "目录创建完成"
}

# 启动服务
start_services() {
    log_info "启动 PostgreSQL 服务..."
    docker compose up -d
    log_success "服务启动完成"
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker compose ps | grep -q "Up"; then
        log_success "PostgreSQL 服务已成功启动"
        log_info "数据库连接信息:"
        echo "  主机: $(grep POSTGRES_HOST .env | cut -d'=' -f2)"
        echo "  端口: $(grep POSTGRES_PORT .env | cut -d'=' -f2)"
        echo "  数据库: $(grep POSTGRES_DB .env | cut -d'=' -f2)"
        echo "  用户名: $(grep POSTGRES_USER .env | cut -d'=' -f2)"
        echo "  密码: $(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)"
        echo ""
        log_info "PgAdmin 管理界面:"
        echo "  URL: http://$(grep PGADMIN_HOST .env | cut -d'=' -f2):$(grep PGADMIN_PORT .env | cut -d'=' -f2)"
        echo "  邮箱: $(grep PGADMIN_EMAIL .env | cut -d'=' -f2)"
        echo "  密码: $(grep PGADMIN_PASSWORD .env | cut -d'=' -f2)"
    else
        log_error "服务启动失败"
        exit 1
    fi
}

# 停止服务
stop_services() {
    log_info "停止 PostgreSQL 服务..."
    docker compose down
    log_success "服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启 PostgreSQL 服务..."
    docker compose restart
    log_success "服务重启完成"
}

# 查看服务状态
show_status() {
    log_info "PostgreSQL 服务状态:"
    docker compose ps
}

# 查看日志
show_logs() {
    log_info "显示服务日志 (按 Ctrl+C 退出):"
    docker compose logs -f
}

# 备份数据库
backup_database() {
    local backup_file="/usr/data/backups/postgres_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    log_info "开始备份数据库..."
    docker compose exec -T postgres pg_dump -U $(grep POSTGRES_USER .env | cut -d'=' -f2) $(grep POSTGRES_DB .env | cut -d'=' -f2) > "$backup_file"
    
    if [ $? -eq 0 ]; then
        log_success "数据库备份完成: $backup_file"
        
        # 清理旧备份
        local retention_days=$(grep BACKUP_RETENTION_DAYS .env | cut -d'=' -f2)
        find /usr/data/backups -name "postgres_backup_*.sql" -mtime +$retention_days -delete 2>/dev/null || true
        log_info "已清理 $retention_days 天前的备份文件"
    else
        log_error "数据库备份失败"
        exit 1
    fi
}

# 恢复数据库
restore_database() {
    if [ -z "$2" ]; then
        log_error "请指定备份文件路径"
        echo "使用方法: $0 restore <备份文件路径>"
        exit 1
    fi
    
    local backup_file="$2"
    
    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_file"
        exit 1
    fi
    
    log_warning "此操作将覆盖当前数据库，是否继续? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    log_info "开始恢复数据库..."
    docker compose exec -T postgres psql -U $(grep POSTGRES_USER .env | cut -d'=' -f2) $(grep POSTGRES_DB .env | cut -d'=' -f2) < "$backup_file"
    
    if [ $? -eq 0 ]; then
        log_success "数据库恢复完成"
    else
        log_error "数据库恢复失败"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "PostgreSQL Docker 部署脚本"
    echo ""
    echo "使用方法: $0 [命令]"
    echo ""
    echo "可用命令:"
    echo "  start     - 启动 PostgreSQL 服务"
    echo "  stop      - 停止 PostgreSQL 服务"
    echo "  restart   - 重启 PostgreSQL 服务"
    echo "  status    - 查看服务状态"
    echo "  logs      - 查看服务日志"
    echo "  backup    - 备份数据库"
    echo "  restore   - 恢复数据库 (需要指定备份文件路径)"
    echo "  help      - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start"
    echo "  $0 backup"
    echo "  $0 restore backups/postgres_backup_20231201_120000.sql"
}

# 主函数
main() {
    case "${1:-help}" in
        start)
            check_docker
            check_env
            create_directories
            start_services
            ;;
        stop)
            check_docker
            stop_services
            ;;
        restart)
            check_docker
            restart_services
            ;;
        status)
            check_docker
            show_status
            ;;
        logs)
            check_docker
            show_logs
            ;;
        backup)
            check_docker
            check_env
            backup_database
            ;;
        restore)
            check_docker
            check_env
            restore_database "$@"
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
