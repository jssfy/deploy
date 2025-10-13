# 双服务架构监控指标设计方案

## 架构概述

您的系统包含两个常驻服务：
1. **对外API服务**：提供检索接口和数据写入接口
2. **数据处理服务**：主动消费消息队列，并发处理数据并存储结果

## 1. 对外API服务监控指标

### 1.1 基础性能指标

#### 请求相关指标
- **请求总数** (`http_requests_total`)
  - 标签：`method`, `endpoint`, `status_code`
  - 类型：Counter
  - 描述：记录所有HTTP请求的总数

- **请求延迟** (`http_request_duration_seconds`)
  - 标签：`method`, `endpoint`, `status_code`
  - 类型：Histogram
  - 描述：记录请求处理时间分布

- **并发请求数** (`http_requests_in_flight`)
  - 标签：`endpoint`
  - 类型：Gauge
  - 描述：当前正在处理的请求数量

#### 业务相关指标
- **检索请求数** (`search_requests_total`)
  - 标签：`query_type`, `status`
  - 类型：Counter
  - 描述：检索接口调用次数

- **数据写入请求数** (`write_requests_total`)
  - 标签：`data_type`, `status`
  - 类型：Counter
  - 描述：数据写入接口调用次数

- **检索响应时间** (`search_duration_seconds`)
  - 标签：`query_type`
  - 类型：Histogram
  - 描述：检索操作耗时分布

- **写入响应时间** (`write_duration_seconds`)
  - 标签：`data_type`
  - 类型：Histogram
  - 描述：写入操作耗时分布

### 1.2 系统资源指标

- **CPU使用率** (`process_cpu_seconds_total`)
- **内存使用量** (`process_resident_memory_bytes`)
- **文件描述符使用数** (`process_open_fds`)
- **线程数** (`process_threads`)

### 1.3 错误和异常指标

- **4xx错误率** (`http_4xx_errors_total`)
- **5xx错误率** (`http_5xx_errors_total`)
- **业务异常数** (`business_exceptions_total`)
  - 标签：`exception_type`, `endpoint`

## 2. 数据处理服务监控指标

### 2.1 消息队列相关指标

#### 消费指标
- **消息消费总数** (`messages_consumed_total`)
  - 标签：`queue_name`, `status`
  - 类型：Counter
  - 描述：从队列消费的消息总数

- **消息消费速率** (`messages_consumed_per_second`)
  - 标签：`queue_name`
  - 类型：Gauge
  - 描述：当前消息消费速率

- **队列深度** (`queue_depth`)
  - 标签：`queue_name`
  - 类型：Gauge
  - 描述：队列中待处理消息数量

- **消费延迟** (`message_consumption_delay_seconds`)
  - 标签：`queue_name`
  - 类型：Histogram
  - 描述：消息从产生到被消费的时间

#### 处理指标
- **消息处理时间** (`message_processing_duration_seconds`)
  - 标签：`message_type`, `status`
  - 类型：Histogram
  - 描述：单个消息处理耗时分布

- **并发处理数** (`messages_processing_concurrent`)
  - 标签：`message_type`
  - 类型：Gauge
  - 描述：当前正在处理的消息数量

- **处理成功率** (`message_processing_success_rate`)
  - 标签：`message_type`
  - 类型：Gauge
  - 描述：消息处理成功率

### 2.2 数据存储指标

- **存储操作总数** (`storage_operations_total`)
  - 标签：`operation_type`, `table`, `status`
  - 类型：Counter

- **存储操作延迟** (`storage_operation_duration_seconds`)
  - 标签：`operation_type`, `table`
  - 类型：Histogram

- **数据库连接池状态** (`db_connections_active`)
  - 标签：`database`
  - 类型：Gauge

- **存储错误数** (`storage_errors_total`)
  - 标签：`error_type`, `table`
  - 类型：Counter

### 2.3 批处理指标

- **批处理大小** (`batch_size`)
  - 标签：`batch_type`
  - 类型：Histogram

- **批处理时间** (`batch_processing_duration_seconds`)
  - 标签：`batch_type`
  - 类型：Histogram

- **批处理吞吐量** (`batch_throughput_per_second`)
  - 标签：`batch_type`
  - 类型：Gauge

## 3. 通用系统指标

### 3.1 应用健康指标
- **服务健康状态** (`service_health_status`)
  - 标签：`service_name`
  - 类型：Gauge
  - 描述：0=不健康，1=健康

- **服务启动时间** (`service_start_time_seconds`)
  - 标签：`service_name`
  - 类型：Gauge

- **服务运行时长** (`service_uptime_seconds`)
  - 标签：`service_name`
  - 类型：Gauge

### 3.2 依赖服务指标
- **外部API调用** (`external_api_calls_total`)
  - 标签：`service`, `endpoint`, `status`
  - 类型：Counter

- **外部API延迟** (`external_api_duration_seconds`)
  - 标签：`service`, `endpoint`
  - 类型：Histogram

- **依赖服务健康状态** (`dependency_health_status`)
  - 标签：`dependency_name`
  - 类型：Gauge

## 4. 告警规则设计

### 4.1 关键告警规则

#### API服务告警
```yaml
# 高错误率告警
- alert: HighErrorRate
  expr: rate(http_5xx_errors_total[5m]) > 0.1
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "API服务错误率过高"

# 高延迟告警
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
  for: 3m
  labels:
    severity: warning
  annotations:
    summary: "API服务延迟过高"

# 高并发告警
- alert: HighConcurrency
  expr: http_requests_in_flight > 1000
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "API服务并发请求数过高"
```

#### 数据处理服务告警
```yaml
# 队列积压告警
- alert: QueueBacklog
  expr: queue_depth > 10000
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "消息队列积压严重"

# 处理失败率告警
- alert: HighProcessingFailureRate
  expr: rate(messages_consumed_total{status="failed"}[5m]) / rate(messages_consumed_total[5m]) > 0.05
  for: 3m
  labels:
    severity: critical
  annotations:
    summary: "消息处理失败率过高"

# 消费延迟告警
- alert: HighConsumptionDelay
  expr: histogram_quantile(0.95, rate(message_consumption_delay_seconds_bucket[5m])) > 300
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "消息消费延迟过高"
```

### 4.2 资源告警
```yaml
# 内存使用告警
- alert: HighMemoryUsage
  expr: process_resident_memory_bytes / 1024 / 1024 / 1024 > 4
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "服务内存使用过高"

# CPU使用告警
- alert: HighCPUUsage
  expr: rate(process_cpu_seconds_total[5m]) > 0.8
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "服务CPU使用率过高"
```

## 5. 监控仪表板设计

### 5.1 API服务仪表板
- **请求概览**：QPS、错误率、延迟分布
- **接口详情**：各接口的请求量、延迟、错误率
- **系统资源**：CPU、内存、网络使用情况
- **业务指标**：检索和写入操作的业务指标

### 5.2 数据处理服务仪表板
- **队列状态**：队列深度、消费速率、积压情况
- **处理性能**：处理时间、吞吐量、成功率
- **存储状态**：数据库连接、存储操作延迟
- **系统资源**：CPU、内存、线程使用情况

### 5.3 综合仪表板
- **服务健康状态**：所有服务的健康检查结果
- **依赖关系**：外部依赖服务的状态
- **业务指标趋势**：关键业务指标的时间序列
- **告警状态**：当前活跃的告警信息

## 6. 实施建议

### 6.1 监控工具选择
- **指标收集**：Prometheus
- **可视化**：Grafana
- **告警**：AlertManager
- **日志**：ELK Stack 或 Loki

### 6.2 实施步骤
1. 在代码中集成监控指标收集
2. 配置Prometheus抓取指标
3. 创建Grafana仪表板
4. 设置告警规则
5. 建立监控运维流程

### 6.3 最佳实践
- 指标命名遵循Prometheus规范
- 合理设置标签，避免高基数
- 定期审查和优化告警规则
- 建立监控数据的保留策略
- 定期进行监控演练
