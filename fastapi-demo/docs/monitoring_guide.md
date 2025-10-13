# 双服务监控系统使用指南

## 概述

本监控系统为您的双服务架构提供了完整的监控解决方案：
- **对外API服务**：提供检索和写入接口
- **数据处理服务**：消费消息队列并处理数据

## 快速开始

### 1. 安装依赖

```bash
# 安装监控相关依赖
pip install -r requirements_monitoring.txt
```

### 2. 启动服务

#### 方式一：使用Docker Compose（推荐）

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f app
```

#### 方式二：手动启动

```bash
# 启动应用服务
python monitoring_implementation.py

# 启动Prometheus（需要单独安装）
prometheus --config.file=prometheus_config.yml

# 启动Grafana（需要单独安装）
grafana-server
```

### 3. 访问服务

- **应用服务**：http://localhost:38000
- **API文档**：http://localhost:38000/docs
- **监控指标**：http://localhost:38000/metrics
- **Prometheus**：http://localhost:9090
- **Grafana**：http://localhost:3000 (admin/admin)
- **健康检查**：http://localhost:38000/health

## 监控指标说明

### 对外API服务指标

#### HTTP请求指标
- `http_requests_total`：HTTP请求总数
- `http_request_duration_seconds`：请求处理时间
- `http_requests_in_flight`：当前并发请求数

#### 业务指标
- `search_requests_total`：检索请求总数
- `write_requests_total`：写入请求总数
- `search_duration_seconds`：检索操作耗时
- `write_duration_seconds`：写入操作耗时

#### 错误指标
- `http_4xx_errors_total`：4xx错误数
- `http_5xx_errors_total`：5xx错误数
- `business_exceptions_total`：业务异常数

### 数据处理服务指标

#### 消息队列指标
- `messages_consumed_total`：消费消息总数
- `messages_consumed_per_second`：消息消费速率
- `queue_depth`：队列深度
- `message_consumption_delay_seconds`：消费延迟

#### 处理指标
- `message_processing_duration_seconds`：消息处理时间
- `messages_processing_concurrent`：并发处理数

#### 存储指标
- `storage_operations_total`：存储操作总数
- `storage_operation_duration_seconds`：存储操作耗时
- `db_connections_active`：活跃数据库连接数
- `storage_errors_total`：存储错误数

### 系统指标
- `service_health_status`：服务健康状态
- `service_uptime_seconds`：服务运行时间
- `process_resident_memory_bytes`：内存使用量
- `process_cpu_seconds_total`：CPU使用时间

## 告警规则

系统预配置了以下告警规则：

### 关键告警（Critical）
- API服务错误率过高（5xx错误率 > 10%）
- 消息队列积压严重（队列深度 > 10000）
- 消息处理失败率过高（失败率 > 5%）
- 存储操作失败率过高（失败率 > 1%）
- 服务不健康

### 警告告警（Warning）
- API服务延迟过高（95%请求 > 2秒）
- 高并发请求数（并发数 > 1000）
- 消息消费延迟过高（95%延迟 > 5分钟）
- 内存使用过高（> 4GB）
- CPU使用率过高（> 80%）

## 测试监控系统

### 1. 测试API服务

```bash
# 测试检索接口
curl "http://localhost:38000/search?query_type=test&query=sample"

# 测试写入接口
curl -X POST "http://localhost:38000/write" \
  -H "Content-Type: application/json" \
  -d '{"data_type": "test", "data": {"key": "value"}}'

# 并发测试
for i in {1..100}; do
  curl "http://localhost:38000/search?query_type=test&query=sample$i" &
done
wait

for i in {1..100}; do
  curl -X POST "http://localhost:38000/write" \
  -H "Content-Type: application/json" \
  -d '{"data_type": "test", "data": {"key": "value"}}' &
done


```

### 2. 测试数据处理服务

```bash
# 模拟队列积压
curl -X POST "http://localhost:38000/simulate/queue?depth=5000"

# 查看监控指标
curl "http://localhost:38000/metrics" | grep queue_depth
```

### 3. 查看告警状态

访问 http://localhost:9090/alerts 查看当前告警状态。

## Grafana仪表板

### 导入预配置仪表板

1. 访问 http://localhost:3000
2. 使用 admin/admin 登录
3. 导入预配置的仪表板JSON文件

### 主要仪表板

1. **API服务概览**：显示API服务的QPS、延迟、错误率等
2. **数据处理服务概览**：显示消息队列状态、处理性能等
3. **系统资源监控**：显示CPU、内存、网络等系统指标
4. **告警中心**：显示当前活跃的告警信息

## 性能调优建议

### 1. 指标收集优化
- 合理设置指标标签，避免高基数
- 使用Histogram而不是Summary来收集延迟指标
- 定期清理不需要的指标

### 2. 告警规则优化
- 根据业务特点调整告警阈值
- 设置合理的告警持续时间
- 避免告警风暴

### 3. 存储优化
- 设置合适的数据保留时间
- 使用数据压缩减少存储空间
- 定期清理过期数据

## 故障排查

### 1. 服务无法启动
```bash
# 检查端口占用
netstat -tlnp | grep :38000

# 检查依赖服务
docker-compose ps
```

### 2. 指标收集异常
```bash
# 检查指标端点
curl "http://localhost:38000/metrics"

# 检查Prometheus配置
promtool check config prometheus_config.yml
```

### 3. 告警不生效
```bash
# 检查告警规则语法
promtool check rules alert_rules.yml

# 查看Prometheus日志
docker-compose logs prometheus
```

## 扩展功能

### 1. 添加自定义指标

```python
from prometheus_client import Counter, Histogram

# 自定义业务指标
custom_metric = Counter(
    'custom_business_metric_total',
    'Custom business metric',
    ['business_type', 'status']
)

# 在业务代码中使用
custom_metric.labels(business_type='order', status='success').inc()
```

### 2. 集成外部监控系统

- **ELK Stack**：用于日志分析
- **Jaeger**：用于分布式链路追踪
- **New Relic/DataDog**：用于APM监控

### 3. 自动化运维

- 集成CI/CD流水线
- 自动扩缩容
- 自动故障恢复

## 最佳实践

1. **监控即代码**：将监控配置纳入版本控制
2. **分层监控**：从基础设施到应用层的全面监控
3. **主动监控**：通过告警提前发现问题
4. **监控可视化**：使用仪表板直观展示系统状态
5. **定期演练**：定期进行监控和告警演练

## 支持与维护

- 定期更新监控组件版本
- 监控监控系统本身的健康状态
- 建立监控运维流程和文档
- 培训团队成员使用监控系统
