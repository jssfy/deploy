# 新增监控指标说明文档

本文档详细说明了新增的监控指标，包括业务指标、稳定性指标和性能追踪指标。

## 目录

1. [业务指标：记忆相关](#业务指标记忆相关)
2. [稳定性指标](#稳定性指标)
3. [性能 & 追踪指标](#性能--追踪指标)
4. [Grafana Dashboard 配置](#grafana-dashboard-配置)
5. [API 端点说明](#api-端点说明)

---

## 业务指标：记忆相关

### 1. 记忆总量 (`memory_total`)

**指标类型**: Gauge  
**说明**: 各类记忆的总数量  
**Labels**:
- `memory_type`: 记忆类型（short_term, mid_term, long_term, memcell）

**PromQL 示例**:
```promql
# 查询所有类型的记忆总量
memory_total

# 查询短期记忆总量
memory_total{memory_type="short_term"}
```

---

### 2. 记忆日变化量 (`memory_daily_change`)

**指标类型**: Gauge  
**说明**: 记忆数量的日变化统计  
**Labels**:
- `memory_type`: 记忆类型
- `change_type`: 变化类型（increase/decrease）

**PromQL 示例**:
```promql
# 查询记忆增量
memory_daily_change{change_type="increase"}

# 查询特定类型的记忆减量
memory_daily_change{memory_type="short_term", change_type="decrease"}
```

---

### 3. Memcell按源类型统计 (`memcell_by_source_total`)

**指标类型**: Gauge  
**说明**: 按源消息类型统计的memcell数量  
**Labels**:
- `source_type`: 源消息类型（chat, note, document, image等）

**PromQL 示例**:
```promql
# 查询所有源类型的memcell数量
memcell_by_source_total

# 查询聊天消息产生的memcell数量
memcell_by_source_total{source_type="chat"}
```

---

### 4. 记忆相关用户数量 (`memory_users_total`)

**指标类型**: Gauge  
**说明**: 与各类记忆相关的用户数量  
**Labels**:
- `memory_type`: 记忆类型

**PromQL 示例**:
```promql
# 查询所有记忆类型的用户数
memory_users_total

# 查询长期记忆的用户数
memory_users_total{memory_type="long_term"}
```

---

### 5. 用户日变化量 (`memory_users_daily_change`)

**指标类型**: Gauge  
**说明**: 用户数量的日变化统计  
**Labels**:
- `memory_type`: 记忆类型
- `change_type`: 变化类型（increase/decrease）

**PromQL 示例**:
```promql
# 查询用户增量
memory_users_daily_change{change_type="increase"}
```

---

### 6. 记忆操作计数 (`memory_operations_total`)

**指标类型**: Counter  
**说明**: 记忆操作的总次数  
**Labels**:
- `operation_type`: 操作类型（create, update, delete, query）
- `memory_type`: 记忆类型
- `status`: 状态（success/failed）

**PromQL 示例**:
```promql
# 查询记忆创建操作的QPS
rate(memory_operations_total{operation_type="create"}[5m])

# 查询失败的操作
memory_operations_total{status="failed"}
```

---

## 稳定性指标

### 1. 实时QPS (`http_requests_qps`)

**指标类型**: Gauge  
**说明**: 实时的每秒请求数（按路径统计）  
**Labels**:
- `path`: 请求路径

**PromQL 示例**:
```promql
# 查询所有路径的QPS
http_requests_qps

# 查询特定路径的QPS
http_requests_qps{path="/memorize"}
```

---

### 2. 按状态码的QPS (`http_requests_qps_by_status`)

**指标类型**: Gauge  
**说明**: 按HTTP状态码统计的QPS  
**Labels**:
- `path`: 请求路径
- `status`: HTTP状态码

**PromQL 示例**:
```promql
# 查询成功请求的QPS
http_requests_qps_by_status{status="200"}

# 查询错误请求的QPS
http_requests_qps_by_status{status=~"4..|5.."}
```

---

### 3. CPU使用率 (`system_cpu_usage_percent`)

**指标类型**: Gauge  
**说明**: CPU使用率百分比  
**Labels**:
- `cpu`: CPU标识（total, cpu0, cpu1等）

**PromQL 示例**:
```promql
# 查询总体CPU使用率
system_cpu_usage_percent{cpu="total"}

# 查询各核心CPU使用率
system_cpu_usage_percent{cpu!="total"}
```

---

### 4. 内存使用情况

#### 内存使用量 (`system_memory_usage_bytes`)

**指标类型**: Gauge  
**说明**: 内存使用量（字节）  
**Labels**:
- `memory_type`: 内存类型（total, used, available, free）

#### 内存使用率 (`system_memory_usage_percent`)

**指标类型**: Gauge  
**说明**: 内存使用率百分比

**PromQL 示例**:
```promql
# 查询内存使用率
system_memory_usage_percent

# 查询已使用内存（转换为GB）
system_memory_usage_bytes{memory_type="used"} / 1024 / 1024 / 1024

# 查询可用内存百分比
(system_memory_usage_bytes{memory_type="available"} / system_memory_usage_bytes{memory_type="total"}) * 100
```

---

### 5. 磁盘使用情况

#### 磁盘使用量 (`system_disk_usage_bytes`)

**指标类型**: Gauge  
**说明**: 磁盘使用量（字节）  
**Labels**:
- `disk`: 磁盘标识
- `usage_type`: 使用类型（total, used, free）

#### 磁盘使用率 (`system_disk_usage_percent`)

**指标类型**: Gauge  
**说明**: 磁盘使用率百分比  
**Labels**:
- `disk`: 磁盘标识

**PromQL 示例**:
```promql
# 查询所有磁盘的使用率
system_disk_usage_percent

# 查询特定磁盘的使用率
system_disk_usage_percent{disk="sda1"}

# 查询磁盘剩余空间（转换为GB）
system_disk_usage_bytes{usage_type="free"} / 1024 / 1024 / 1024
```

---

### 6. 网络流量

#### 网络字节数 (`system_network_bytes_total`)

**指标类型**: Counter  
**说明**: 网络传输的总字节数  
**Labels**:
- `interface`: 网络接口名称
- `direction`: 方向（sent/received）

#### 网络包数 (`system_network_packets_total`)

**指标类型**: Counter  
**说明**: 网络传输的总包数  
**Labels**:
- `interface`: 网络接口名称
- `direction`: 方向（sent/received）

#### 网络错误 (`system_network_errors_total`)

**指标类型**: Counter  
**说明**: 网络错误总数  
**Labels**:
- `interface`: 网络接口名称
- `error_type`: 错误类型（send_errors/recv_errors）

**PromQL 示例**:
```promql
# 查询网络发送速率（MB/s）
rate(system_network_bytes_total{direction="sent"}[5m]) / 1024 / 1024

# 查询网络接收速率（MB/s）
rate(system_network_bytes_total{direction="received"}[5m]) / 1024 / 1024

# 查询网络错误率
rate(system_network_errors_total[5m])
```

---

## 性能 & 追踪指标

### 1. 队列任务状态

#### 队列任务总数 (`queue_tasks_total`)

**指标类型**: Gauge  
**说明**: 队列中各状态的任务总数  
**Labels**:
- `queue_name`: 队列名称
- `status`: 任务状态（pending, processing, completed, failed）

#### 待处理任务数 (`queue_tasks_pending`)

**指标类型**: Gauge  
**说明**: 队列中待处理的任务数  
**Labels**:
- `queue_name`: 队列名称

#### 处理中任务数 (`queue_tasks_processing`)

**指标类型**: Gauge  
**说明**: 队列中正在处理的任务数  
**Labels**:
- `queue_name`: 队列名称

**PromQL 示例**:
```promql
# 查询待处理任务数
queue_tasks_pending

# 查询处理中的任务数
queue_tasks_processing

# 查询失败任务数
queue_tasks_total{status="failed"}
```

---

### 2. 并发任务数量

#### 当前并发任务数 (`concurrent_tasks_count`)

**指标类型**: Gauge  
**说明**: 当前正在并发执行的任务数  
**Labels**:
- `task_type`: 任务类型

#### 最大并发数 (`concurrent_tasks_max`)

**指标类型**: Gauge  
**说明**: 允许的最大并发任务数  
**Labels**:
- `task_type`: 任务类型

**PromQL 示例**:
```promql
# 查询当前并发任务数
concurrent_tasks_count

# 计算并发使用率
(concurrent_tasks_count / concurrent_tasks_max) * 100
```

---

### 3. Memorize操作延迟

#### Memorize操作耗时 (`memorize_duration_seconds`)

**指标类型**: Histogram  
**说明**: Memorize操作的耗时分布（支持Pxx统计）  
**Labels**:
- `operation_type`: 操作类型（create, update, retrieve, delete）
- `status`: 状态（success/failed）

**Buckets**: [0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 10.0, 30.0]

#### Memorize操作计数 (`memorize_operations_total`)

**指标类型**: Counter  
**说明**: Memorize操作的总次数  
**Labels**:
- `operation_type`: 操作类型
- `memory_type`: 记忆类型
- `status`: 状态

#### Memorize并发数 (`memorize_concurrent`)

**指标类型**: Gauge  
**说明**: 当前并发执行的memorize操作数  
**Labels**:
- `operation_type`: 操作类型

**PromQL 示例**:
```promql
# P50延迟
histogram_quantile(0.50, rate(memorize_duration_seconds_bucket[5m]))

# P90延迟
histogram_quantile(0.90, rate(memorize_duration_seconds_bucket[5m]))

# P95延迟
histogram_quantile(0.95, rate(memorize_duration_seconds_bucket[5m]))

# P99延迟
histogram_quantile(0.99, rate(memorize_duration_seconds_bucket[5m]))

# Memorize操作QPS
rate(memorize_operations_total[5m])

# 按操作类型查询QPS
rate(memorize_operations_total{operation_type="create"}[5m])

# 查询当前并发数
memorize_concurrent
```

---

## Grafana Dashboard 配置

新的Dashboard包含以下面板：

### 基础监控面板（第1-4行）
1. **实时QPS（按路径）** - 展示各路径的实时QPS
2. **按状态码的QPS** - 展示不同状态码的QPS分布
3. **请求延迟分布** - 展示P50, P90, P95, P99延迟
4. **错误率** - 展示4xx和5xx错误率

### 业务指标面板（第5-8行）
5. **记忆总量（按类型）** - 展示各类记忆的数量
6. **记忆日变化量** - 展示记忆的增减趋势
7. **Memcell按源类型统计** - 展示不同源类型的memcell数量
8. **记忆相关用户数量** - 展示各类记忆关联的用户数

### 性能追踪面板（第9-10行）
9. **Memorize操作延迟（Pxx）** - 展示memorize操作的P50, P90, P95, P99延迟
10. **Memorize并发处理数** - 展示当前并发处理的memorize操作数

### 系统资源面板（第11-14行）
11. **CPU使用率** - 展示各CPU核心的使用率
12. **内存使用情况** - 展示内存使用率和使用量
13. **磁盘使用率** - 展示各磁盘的使用率
14. **网络流量** - 展示各网络接口的发送/接收流量

### 任务队列面板（第15-16行）
15. **队列任务状态** - 展示队列中各状态的任务数
16. **并发任务数量** - 展示当前并发数和最大并发数

### 其他指标面板（第17-18行）
17. **记忆操作QPS** - 展示记忆操作的QPS
18. **网络错误** - 展示网络错误率

---

## API 端点说明

### 1. POST /memorize

执行memorize操作（创建、更新、检索、删除记忆）

**参数**:
- `operation_type`: 操作类型（create, update, retrieve, delete），默认: create
- `memory_type`: 记忆类型（short_term, mid_term, long_term, memcell），默认: short_term
- `user_id`: 用户ID（可选）
- `source_type`: 源类型（可选，用于memcell）

**示例**:
```bash
# 创建短期记忆
curl -X POST "http://localhost:38000/memorize?operation_type=create&memory_type=short_term&user_id=123"

# 创建memcell（指定源类型）
curl -X POST "http://localhost:38000/memorize?operation_type=create&memory_type=memcell&user_id=456&source_type=chat"
```

---

### 2. GET /memory/stats

获取记忆统计信息

**返回示例**:
```json
{
  "memories": {
    "short_term": 100,
    "mid_term": 50,
    "long_term": 200,
    "memcell": 150
  },
  "users": {
    "short_term": 20,
    "mid_term": 15,
    "long_term": 30,
    "memcell": 25
  },
  "memcell_sources": {
    "chat": 60,
    "note": 40,
    "document": 30,
    "image": 20
  }
}
```

---

### 3. POST /tasks/add

添加任务到队列

**参数**:
- `task_id`: 任务ID（可选，不提供则自动生成）

**示例**:
```bash
curl -X POST "http://localhost:38000/tasks/add?task_id=task_001"
```

---

### 4. GET /system/stats

获取系统资源统计信息（需要安装psutil）

**返回示例**:
```json
{
  "cpu": {
    "percent": 45.2,
    "per_cpu": [42.1, 48.3, 44.5, 46.0]
  },
  "memory": {
    "total": 17179869184,
    "used": 8589934592,
    "percent": 50.0
  },
  "disk": [
    {
      "device": "/dev/sda1",
      "mountpoint": "/",
      "usage": 65.3
    }
  ]
}
```

---

## 使用建议

### 1. 告警配置建议

基于新增指标，建议配置以下告警：

#### 业务告警
```yaml
# 记忆数量异常增长
- alert: MemoryGrowthAbnormal
  expr: rate(memory_total[1h]) > 1000
  for: 5m
  annotations:
    summary: "记忆数量增长异常"

# Memorize操作延迟过高
- alert: MemorizeHighLatency
  expr: histogram_quantile(0.95, rate(memorize_duration_seconds_bucket[5m])) > 5
  for: 5m
  annotations:
    summary: "Memorize P95延迟超过5秒"
```

#### 系统资源告警
```yaml
# CPU使用率过高
- alert: HighCPUUsage
  expr: system_cpu_usage_percent{cpu="total"} > 80
  for: 5m
  annotations:
    summary: "CPU使用率超过80%"

# 内存使用率过高
- alert: HighMemoryUsage
  expr: system_memory_usage_percent > 90
  for: 5m
  annotations:
    summary: "内存使用率超过90%"

# 磁盘使用率过高
- alert: HighDiskUsage
  expr: system_disk_usage_percent > 85
  for: 5m
  annotations:
    summary: "磁盘使用率超过85%"
```

#### 性能告警
```yaml
# 队列积压
- alert: QueueBacklog
  expr: queue_tasks_pending > 100
  for: 5m
  annotations:
    summary: "队列待处理任务超过100个"

# 并发数接近上限
- alert: HighConcurrency
  expr: (concurrent_tasks_count / concurrent_tasks_max) > 0.9
  for: 5m
  annotations:
    summary: "并发任务数接近上限"
```

### 2. 性能优化建议

根据监控指标进行性能优化：

1. **通过P99延迟识别慢请求**
   ```promql
   histogram_quantile(0.99, rate(memorize_duration_seconds_bucket[5m])) by (operation_type)
   ```

2. **识别高QPS路径**
   ```promql
   topk(5, http_requests_qps)
   ```

3. **监控并发使用情况**
   ```promql
   concurrent_tasks_count / concurrent_tasks_max
   ```

### 3. 容量规划建议

使用这些指标进行容量规划：

1. **记忆增长趋势分析**
   ```promql
   # 计算日增长率
   deriv(memory_total[1d])
   ```

2. **资源使用趋势**
   ```promql
   # CPU趋势
   predict_linear(system_cpu_usage_percent{cpu="total"}[1h], 3600)
   
   # 内存趋势
   predict_linear(system_memory_usage_percent[1h], 3600)
   ```

3. **队列处理能力评估**
   ```promql
   # 任务处理速率
   rate(queue_tasks_total{status="completed"}[5m])
   
   # 平均处理时间
   rate(message_processing_duration_seconds_sum[5m]) / rate(message_processing_duration_seconds_count[5m])
   ```

---

## 依赖说明

新增指标需要安装以下Python包：

```txt
psutil>=5.9.0  # 用于系统资源监控
```

如果不安装psutil，系统资源指标将不会被收集，但不影响其他指标的正常工作。

---

## 总结

本次新增的监控指标全面覆盖了：

1. **业务维度** - 记忆数量、用户数、操作统计等
2. **稳定性维度** - CPU、内存、磁盘、网络、QPS等
3. **性能维度** - 队列任务、并发数、延迟分布等

这些指标可以帮助你：
- 实时了解系统运行状态
- 快速发现和定位问题
- 进行容量规划和性能优化
- 设置合理的告警阈值

建议定期检查Dashboard，关注关键指标的变化趋势。

