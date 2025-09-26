# PostgreSQL Docker 部署方案

这是一个基于Docker的PostgreSQL数据库部署方案，包含完整的部署、管理和备份功能。

## 📋 功能特性

- 🐳 **Docker容器化部署** - 使用Docker Compose一键部署
- 🗄️ **PostgreSQL 15** - 使用最新的PostgreSQL 15 Alpine版本
- 🖥️ **PgAdmin管理界面** - 提供Web界面管理数据库
- 🔧 **自动化脚本** - 提供部署、管理和备份脚本
- 💾 **自动备份** - 支持定时备份和手动备份
- 🔒 **数据持久化** - 数据存储在Docker卷中
- 🏥 **健康检查** - 自动监控数据库状态
- 📊 **初始化脚本** - 自动创建示例数据库和表

## 📁 项目结构

```
.
├── docker-compose.yml          # Docker Compose配置文件
├── env.example                 # 环境变量示例文件
├── deploy.sh                   # 部署管理脚本
├── db-manage.sh               # 数据库管理脚本
├── backup.sh                  # 备份脚本
├── init-scripts/              # 数据库初始化脚本目录
│   └── 01-init-database.sql   # 初始化数据库脚本
├── postgres-config/           # PostgreSQL配置文件目录
│   ├── postgresql.conf        # PostgreSQL主配置文件
│   └── pg_hba.conf           # 客户端认证配置文件
├── /home/data/                # 数据存储目录
│   ├── postgres/              # PostgreSQL数据目录
│   └── pgadmin/               # PgAdmin数据目录
├── /usr/data/                 # 备份存储目录
│   └── backups/               # 备份文件存储目录
└── README.md                  # 项目说明文档
```

## 🚀 快速开始

### 1. 环境准备

确保系统已安装以下软件：
- Docker (版本 20.10+)
- Docker Compose V2 (版本 2.0+)

**注意**: 本方案使用现代的 `docker compose` 命令（Docker Compose V2），而不是旧的 `docker-compose` 命令。Docker Compose V2 已集成到Docker CLI中，提供更好的性能和功能。

### 2. 配置环境变量

```bash
# 复制环境变量示例文件
cp env.example .env

# 编辑配置文件，根据需要修改参数
nano .env
```

### 3. 启动服务

```bash
# 启动PostgreSQL服务
./deploy.sh start
```

### 4. 验证部署

访问以下地址验证部署：
- **数据库连接**: 
  - 本地: `${POSTGRES_HOST}:${POSTGRES_PORT}`
  - 远程: `<服务器IP>:${POSTGRES_PORT}`
- **PgAdmin管理界面**: 
  - 本地: `http://${PGADMIN_HOST}:${PGADMIN_PORT}`
  - 远程: `http://<服务器IP>:${PGADMIN_PORT}`

## 📖 使用说明

### 部署脚本 (deploy.sh)

```bash
# 启动服务
./deploy.sh start

# 停止服务
./deploy.sh stop

# 重启服务
./deploy.sh restart

# 查看服务状态
./deploy.sh status

# 查看服务日志
./deploy.sh logs

# 备份数据库
./deploy.sh backup

# 恢复数据库
./deploy.sh restore backups/postgres_backup_20231201_120000.sql

# 显示帮助
./deploy.sh help
```

### 数据库管理脚本 (db-manage.sh)

```bash
# 连接到数据库
./db-manage.sh connect

# 创建数据库
./db-manage.sh create-db testdb

# 删除数据库
./db-manage.sh drop-db testdb

# 创建用户
./db-manage.sh create-user testuser testpass

# 删除用户
./db-manage.sh drop-user testuser

# 列出所有数据库
./db-manage.sh list-dbs

# 列出所有用户
./db-manage.sh list-users

# 显示数据库大小
./db-manage.sh show-size

# 显示所有表
./db-manage.sh show-tables

# 显示表结构
./db-manage.sh describe users

# 执行SQL文件
./db-manage.sh exec-file init-scripts/01-init-database.sql
```

### 备份脚本 (backup.sh)

```bash
# 备份所有数据库
./backup.sh backup

# 备份指定数据库
./backup.sh backup myapp

# 恢复数据库
./backup.sh restore backups/20231201/myapp_backup_20231201_120000.sql.gz

# 列出备份文件
./backup.sh list

# 清理旧备份
./backup.sh cleanup

# 设置定时备份
./backup.sh setup-cron

# 移除定时备份
./backup.sh remove-cron
```

## ⚙️ 配置说明

### 远程访问配置

本方案默认配置为允许远程IP访问数据库，主要配置包括：

1. **Docker端口绑定**: 使用 `0.0.0.0:端口` 绑定所有网络接口
2. **PostgreSQL配置**: 
   - `listen_addresses = '*'` - 监听所有IP地址
   - `pg_hba.conf` - 允许所有IP连接（使用MD5认证）
3. **PgAdmin配置**: 同样允许远程访问

**安全提醒**: 生产环境建议：
- 限制特定IP段访问
- 使用防火墙规则
- 定期更新密码
- 启用SSL连接

### 环境变量配置 (.env)

```bash
# PostgreSQL 数据库配置
POSTGRES_DB=myapp                    # 数据库名称
POSTGRES_USER=postgres               # 数据库用户名
POSTGRES_PASSWORD=postgres123        # 数据库密码
POSTGRES_PORT=5432                   # 数据库端口

# PgAdmin 配置
PGADMIN_EMAIL=admin@example.com      # PgAdmin登录邮箱
PGADMIN_PASSWORD=admin123            # PgAdmin登录密码
PGADMIN_PORT=8080                    # PgAdmin端口

# 数据目录配置
POSTGRES_DATA_DIR=/home/data/postgres # PostgreSQL数据存储目录
PGADMIN_DATA_DIR=/home/data/pgadmin   # PgAdmin数据存储目录
BACKUP_DIR=/usr/data/backups          # 备份文件存储目录

# 网络配置
ALLOW_REMOTE_ACCESS=true              # 是否允许远程访问
POSTGRES_HOST=0.0.0.0                # PostgreSQL监听地址
PGADMIN_HOST=0.0.0.0                 # PgAdmin监听地址

# 备份配置
BACKUP_RETENTION_DAYS=7              # 备份保留天数
BACKUP_SCHEDULE="0 2 * * *"          # 定时备份计划 (每天凌晨2点)

# 日志配置
LOG_LEVEL=INFO                       # 日志级别
```

### Docker Compose 配置

主要配置项：
- **PostgreSQL 15 Alpine**: 轻量级数据库镜像
- **PgAdmin 4**: Web管理界面
- **数据持久化**: 使用主机目录挂载存储数据
  - PostgreSQL数据: `/home/data/postgres`
  - PgAdmin数据: `/home/data/pgadmin`
  - 备份文件: `/usr/data/backups`
- **网络隔离**: 自定义网络确保安全
- **健康检查**: 自动监控服务状态

## 🔧 高级功能

### 1. 远程连接测试

测试远程连接是否正常：

```bash
# 获取服务器IP地址
ip addr show | grep inet

# 测试PostgreSQL连接
psql -h <服务器IP> -p ${POSTGRES_PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB}

# 测试PgAdmin访问
curl -I http://<服务器IP>:${PGADMIN_PORT}

# 使用telnet测试端口连通性
telnet <服务器IP> ${POSTGRES_PORT}
telnet <服务器IP> ${PGADMIN_PORT}
```

### 2. 定时备份

设置定时备份任务：

```bash
# 设置定时备份 (每天凌晨2点)
./backup.sh setup-cron

# 查看定时任务
crontab -l

# 移除定时备份
./backup.sh remove-cron
```

### 2. 数据迁移

从其他PostgreSQL实例迁移数据：

```bash
# 1. 备份源数据库
pg_dump -h source_host -U source_user source_db > migration.sql

# 2. 恢复数据到新实例
./backup.sh restore migration.sql
```

### 3. 性能优化

在 `docker-compose.yml` 中可以添加PostgreSQL性能优化参数：

```yaml
environment:
  # 性能优化参数
  POSTGRES_SHARED_BUFFERS: 256MB
  POSTGRES_EFFECTIVE_CACHE_SIZE: 1GB
  POSTGRES_MAINTENANCE_WORK_MEM: 64MB
  POSTGRES_CHECKPOINT_COMPLETION_TARGET: 0.9
  POSTGRES_WAL_BUFFERS: 16MB
  POSTGRES_DEFAULT_STATISTICS_TARGET: 100
```

## 🛠️ 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tulpn | grep :${POSTGRES_PORT}
   
   # 修改.env文件中的端口配置
   POSTGRES_PORT=5433
   ```

2. **权限问题**
   ```bash
   # 给脚本添加执行权限
   chmod +x *.sh
   ```

3. **数据目录权限**
   ```bash
   # 修复数据目录权限
   sudo chown -R 999:999 /home/data/postgres
   sudo chown -R 5050:5050 /home/data/pgadmin
   sudo chmod -R 755 /usr/data/backups
   ```

4. **容器启动失败**
   ```bash
   # 查看详细日志
   docker compose logs postgres
   
   # 重启服务
   ./deploy.sh restart
   ```

### 日志查看

```bash
# 查看PostgreSQL日志
docker compose logs postgres

# 查看PgAdmin日志
docker compose logs pgadmin

# 实时查看日志
./deploy.sh logs
```

## 📊 监控和维护

### 1. 健康检查

服务包含自动健康检查，可以通过以下方式监控：

```bash
# 查看服务状态
./deploy.sh status

# 检查容器健康状态
docker compose ps
```

### 2. 性能监控

使用PgAdmin或命令行工具监控数据库性能：

```bash
# 连接到数据库
./db-manage.sh connect

# 查看数据库大小
./db-manage.sh show-size

# 查看活跃连接
SELECT * FROM pg_stat_activity;
```

### 3. 定期维护

建议定期执行以下维护任务：

```bash
# 每周备份
./backup.sh backup

# 清理旧备份
./backup.sh cleanup

# 检查数据库状态
./deploy.sh status
```

## 🔒 安全建议

1. **修改默认密码**: 部署后立即修改默认密码
2. **网络隔离**: 使用防火墙限制数据库访问
3. **定期备份**: 设置自动备份任务
4. **监控日志**: 定期检查访问日志
5. **更新镜像**: 定期更新Docker镜像

## 📝 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 📞 支持

如果您在使用过程中遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查项目的Issue列表
3. 创建新的Issue描述您的问题

---

**注意**: 这是一个生产就绪的PostgreSQL部署方案，但请根据您的具体需求调整配置参数。
