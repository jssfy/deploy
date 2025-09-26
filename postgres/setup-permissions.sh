#!/bin/bash

# 目录权限设置脚本
# 用于设置PostgreSQL Docker部署所需的目录权限

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

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 创建目录并设置权限
setup_directories() {
    log_info "创建数据目录并设置权限..."
    
    # 创建PostgreSQL数据目录
    log_info "创建PostgreSQL数据目录: /home/data/postgres"
    mkdir -p /home/data/postgres
    chown -R 999:999 /home/data/postgres
    chmod -R 755 /home/data/postgres
    
    # 创建PgAdmin数据目录
    log_info "创建PgAdmin数据目录: /home/data/pgadmin"
    mkdir -p /home/data/pgadmin
    chown -R 5050:5050 /home/data/pgadmin
    chmod -R 755 /home/data/pgadmin
    
    # 创建备份目录
    log_info "创建备份目录: /usr/data/backups"
    mkdir -p /usr/data/backups
    chmod -R 755 /usr/data/backups
    
    # 创建日志目录
    log_info "创建日志目录: /var/log/postgres-docker"
    mkdir -p /var/log/postgres-docker
    chmod -R 755 /var/log/postgres-docker
    
    log_success "目录创建和权限设置完成"
}

# 验证权限设置
verify_permissions() {
    log_info "验证目录权限..."
    
    # 检查PostgreSQL目录
    if [ -d "/home/data/postgres" ]; then
        local postgres_owner=$(stat -c '%U:%G' /home/data/postgres)
        if [ "$postgres_owner" = "999:999" ]; then
            log_success "PostgreSQL目录权限正确: $postgres_owner"
        else
            log_warning "PostgreSQL目录权限异常: $postgres_owner (期望: 999:999)"
        fi
    else
        log_error "PostgreSQL目录不存在"
    fi
    
    # 检查PgAdmin目录
    if [ -d "/home/data/pgadmin" ]; then
        local pgadmin_owner=$(stat -c '%U:%G' /home/data/pgadmin)
        if [ "$pgadmin_owner" = "5050:5050" ]; then
            log_success "PgAdmin目录权限正确: $pgadmin_owner"
        else
            log_warning "PgAdmin目录权限异常: $pgadmin_owner (期望: 5050:5050)"
        fi
    else
        log_error "PgAdmin目录不存在"
    fi
    
    # 检查备份目录
    if [ -d "/usr/data/backups" ]; then
        log_success "备份目录存在: /usr/data/backups"
    else
        log_error "备份目录不存在"
    fi
}

# 显示目录信息
show_directory_info() {
    log_info "目录信息:"
    echo ""
    echo "数据目录:"
    echo "  PostgreSQL: /home/data/postgres (用户: 999:999)"
    echo "  PgAdmin:    /home/data/pgadmin (用户: 5050:5050)"
    echo ""
    echo "备份目录:"
    echo "  备份文件:   /usr/data/backups"
    echo ""
    echo "日志目录:"
    echo "  应用日志:   /var/log/postgres-docker"
    echo ""
}

# 显示帮助信息
show_help() {
    echo "PostgreSQL Docker 目录权限设置脚本"
    echo ""
    echo "使用方法: sudo $0 [命令]"
    echo ""
    echo "可用命令:"
    echo "  setup      - 创建目录并设置权限"
    echo "  verify     - 验证目录权限"
    echo "  info       - 显示目录信息"
    echo "  help       - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  sudo $0 setup"
    echo "  sudo $0 verify"
}

# 主函数
main() {
    case "${1:-help}" in
        setup)
            check_root
            setup_directories
            verify_permissions
            show_directory_info
            ;;
        verify)
            check_root
            verify_permissions
            ;;
        info)
            show_directory_info
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
