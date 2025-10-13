# 实际可用的Prometheus查询语句

## 📊 基于当前系统的实际查询

基于测试结果，以下是当前系统中实际可用的查询语句：

## ✅ 可用的查询

### 1. 服务健康检查

#### 检查所有服务状态
```promql
up
```
**结果**: 显示所有监控目标的状态

#### 服务健康率
```promql
avg(up) * 100
```
**结果**: 100% (所有服务健康)

### 2. HTTP请求指标

#### 总请求数
```promql
http_requests_total
```
**结果**: 显示所有HTTP请求的总数

#### 按接口分组的请求数
```promql
sum by (endpoint) (http_requests_total)
```
**结果**: 按接口路径统计请求数

#### 按状态码分组的请求数
```promql
sum by (status_code) (http_requests_total)
```
**结果**: 按HTTP状态码统计请求数

#### 总请求数聚合
```promql
sum(http_requests_total)
```
**结果**: 所有请求的总和

#### 每秒请求数 (RPS - Requests Per Second)
```promql
rate(http_requests_total[1m])
```
**结果**: 过去1分钟的平均每秒请求数

#### 每分钟请求数 (RPM - Requests Per Minute)
```promql
rate(http_requests_total[1m]) * 60
```
**结果**: 过去1分钟的平均每分钟请求数

#### 按接口分组的每秒请求数
```promql
sum by (endpoint) (rate(http_requests_total[1m]))
```
**结果**: 每个接口的每秒请求数

#### 按状态码分组的每秒请求数
```promql
sum by (status_code) (rate(http_requests_total[1m]))
```
**结果**: 每个状态码的每秒请求数

#### 总每秒请求数
```promql
sum(rate(http_requests_total[1m]))
```
**结果**: 所有接口的总每秒请求数

#### 5分钟平均每秒请求数
```promql
rate(http_requests_total[5m])
```
**结果**: 过去5分钟的平均每秒请求数，更平滑

#### 1小时平均每秒请求数
```promql
rate(http_requests_total[1h])
```
**结果**: 过去1小时的平均每秒请求数，最平滑

## ⚠️ 重要说明：为什么QPS查询可能显示0

### 问题原因
当您看到 `rate(http_requests_total[1m])` 返回0时，通常是因为：

1. **时间窗口问题**: 请求发生在1分钟时间窗口之前
2. **数据点不足**: 需要至少2个数据点才能计算rate
3. **计数器重置**: 应用重启导致计数器重置

### 解决方案

#### 1. 使用更长的时间窗口
```promql
# 使用5分钟窗口，更可能包含历史数据
rate(http_requests_total[5m])

# 使用10分钟窗口
rate(http_requests_total[10m])
```

#### 2. 使用increase函数查看增量
```promql
# 查看过去1分钟的请求增量
increase(http_requests_total[1m])

# 查看过去5分钟的请求增量
increase(http_requests_total[5m])
```

#### 3. 查看总请求数确认数据存在
```promql
# 先确认总请求数不为0
http_requests_total

# 然后计算rate
rate(http_requests_total[5m])
```

#### 4. 实时测试方法
```bash
# 1. 先发送一些请求
for i in {1..10}; do
  curl "http://localhost:8000/search?query=test$i" &
done

# 2. 立即查询（使用较短时间窗口）
rate(http_requests_total[30s])
```

### 实际示例
```promql
# 当前系统状态
http_requests_total{endpoint="/search"}  # 显示: 50

# 为什么rate返回0
rate(http_requests_total{endpoint="/search"}[1m])  # 显示: 0
# 原因: 这50个请求发生在1分钟之前

# 正确的查询方式
rate(http_requests_total{endpoint="/search"}[5m])  # 可能显示: 0.1
increase(http_requests_total{endpoint="/search"}[5m])  # 显示: 50
```

## ⚠️ 重要说明：为什么increase查询时间窗口太小时返回空

### 问题现象
```promql
# 返回空结果 []
increase(http_requests_total[10s])

# 返回有数据
increase(http_requests_total[20s])
```

### 根本原因

#### 1. **Prometheus数据抓取间隔**
```yaml
# configs/prometheus_config.yml
global:
  scrape_interval: 15s    # 全局抓取间隔15秒

scrape_configs:
  - job_name: 'dual-service-app'
    scrape_interval: 10s  # 应用服务抓取间隔10秒
```

#### 2. **数据点要求**
- `increase()` 函数需要**至少2个数据点**才能计算增量
- 如果时间窗口 < 抓取间隔，可能只有1个或0个数据点
- 没有足够数据点 = 返回空结果

#### 3. **时间窗口计算**
```
抓取间隔: 10秒
时间窗口: 10秒
数据点: 可能只有1个 → 返回空

抓取间隔: 10秒  
时间窗口: 20秒
数据点: 2-3个 → 有结果
```

### 解决方案

#### 1. **使用合适的时间窗口**
```promql
# ❌ 太小，可能返回空
increase(http_requests_total[5s])
increase(http_requests_total[10s])

# ✅ 合适，有结果
increase(http_requests_total[20s])
increase(http_requests_total[30s])
increase(http_requests_total[1m])
```

#### 2. **查看抓取间隔配置**
```bash
# 查看Prometheus配置
cat configs/prometheus_config.yml | grep scrape_interval
# 结果: scrape_interval: 10s
```

#### 3. **最佳实践时间窗口**
```promql
# 推荐使用抓取间隔的2-4倍
increase(http_requests_total[20s])  # 2倍抓取间隔
increase(http_requests_total[30s])  # 3倍抓取间隔
increase(http_requests_total[1m])   # 6倍抓取间隔
```

### 实际测试结果

```bash
# 10秒窗口 - 返回空
curl "http://localhost:9090/api/v1/query?query=increase(http_requests_total[10s])"
# 结果: {"data":{"result":[]}}

# 20秒窗口 - 有数据
curl "http://localhost:9090/api/v1/query?query=increase(http_requests_total[20s])"
# 结果: {"data":{"result":[...]}}
```

### 关键理解

1. **数据抓取频率**: Prometheus每10秒抓取一次数据
2. **计算要求**: increase()需要至少2个数据点
3. **时间窗口**: 必须 ≥ 2 × 抓取间隔才能保证有足够数据点
4. **推荐设置**: 使用抓取间隔的2-4倍作为最小时间窗口

### 配置优化建议

```yaml
# 如果需要更细粒度的监控
scrape_configs:
  - job_name: 'dual-service-app'
    scrape_interval: 5s    # 更频繁的抓取
    scrape_timeout: 3s
```

**总结**: 时间窗口小于抓取间隔的2倍时，increase()可能没有足够的数据点来计算增量，因此返回空结果！🎯

### 3. 系统资源指标

#### 内存使用量 (MB)
```promql
process_resident_memory_bytes / 1024 / 1024
```
**结果**: 
- 应用服务: ~54.5 MB
- Prometheus: ~91.7 MB

## 📊 系统指标来源说明

### `process_resident_memory_bytes` 指标来源

#### 1. **自动收集器**
这个指标来自 **Prometheus Client 的自动收集器**，不是我们手动定义的：

```python
# monitoring_implementation.py 中没有定义这个指标
# 它是由 prometheus_client 库自动提供的
```

#### 2. **Process Collector**
```python
from prometheus_client import PROCESS_COLLECTOR, PLATFORM_COLLECTOR

# PROCESS_COLLECTOR 自动收集进程相关指标
# PLATFORM_COLLECTOR 自动收集平台相关指标
```

#### 3. **自动收集的指标列表**
```bash
# 查看所有自动收集的进程指标
curl -s "http://localhost:8000/metrics" | grep -E "^# HELP.*process_"
```

结果包括：
- `process_resident_memory_bytes` - 常驻内存大小
- `process_virtual_memory_bytes` - 虚拟内存大小  
- `process_start_time_seconds` - 进程启动时间
- `process_cpu_seconds_total` - CPU使用时间
- `process_open_fds` - 打开的文件描述符数量
- `process_max_fds` - 最大文件描述符数量

#### 4. **指标含义**
```promql
# 常驻内存 (物理内存)
process_resident_memory_bytes  # 单位: 字节

# 转换为MB
process_resident_memory_bytes / 1024 / 1024

# 转换为GB  
process_resident_memory_bytes / 1024 / 1024 / 1024
```

#### 5. **实际数值**
```bash
# 当前应用的内存使用
process_resident_memory_bytes  # 58454016 字节
58454016 / 1024 / 1024        # ≈ 55.7 MB
```

### 其他自动收集的指标

#### **Python 相关指标**
```bash
# Python运行时信息
python_info{implementation="CPython",major="3",minor="12",patchlevel="11",version="3.12.11"} 1.0

# Python GC指标
python_gc_objects_collected_total{generation="0"} 25524.0
python_gc_objects_collected_total{generation="1"} 1234.0
python_gc_objects_collected_total{generation="2"} 567.0
```

#### **平台相关指标**
```bash
# 平台信息
platform_info{system="Darwin",release="24.5.0",version="Darwin Kernel Version 24.5.0",machine="arm64"} 1.0
```

### 如何禁用自动收集器

如果您不需要这些系统指标，可以禁用：

```python
from prometheus_client import start_http_server, CollectorRegistry
from prometheus_client import PROCESS_COLLECTOR, PLATFORM_COLLECTOR

# 创建自定义注册表
registry = CollectorRegistry()

# 移除自动收集器
registry.unregister(PROCESS_COLLECTOR)
registry.unregister(PLATFORM_COLLECTOR)

# 启动服务器时使用自定义注册表
start_http_server(8000, registry=registry)
```

### 总结

`process_resident_memory_bytes` 指标是：
1. **自动提供**: 由 prometheus_client 库自动收集
2. **无需定义**: 不需要在代码中手动创建
3. **系统级**: 反映Python进程的系统资源使用情况
4. **实时更新**: 随着进程运行自动更新

这些指标对于监控应用的系统资源使用非常有用！🎯

#### 文件描述符使用数
```promql
process_open_fds
```
**结果**: 
- 应用服务: 15个
- Prometheus: 14个

### 4. 消息队列指标

#### 队列深度
```promql
queue_depth
```
**结果**: 当前队列中的消息数量 (当前为0)

#### 最大队列深度
```promql
max(queue_depth)
```
**结果**: 历史最大队列深度

### 5. 服务运行时间

#### 服务运行时长 (秒)
```promql
time() - service_start_time_seconds
```
**结果**: 显示各服务的运行时长

#### 服务运行时长 (小时)
```promql
(time() - service_start_time_seconds) / 3600
```
**结果**: 显示各服务的运行时长（小时）

### 6. 指标统计

#### 指标数量
```promql
count(http_requests_total)
```
**结果**: HTTP请求指标的数量

## ⚠️ 当前不可用的查询

以下查询在当前系统中暂无数据，需要更多时间积累或触发相应操作：

### 1. 速率查询 (需要时间积累)
```promql
# 这些查询需要至少5分钟的数据积累
rate(http_requests_total[5m])
rate(http_request_duration_seconds_sum[5m])
rate(process_cpu_seconds_total[5m])
```

### 2. 延迟查询 (需要时间积累)
```promql
# 需要histogram数据积累
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

### 3. 业务指标 (需要触发业务操作)
```promql
# 需要访问/search和/write接口
search_requests_total
write_requests_total
rate(search_requests_total[5m])
rate(write_requests_total[5m])
```

### 4. 错误指标 (需要产生错误)
```promql
# 需要产生4xx或5xx错误
http_4xx_errors_total
http_5xx_errors_total
rate(http_4xx_errors_total[5m])
rate(http_5xx_errors_total[5m])
```

### 5. 消息处理指标 (需要消息处理)
```promql
# 需要消息队列操作
messages_consumed_total
rate(messages_consumed_total[5m])
histogram_quantile(0.95, rate(message_processing_duration_seconds_bucket[5m]))
```

## 🚀 如何生成更多数据

### 1. 触发HTTP请求
```bash
# 访问不同接口生成请求数据
curl http://localhost:8000/search
curl http://localhost:8000/write
curl http://localhost:8000/simulate/queue
```

### 2. 生成错误请求
```bash
# 生成4xx错误
curl http://localhost:8000/nonexistent

ab -n 100 -c 4 http://localhost:8000/nonexistent

# 生成5xx错误 (如果应用有错误处理)
curl -X POST http://localhost:8000/write -d '{"invalid": "data"}'


```

### 3. 等待数据积累
```bash
# 等待5-10分钟让Prometheus收集足够的数据
# 然后重新运行查询测试
./scripts/monitoring/test_queries.sh
```

## 📈 实用的实时查询

### 1. 当前系统状态
```promql
# 服务健康状态
up

# 内存使用情况
process_resident_memory_bytes / 1024 / 1024

# 文件描述符使用
process_open_fds

# 队列状态
queue_depth
```

### 2. 请求统计
```promql
# 总请求数
sum(http_requests_total)

# 按接口统计
sum by (endpoint) (http_requests_total)

# 按状态码统计
sum by (status_code) (http_requests_total)
```

### 3. 服务运行时间
```promql
# 运行时长（小时）
(time() - service_start_time_seconds) / 3600
```

## 🔍 在Prometheus Web界面中使用

1. 打开 http://localhost:9090
2. 在查询框中输入上述查询语句
3. 点击"Execute"执行查询
4. 查看结果和图表

## 📊 在Grafana中创建仪表板

可以使用以下查询创建仪表板面板：

### 概览面板
```promql
# 服务健康率
avg(up) * 100

# 总请求数
sum(http_requests_total)

# 内存使用
process_resident_memory_bytes / 1024 / 1024

# 队列深度
queue_depth
```

### 请求详情面板
```promql
# 按接口统计
sum by (endpoint) (http_requests_total)

# 按状态码统计
sum by (status_code) (http_requests_total)
```

## 💡 查询技巧

### 1. 使用标签过滤
```promql
# 只查看应用服务的指标
process_resident_memory_bytes{job="dual-service-app"}

# 只查看特定接口
http_requests_total{endpoint="/metrics"}
```

### 2. 使用聚合函数
```promql
# 求和
sum(http_requests_total)

# 最大值
max(queue_depth)

# 计数
count(http_requests_total)
```

### 3. 使用数学运算
```promql
# 内存使用量 (GB)
process_resident_memory_bytes / 1024 / 1024 / 1024

# 运行时长 (天)
(time() - service_start_time_seconds) / 3600 / 24
```

## 🎯 下一步建议

1. **生成更多数据**: 访问不同接口，产生各种类型的请求
2. **等待数据积累**: 让系统运行更长时间，积累更多历史数据
3. **创建Grafana仪表板**: 使用可用查询创建可视化仪表板
4. **设置告警**: 基于可用指标设置告警规则
5. **扩展监控**: 根据需要添加更多自定义指标
