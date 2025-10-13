# 双服务监控系统

一个完整的双服务架构监控解决方案，包含对外API服务和数据处理服务的监控指标收集、存储和可视化。

## 🚀 快速开始

### 一键部署
```bash
./scripts/deployment/deploy.sh
```

### 查看状态
```bash
./scripts/monitoring/status.sh
```

### 访问服务
- **应用服务**: http://localhost:38000
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

## 📁 项目结构

```
fastapi-demo/
├── configs/              # 配置文件
├── docs/                 # 文档
├── scripts/              # 脚本
│   ├── deployment/       # 部署脚本
│   ├── monitoring/       # 监控脚本
│   └── backup/          # 备份脚本
├── grafana/             # Grafana配置
└── monitoring_implementation.py  # 主应用
```

## 📚 文档

- [项目结构说明](docs/project_structure.md)
- [快速开始指南](docs/quick_start.md)
- [监控系统使用指南](docs/monitoring_guide.md)
- [监控指标设计文档](docs/monitoring_design.md)
- [up指标完整指南](docs/up_metric_guide.md)

## 🔧 管理命令

### 部署管理
```bash
# 部署系统
./scripts/deployment/deploy.sh

# 卸载系统
./scripts/deployment/undeploy.sh

# 完全清理
./scripts/deployment/undeploy.sh -a
```

### 监控管理
```bash
# 检查状态
./scripts/monitoring/status.sh

# 清理数据
./scripts/monitoring/clean_prometheus_data.sh
```

### 备份恢复
```bash
# 备份数据
./scripts/backup/backup.sh

# 恢复数据
./scripts/backup/restore.sh ./backups/monitoring_backup_xxx
```

## 🎯 功能特性

- ✅ **双服务监控**: API服务和数据处理服务
- ✅ **实时指标**: HTTP请求、业务指标、系统资源
- ✅ **告警系统**: 基于Prometheus的告警规则
- ✅ **可视化**: Grafana仪表板
- ✅ **自动化**: 一键部署、备份、恢复
- ✅ **容器化**: Docker Compose编排

## 📊 监控指标

### API服务指标
- HTTP请求总数、延迟、并发数
- 检索和写入请求统计
- 错误率和异常监控

### 数据处理服务指标
- 消息队列深度和消费速率
- 消息处理时间和成功率
- 数据存储操作统计

### 系统指标
- 服务健康状态
- 系统资源使用
- 运行时间统计

## 🛠️ 技术栈

- **应用框架**: FastAPI + Python
- **监控系统**: Prometheus + Grafana
- **容器化**: Docker + Docker Compose
- **指标收集**: prometheus-client
- **可视化**: Grafana仪表板

## 📝 许可证

MIT License
