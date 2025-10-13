# 新增监控指标快速开始

本文档将帮助你快速启动并验证新增的监控指标。

## 快速开始

### 1. 安装依赖

```bash
# 安装Python依赖
pip install -r requirements.txt

# 或者单独安装
pip install fastapi uvicorn prometheus-client psutil
```

**注意**: `psutil` 是可选的，用于系统资源监控。如果不安装，其他指标仍然可以正常工作。

### 2. 启动服务

```bash
# 启动监控服务
python monitoring_implementation.py
```

服务将在 http://localhost:38000 启动

### 3. 验证服务

在浏览器中访问以下地址：

- **API文档**: http://localhost:38000/docs
- **Prometheus指标**: http://localhost:38000/metrics
- **健康检查**: http://localhost:38000/health
- **记忆统计**: http://localhost:38000/memory/stats
- **系统统计**: http://localhost:38000/system/stats

### 4. 运行测试脚本

```bash
# 运行自动化测试
python test_new_metrics.py
```

测试脚本将：
- 测试所有API端点
- 生成测试数据
- 验证所有指标是否正常工作
- 显示指标统计信息

## 使用Docker Compose启动完整监控栈

### 1. 启动Prometheus和Grafana

```bash
cd configs
docker-compose up -d
```

这将启动：
- **FastAPI应用**: http://localhost:38000
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000

### 2. 配置Grafana

1. 访问 http://localhost:3000
2. 默认账号密码: admin/admin
3. 数据源已自动配置（Prometheus）
4. 导入Dashboard：
   - 进入 "Dashboards" → "Import"
   - 上传 `grafana/dashboards/api_service_dashboard.json`

## 指标分类

### 业务指标

```bash
# 查询记忆总量
curl http://localhost:38000/metrics | grep memory_total

# 查询记忆日变化
curl http://localhost:38000/metrics | grep memory_daily_change

# 查询memcell源类型统计
curl http://localhost:38000/metrics | grep memcell_by_source
```

### 稳定性指标

```bash
# 查询实时QPS
curl http://localhost:38000/metrics | grep http_requests_qps

# 查询CPU使用率
curl http://localhost:38000/metrics | grep system_cpu_usage

# 查询内存使用
curl http://localhost:38000/metrics | grep system_memory_usage
```

### 性能指标

```bash
# 查询队列任务
curl http://localhost:38000/metrics | grep queue_tasks

# 查询memorize延迟
curl http://localhost:38000/metrics | grep memorize_duration

# 查询并发数
curl http://localhost:38000/metrics | grep concurrent_tasks
```

## API使用示例

### 1. 创建记忆

```bash
# 创建短期记忆
curl -X POST "http://localhost:38000/memorize?operation_type=create&memory_type=short_term&user_id=123"

# 创建memcell（指定源类型）
curl -X POST "http://localhost:38000/memorize?operation_type=create&memory_type=memcell&user_id=456&source_type=chat"
```

### 2. 查询记忆统计

```bash
# 获取记忆统计
curl http://localhost:38000/memory/stats
```

返回示例：
```json
{
  "memories": {
    "short_term": 105,
    "mid_term": 52,
    "long_term": 203,
    "memcell": 165
  },
  "users": {
    "short_term": 23,
    "mid_term": 17,
    "long_term": 32,
    "memcell": 28
  },
  "memcell_sources": {
    "chat": 75,
    "note": 45,
    "document": 30,
    "image": 15
  }
}
```

### 3. 添加队列任务

```bash
# 添加任务
curl -X POST "http://localhost:38000/tasks/add?task_id=my_task_001"
```

### 4. 查询系统状态

```bash
# 获取系统资源使用情况
curl http://localhost:38000/system/stats
```

## Prometheus查询示例

访问 http://localhost:9090 并尝试以下查询：

### 基础查询

```promql
# 查询所有记忆类型的数量
memory_total

# 查询特定类型的记忆
memory_total{memory_type="short_term"}

# 查询实时QPS
http_requests_qps
```

### 聚合查询

```promql
# 总记忆数
sum(memory_total)

# 各类型记忆占比
memory_total / sum(memory_total)

# 总QPS
sum(http_requests_qps)
```

### 延迟分析

```promql
# Memorize操作P50延迟
histogram_quantile(0.50, rate(memorize_duration_seconds_bucket[5m]))

# Memorize操作P95延迟
histogram_quantile(0.95, rate(memorize_duration_seconds_bucket[5m]))

# Memorize操作P99延迟
histogram_quantile(0.99, rate(memorize_duration_seconds_bucket[5m]))
```

### 系统资源查询

```promql
# CPU使用率
system_cpu_usage_percent{cpu="total"}

# 内存使用率
system_memory_usage_percent

# 磁盘使用率
system_disk_usage_percent

# 网络发送速率（MB/s）
rate(system_network_bytes_total{direction="sent"}[5m]) / 1024 / 1024
```

### 趋势分析

```promql
# 记忆增长速率
rate(memory_total[1h])

# CPU使用趋势预测（1小时后）
predict_linear(system_cpu_usage_percent{cpu="total"}[1h], 3600)

# 队列处理速率
rate(queue_tasks_total{status="completed"}[5m])
```

## Grafana Dashboard 说明

新的Dashboard包含18个面板，分为以下几个部分：

### 第1-4行：基础监控
- 实时QPS（按路径）
- 按状态码的QPS
- 请求延迟分布（P50, P90, P95, P99）
- 错误率（4xx, 5xx）

### 第5-8行：业务指标
- 记忆总量（按类型）
- 记忆日变化量
- Memcell按源类型统计
- 记忆相关用户数量

### 第9-10行：性能追踪
- Memorize操作延迟（Pxx）
- Memorize并发处理数

### 第11-14行：系统资源
- CPU使用率
- 内存使用情况
- 磁盘使用率
- 网络流量

### 第15-16行：任务队列
- 队列任务状态
- 并发任务数量

### 第17-18行：其他指标
- 记忆操作QPS
- 网络错误

## 性能测试

### 1. 压力测试

使用 `ab` (Apache Bench) 进行压力测试：

```bash
# 测试根路径
ab -n 1000 -c 10 http://localhost:38000/

# 测试memorize端点
ab -n 500 -c 5 -p /dev/null -T "application/json" \
   "http://localhost:38000/memorize?operation_type=create&memory_type=short_term&user_id=123"
```

### 2. 使用 wrk 进行测试

```bash
# 安装wrk
# macOS: brew install wrk
# Linux: apt-get install wrk

# 运行测试
wrk -t4 -c100 -d30s http://localhost:38000/
```

### 3. 观察指标变化

在Grafana中观察以下指标的变化：
- QPS上升
- 延迟分布变化
- CPU和内存使用率
- 并发任务数

## 告警配置示例

在 Prometheus 中配置告警规则（`prometheus.yml` 或单独的规则文件）：

```yaml
groups:
  - name: business_alerts
    rules:
      # Memorize延迟过高
      - alert: MemorizeHighLatency
        expr: histogram_quantile(0.95, rate(memorize_duration_seconds_bucket[5m])) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Memorize操作延迟过高"
          description: "P95延迟超过5秒，当前值: {{ $value }}秒"

      # 记忆增长异常
      - alert: MemoryGrowthAbnormal
        expr: rate(memory_total[1h]) > 1000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "记忆数量异常增长"
          description: "记忆增长速率过快: {{ $value }}/小时"

  - name: system_alerts
    rules:
      # CPU使用率过高
      - alert: HighCPUUsage
        expr: system_cpu_usage_percent{cpu="total"} > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU使用率过高"
          description: "CPU使用率: {{ $value }}%"

      # 内存使用率过高
      - alert: HighMemoryUsage
        expr: system_memory_usage_percent > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "内存使用率过高"
          description: "内存使用率: {{ $value }}%"

      # 磁盘空间不足
      - alert: DiskSpaceLow
        expr: system_disk_usage_percent > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "磁盘空间不足"
          description: "{{ $labels.disk }} 使用率: {{ $value }}%"

  - name: performance_alerts
    rules:
      # 队列积压
      - alert: QueueBacklog
        expr: queue_tasks_pending > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "队列任务积压"
          description: "待处理任务数: {{ $value }}"

      # 并发接近上限
      - alert: HighConcurrency
        expr: (concurrent_tasks_count / concurrent_tasks_max) > 0.9
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "并发数接近上限"
          description: "并发使用率: {{ $value | humanizePercentage }}"
```

## 故障排查

### 1. 服务无法启动

```bash
# 检查端口是否被占用
lsof -i :38000

# 检查Python依赖
pip list | grep -E "fastapi|uvicorn|prometheus"
```

### 2. 系统指标不可用

```bash
# 安装psutil
pip install psutil

# 验证psutil是否工作
python -c "import psutil; print(psutil.cpu_percent())"
```

### 3. Prometheus无法抓取指标

```bash
# 检查metrics端点
curl http://localhost:38000/metrics

# 检查Prometheus配置
docker logs prometheus
```

### 4. Grafana无法显示数据

1. 检查Prometheus数据源配置
2. 验证查询语句是否正确
3. 检查时间范围设置

## 最佳实践

### 1. 指标采集频率

- QPS指标：每秒更新
- 系统资源：每5秒采集
- 日变化量：每小时更新一次

### 2. 数据保留策略

在Prometheus配置中设置：

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# 数据保留15天
storage:
  tsdb:
    retention.time: 15d
```

### 3. 性能优化建议

- 使用recording rules预计算常用查询
- 合理设置histogram buckets
- 定期清理旧数据
- 使用标签过滤减少查询范围

## 下一步

1. 根据实际业务需求调整指标
2. 配置告警规则和通知渠道
3. 创建自定义Dashboard
4. 集成到CI/CD流程
5. 定期审查和优化指标

## 相关文档

- [详细指标说明](./new_metrics_guide.md)
- [监控设计文档](./monitoring_design.md)
- [PromQL语法文档](./prometheus_queries.md)

## 问题反馈

如果遇到问题，请检查：
1. 服务日志
2. Prometheus targets页面
3. Grafana数据源连接状态
4. 防火墙设置

