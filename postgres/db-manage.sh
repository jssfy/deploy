#!/bin/bash

# PostgreSQL 数据库管理脚本
# 提供常用的数据库管理功能

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

# 获取数据库连接参数
get_db_params() {
    if [ ! -f ".env" ]; then
        log_error "未找到 .env 文件"
        exit 1
    fi
    
    export POSTGRES_DB=$(grep POSTGRES_DB .env | cut -d'=' -f2)
    export POSTGRES_USER=$(grep POSTGRES_USER .env | cut -d'=' -f2)
    export POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)
    export POSTGRES_PORT=$(grep POSTGRES_PORT .env | cut -d'=' -f2)
}

# 执行SQL命令
execute_sql() {
    local sql="$1"
    get_db_params
    
    docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$sql"
}

# 连接到数据库
connect_db() {
    get_db_params
    log_info "连接到 PostgreSQL 数据库..."
    docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
}

# 创建数据库
create_database() {
    local db_name="$1"
    
    if [ -z "$db_name" ]; then
        log_error "请指定数据库名称"
        echo "使用方法: $0 create-db <数据库名称>"
        exit 1
    fi
    
    log_info "创建数据库: $db_name"
    execute_sql "CREATE DATABASE $db_name;"
    log_success "数据库 $db_name 创建成功"
}

# 删除数据库
drop_database() {
    local db_name="$1"
    
    if [ -z "$db_name" ]; then
        log_error "请指定数据库名称"
        echo "使用方法: $0 drop-db <数据库名称>"
        exit 1
    fi
    
    log_warning "此操作将永久删除数据库 $db_name，是否继续? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    log_info "删除数据库: $db_name"
    execute_sql "DROP DATABASE IF EXISTS $db_name;"
    log_success "数据库 $db_name 删除成功"
}

# 创建用户
create_user() {
    local username="$1"
    local password="$2"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        log_error "请指定用户名和密码"
        echo "使用方法: $0 create-user <用户名> <密码>"
        exit 1
    fi
    
    log_info "创建用户: $username"
    execute_sql "CREATE USER $username WITH PASSWORD '$password';"
    log_success "用户 $username 创建成功"
}

# 删除用户
drop_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        log_error "请指定用户名"
        echo "使用方法: $0 drop-user <用户名>"
        exit 1
    fi
    
    log_warning "此操作将永久删除用户 $username，是否继续? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    log_info "删除用户: $username"
    execute_sql "DROP USER IF EXISTS $username;"
    log_success "用户 $username 删除成功"
}

# 列出所有数据库
list_databases() {
    log_info "数据库列表:"
    execute_sql "\l"
}

# 列出所有用户
list_users() {
    log_info "用户列表:"
    execute_sql "\du"
}

# 显示数据库大小
show_db_size() {
    local db_name="${1:-$POSTGRES_DB}"
    
    if [ -z "$db_name" ]; then
        get_db_params
        db_name="$POSTGRES_DB"
    fi
    
    log_info "数据库 $db_name 大小信息:"
    execute_sql "SELECT pg_size_pretty(pg_database_size('$db_name'));"
}

# 显示表信息
show_tables() {
    log_info "表列表:"
    execute_sql "\dt"
}

# 显示表结构
describe_table() {
    local table_name="$1"
    
    if [ -z "$table_name" ]; then
        log_error "请指定表名"
        echo "使用方法: $0 describe <表名>"
        exit 1
    fi
    
    log_info "表 $table_name 结构:"
    execute_sql "\d $table_name"
}

# 执行SQL文件
execute_sql_file() {
    local sql_file="$1"
    
    if [ -z "$sql_file" ]; then
        log_error "请指定SQL文件路径"
        echo "使用方法: $0 exec-file <SQL文件路径>"
        exit 1
    fi
    
    if [ ! -f "$sql_file" ]; then
        log_error "SQL文件不存在: $sql_file"
        exit 1
    fi
    
    log_info "执行SQL文件: $sql_file"
    get_db_params
    docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "/docker-entrypoint-initdb.d/$(basename "$sql_file")"
    log_success "SQL文件执行完成"
}

# 显示帮助信息
show_help() {
    echo "PostgreSQL 数据库管理脚本"
    echo ""
    echo "使用方法: $0 [命令] [参数]"
    echo ""
    echo "可用命令:"
    echo "  connect                    - 连接到数据库"
    echo "  create-db <数据库名>        - 创建数据库"
    echo "  drop-db <数据库名>          - 删除数据库"
    echo "  create-user <用户名> <密码>  - 创建用户"
    echo "  drop-user <用户名>          - 删除用户"
    echo "  list-dbs                   - 列出所有数据库"
    echo "  list-users                 - 列出所有用户"
    echo "  show-size [数据库名]        - 显示数据库大小"
    echo "  show-tables                - 显示所有表"
    echo "  describe <表名>             - 显示表结构"
    echo "  exec-file <SQL文件>         - 执行SQL文件"
    echo "  help                       - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 connect"
    echo "  $0 create-db testdb"
    echo "  $0 create-user testuser testpass"
    echo "  $0 show-tables"
    echo "  $0 describe users"
}

# 主函数
main() {
    case "${1:-help}" in
        connect)
            connect_db
            ;;
        create-db)
            create_database "$2"
            ;;
        drop-db)
            drop_database "$2"
            ;;
        create-user)
            create_user "$2" "$3"
            ;;
        drop-user)
            drop_user "$2"
            ;;
        list-dbs)
            list_databases
            ;;
        list-users)
            list_users
            ;;
        show-size)
            show_db_size "$2"
            ;;
        show-tables)
            show_tables
            ;;
        describe)
            describe_table "$2"
            ;;
        exec-file)
            execute_sql_file "$2"
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
