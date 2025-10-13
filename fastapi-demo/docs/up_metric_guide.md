# Prometheus `up` 指标完整指南

## 📊 `up` 指标是什么？

`up` 是 Prometheus 的**内置指标**，用于监控目标的健康状态。它不是由应用程序直接暴露的，而是由 Prometheus 服务器在抓取目标时自动生成的。

## 🔍 `up` 指标的工作原理

### 1. 自动生成机制

当 Prometheus 尝试抓取一个监控目标时：

1. **成功抓取**: 如果 Prometheus 能够成功连接到目标并获取指标，`up` 值设为 `1`
2. **抓取失败**: 如果连接失败、超时或返回错误，`up` 值设为 `0`

### 2. 抓取过程流程图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │    │   Target App    │    │   Time Series   │
│    Server       │    │   (app:38000)    │    │    Database     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │ 1. 尝试抓取            │                       │
         ├──────────────────────►│                       │
         │                       │                       │
         │                       │ 2. 返回指标数据        │
         │◄──────────────────────┤                       │
         │                       │                       │
         │ 3. 生成 up=1          │                       │
         ├───────────────────────┼──────────────────────►│
         │                       │                       │
         │ 4. 存储所有指标        │                       │
         ├───────────────────────┼──────────────────────►│
         │                       │                       │
         │ 5. 等待下次抓取        │                       │
         │ (10秒后)              │                       │
         └───────────────────────┴───────────────────────┘
```

### 3. 抓取失败流程

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │    │   Target App    │    │   Time Series   │
│    Server       │    │   (app:38000)    │    │    Database     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │ 1. 尝试抓取            │                       │
         ├──────────────────────►│                       │
         │                       │                       │
         │ 2. 连接超时/失败        │                       │
         │ (5秒后)               │                       │
         │                       │                       │
         │ 3. 生成 up=0          │                       │
         ├───────────────────────┼──────────────────────►│
         │                       │                       │
         │ 4. 存储 up=0          │                       │
         ├───────────────────────┼──────────────────────►│
         │                       │                       │
         │ 5. 等待下次抓取        │                       │
         │ (10秒后)              │                       │
         └───────────────────────┴───────────────────────┘
```

## 📋 `up` 指标的特征

### 1. 指标格式
```
up{job="job_name", instance="target:port"} value
```

### 2. 标签说明
- **`job`**: 抓取配置中的作业名称
- **`instance`**: 目标实例的地址和端口
- **其他标签**: 可能包含配置中定义的额外标签

### 3. 值含义
- **`1`**: 目标健康，可以正常抓取
- **`0`**: 目标不健康，无法抓取

## 🔧 在我们的系统中的表现

### 当前配置
```yaml
# configs/prometheus_config.yml
scrape_configs:
  - job_name: 'dual-service-app'
    static_configs:
      - targets: ['app:38000']
        labels:
          service: 'dual-service'
          components: 'api,data-processing'
    scrape_interval: 10s
    scrape_timeout: 5s
```

### 实际结果
```promql
up{job="dual-service-app", instance="app:38000", service="dual-service", components="api,data-processing"} = 1
```

## 📊 指标数据流

### 1. 应用指标 (由应用暴露)
```
app:38000/metrics 端点返回:
├── http_requests_total{endpoint="/search", method="GET", status_code="200"} 42
├── process_resident_memory_bytes 57143296
├── queue_depth{queue_name="default_queue"} 0
└── service_health_status{service_name="api_service"} 1.0
```

### 2. Prometheus 系统指标 (自动生成)
```
Prometheus 自动添加:
├── up{job="dual-service-app", instance="app:38000", service="dual-service"} 1
├── scrape_duration_seconds{job="dual-service-app", instance="app:38000"} 0.002
└── scrape_samples_scraped{job="dual-service-app", instance="app:38000"} 15
```

## ⏰ 时间线示例

```
时间轴: 00:00:00 ────────────────────────────────── 00:00:30

00:00:00  Prometheus 开始抓取 app:38000
00:00:00  ├─ 连接成功
00:00:00  ├─ 获取指标数据 (15个指标)
00:00:00  ├─ 生成 up=1
00:00:00  └─ 存储到时间序列数据库

00:00:10  Prometheus 再次抓取 app:38000
00:00:10  ├─ 连接成功
00:00:10  ├─ 获取指标数据 (15个指标)
00:00:10  ├─ 生成 up=1
00:00:10  └─ 存储到时间序列数据库

00:00:20  Prometheus 再次抓取 app:38000
00:00:20  ├─ 连接失败 (应用重启)
00:00:20  ├─ 超时 (5秒)
00:00:20  ├─ 生成 up=0
00:00:20  └─ 存储到时间序列数据库

00:00:30  Prometheus 再次抓取 app:38000
00:00:30  ├─ 连接成功 (应用恢复)
00:00:30  ├─ 获取指标数据 (15个指标)
00:00:30  ├─ 生成 up=1
00:00:30  └─ 存储到时间序列数据库
```

## 🎯 `up` 指标的用途

### 1. 服务健康监控
```promql
# 检查所有服务状态
up

# 检查特定服务
up{job="dual-service-app"}

# 计算健康率
avg(up) * 100
```

### 2. 告警规则
```yaml
# configs/alert_rules.yml
groups:
  - name: service_health
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} is down"
```

### 3. 仪表板监控
```promql
# 服务健康率面板
avg(up) * 100

# 按作业分组的健康状态
group by (job) (up)
```

## 🔍 验证 `up` 指标

### 1. 查看当前状态
```bash
curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result[] | {job: .metric.job, instance: .metric.instance, value: .value[1]}'
```

### 2. 在 Prometheus Web 界面
- 访问: http://localhost:9090
- 查询: `up`
- 查看结果

### 3. 检查抓取状态
- 访问: http://localhost:9090/targets
- 查看目标状态

## 📊 实际示例

### 1. 健康检查查询
```promql
# 所有服务健康状态
up

# 结果示例:
# up{job="dual-service-app", instance="app:38000"} = 1
# up{job="prometheus", instance="localhost:9090"} = 1
```

### 2. 健康率计算
```promql
# 服务健康率百分比
avg(up) * 100

# 结果: 100 (表示100%健康)
```

### 3. 按作业分组
```promql
# 按作业分组的健康状态
group by (job) (up)

# 结果:
# {job="dual-service-app"} = 1
# {job="prometheus"} = 1
```

## ⚠️ 重要注意事项

### 1. `up` 指标不在应用指标中
```bash
# 这个命令不会显示 up 指标
curl http://localhost:38000/metrics | grep up
# 结果: 空（因为 up 不是应用暴露的）
```

### 2. `up` 指标只在 Prometheus 中存在
- 应用程序的 `/metrics` 端点不包含 `up` 指标
- `up` 指标只存在于 Prometheus 的时间序列数据库中

### 3. 抓取间隔影响
```yaml
scrape_configs:
  - job_name: 'dual-service-app'
    scrape_interval: 10s  # 每10秒检查一次
    scrape_timeout: 5s    # 5秒超时
```

## 🚨 故障排查

### 1. `up=0` 的常见原因

#### 网络问题
```bash
# 检查网络连接
docker exec -it fastapi-demo-prometheus-1 ping app:38000
```

#### 服务未启动
```bash
# 检查服务状态
docker-compose ps
```

#### 端口问题
```bash
# 检查端口是否开放
docker exec -it fastapi-demo-app-1 netstat -tlnp
```

#### 指标端点问题
```bash
# 检查指标端点
curl http://localhost:38000/metrics
```

### 2. 调试步骤

#### 检查 Prometheus 配置
```bash
# 验证配置
docker-compose config

# 检查 Prometheus 日志
docker-compose logs prometheus
```

#### 检查目标状态
```bash
# 查看目标页面
open http://localhost:9090/targets
```

#### 手动测试抓取
```bash
# 模拟 Prometheus 抓取
curl -v http://app:38000/metrics
```

### 3. 故障排查流程图

```
问题: up=0
  │
  ▼
┌─────────────────┐
│ 检查网络连接     │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ 检查服务状态     │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ 检查指标端点     │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ 检查 Prometheus │
│ 配置和日志      │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ 检查目标页面     │
│ /targets        │
└─────────────────┘
```

## 🔄 与其他指标的区别

### 1. 应用指标 vs 系统指标

| 指标类型 | 来源 | 示例 | 用途 |
|---------|------|------|------|
| 应用指标 | 应用程序暴露 | `http_requests_total` | 业务监控 |
| 系统指标 | Prometheus 生成 | `up` | 基础设施监控 |

### 2. 我们的应用指标
```bash
# 应用暴露的指标
curl http://localhost:38000/metrics | grep -E "^[a-zA-Z]"

# 包括:
# - http_requests_total
# - process_resident_memory_bytes
# - queue_depth
# - service_health_status
```

### 3. Prometheus 系统指标
```promql
# Prometheus 自动生成的指标
up                    # 目标健康状态
scrape_duration_seconds  # 抓取耗时
scrape_samples_scraped   # 抓取的样本数
```

**`scrape_samples_scraped`**: 这个指标代表 target 暴露出来的 sample 数量，可用于查看采集到的数据量。

## 💡 最佳实践

### 1. 监控配置
```yaml
# 合理的抓取间隔
scrape_interval: 10s
scrape_timeout: 5s

# 合理的标签
labels:
  service: 'dual-service'
  environment: 'production'
```

### 2. 告警设置
```yaml
# 避免过于敏感的告警
- alert: ServiceDown
  expr: up == 0
  for: 1m  # 持续1分钟才告警
```

### 3. 仪表板设计
```promql
# 使用 up 指标创建健康状态面板
avg(up) * 100 as "Health Rate"
```

## 🎯 正确的PromQL语法规则

### 聚合函数
```promql
sum by (job) (up)
avg by (job) (up)
```

### 分组函数
```promql
group by (job) (up)
```

### 基础查询
```promql
up
up{job="dual-service-app"}
```

## 📚 总结

`up` 指标是 Prometheus 监控系统的基础，它：

1. **自动生成**: 由 Prometheus 服务器自动创建
2. **健康指示**: 反映监控目标的可用性
3. **告警基础**: 是服务健康告警的核心指标
4. **系统指标**: 不是应用程序直接暴露的指标
5. **实时更新**: 根据抓取结果实时更新

理解 `up` 指标的工作原理对于 Prometheus 监控至关重要！🎯
