# 项目结构说明

## 📁 目录结构

```
fastapi-demo/
├── configs/                          # 配置文件目录
│   ├── docker-compose.yml            # Docker编排配置（已移至根目录）
│   ├── prometheus_config.yml         # Prometheus配置
│   ├── alert_rules.yml              # 告警规则配置
│   ├── Dockerfile                   # 应用镜像构建文件
│   ├── requirements_monitoring.txt  # Python依赖包
│   └── prometheus_solutions.yml     # Prometheus配置示例
├── docs/                            # 文档目录
│   ├── project_structure.md         # 项目结构说明（本文件）
│   ├── up_metric_guide.md           # up指标完整指南
│   └── ...                          # 其他文档文件
├── scripts/                         # 脚本目录
│   ├── deployment/                  # 部署脚本
│   │   ├── deploy.sh               # 部署脚本
│   │   └── undeploy.sh             # 卸载脚本
│   ├── monitoring/                  # 监控脚本
│   │   ├── status.sh               # 状态检查脚本
│   │   └── clean_prometheus_data.sh # 数据清理脚本
│   └── backup/                      # 备份脚本
│       ├── backup.sh               # 备份脚本
│       └── restore.sh              # 恢复脚本
├── grafana/                         # Grafana配置
│   ├── dashboards/                 # 仪表板配置
│   └── datasources/                # 数据源配置
├── monitoring_implementation.py     # 主应用代码
├── main.py                         # 原始测试代码
├── docker-compose.yml              # Docker编排配置（根目录）
└── README.md                       # 项目说明
```

## 🎯 各目录说明

### **configs/** - 配置文件目录
包含所有系统配置文件：
- **prometheus_config.yml**: Prometheus监控配置
- **alert_rules.yml**: 告警规则定义
- **Dockerfile**: 应用容器构建配置
- **requirements_monitoring.txt**: Python依赖包列表
- **prometheus_solutions.yml**: Prometheus配置示例和最佳实践

### **docs/** - 文档目录
包含所有项目文档：
- **PROJECT_STRUCTURE.md**: 项目结构说明
- **QUICK_START.md**: 快速开始指南
- **MONITORING_GUIDE.md**: 监控系统使用指南
- **monitoring_design.md**: 监控指标设计文档
- **docker_volume_guide.md**: Docker卷管理指南

### **scripts/** - 脚本目录
按功能分类的自动化脚本：

#### **deployment/** - 部署脚本
- **deploy.sh**: 一键部署脚本
  - 检查依赖和配置
  - 构建应用镜像
  - 启动所有服务
  - 验证部署状态
- **undeploy.sh**: 卸载脚本
  - 停止和删除服务
  - 可选删除数据卷和镜像
  - 清理未使用资源

#### **monitoring/** - 监控脚本
- **status.sh**: 系统状态检查脚本
  - 检查服务运行状态
  - 验证监控目标
  - 显示关键指标
  - 生成健康报告
- **clean_prometheus_data.sh**: Prometheus数据清理脚本
  - 安全清理历史数据
  - 保留配置和脚本

#### **backup/** - 备份脚本
- **backup.sh**: 数据备份脚本
  - 备份数据卷
  - 备份配置文件
  - 支持压缩和增量备份
- **restore.sh**: 数据恢复脚本
  - 恢复数据卷
  - 恢复配置文件
  - 验证恢复结果

### **grafana/** - Grafana配置
- **dashboards/**: 预配置的仪表板
- **datasources/**: 数据源配置

## 🚀 快速使用

### **部署系统**
```bash
# 一键部署
./scripts/deployment/deploy.sh

# 查看状态
./scripts/monitoring/status.sh
```

### **管理服务**
```bash
# 停止服务
docker-compose stop

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f
```

### **备份恢复**
```bash
# 备份数据
./scripts/backup/backup.sh

# 恢复数据
./scripts/backup/restore.sh ./backups/monitoring_backup_20231010_120000
```

### **卸载系统**
```bash
# 保留数据卸载
./scripts/deployment/undeploy.sh

# 完全清理
./scripts/deployment/undeploy.sh -a
```

## 📋 配置文件说明

### **Docker Compose配置**
- 位置: `docker-compose.yml` (根目录)
- 作用: 定义所有服务的编排配置
- 包含: 应用服务、Prometheus、Grafana

### **Prometheus配置**
- 位置: `configs/prometheus_config.yml`
- 作用: 定义监控目标和抓取规则
- 包含: 目标配置、告警规则、数据保留策略

### **告警规则**
- 位置: `configs/alert_rules.yml`
- 作用: 定义告警条件和阈值
- 包含: 服务健康、性能指标、错误率告警

### **应用配置**
- 位置: `configs/Dockerfile`
- 作用: 定义应用容器构建过程
- 包含: 基础镜像、依赖安装、应用部署

## 🔧 自定义配置

### **修改监控目标**
编辑 `configs/prometheus_config.yml` 中的 `scrape_configs` 部分

### **调整告警阈值**
编辑 `configs/alert_rules.yml` 中的告警规则

### **添加新的监控指标**
在 `monitoring_implementation.py` 中添加新的Prometheus指标

### **自定义仪表板**
在 `grafana/dashboards/` 中添加新的仪表板配置

## 📚 相关文档

- [快速开始指南](quick_start.md)
- [监控系统使用指南](monitoring_guide.md)
- [监控指标设计文档](monitoring_design.md)
- [Docker卷管理指南](docker_volume_guide.md)
- [up指标完整指南](up_metric_guide.md)

## 🆘 故障排查

### **服务无法启动**
1. 检查配置文件语法: `docker-compose config`
2. 查看服务日志: `docker-compose logs [service_name]`
3. 检查端口占用: `netstat -tlnp | grep :38000`

### **监控数据异常**
1. 检查Prometheus目标状态: http://localhost:9090/targets
2. 验证指标端点: http://localhost:38000/metrics
3. 查看Prometheus日志: `docker-compose logs prometheus`

### **Grafana无法访问**
1. 检查Grafana服务状态: `docker-compose ps grafana`
2. 验证数据源配置: http://localhost:3000/datasources
3. 查看Grafana日志: `docker-compose logs grafana`
