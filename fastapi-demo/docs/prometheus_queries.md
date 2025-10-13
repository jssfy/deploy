# Prometheus查询指南

## 📊 概述

Prometheus提供了强大的PromQL查询语言，用于查询和聚合时间序列数据。本指南总结了双服务监控系统中的常用查询功能。

## 🎯 基础查询

### 1. 服务健康检查

#### 检查所有服务状态
```promql
up
```
**说明**: 返回所有监控目标的状态，1表示健康，0表示不健康

#### 检查特定服务状态
```promql
up{job="dual-service-app"}
```
**说明**: 只检查双服务应用的状态

#### 检查服务健康率
```promql
avg(up) * 100
```
**说明**: 计算服务健康率百分比

### 2. HTTP请求指标

#### 总请求数
```promql
http_requests_total
```
**说明**: 显示所有HTTP请求的总数

#### 按状态码分组的请求数
```promql
sum by (status_code) (http_requests_total)
```
**说明**: 按HTTP状态码统计请求数

#### 按接口分组的请求数
```promql
sum by (endpoint) (http_requests_total)
```
**说明**: 按接口路径统计请求数

#### 请求速率 (QPS)
```promql
rate(http_requests_total[5m])
```
**说明**: 计算过去5分钟的平均请求速率

#### 按接口的请求速率
```promql
sum by (endpoint) (rate(http_requests_total[5m]))
```
**说明**: 按接口计算请求速率

### 3. 请求延迟指标

#### 平均延迟
```promql
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```
**说明**: 计算过去5分钟的平均请求延迟

#### 95%延迟
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```
**说明**: 计算95%的请求延迟

#### 99%延迟
```promql
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```
**说明**: 计算99%的请求延迟

#### 延迟分布
```promql
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.90, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```
**说明**: 同时显示50%、90%、95%、99%的延迟

### 4. 错误率监控

#### 4xx错误率
```promql
rate(http_4xx_errors_total[5m])
```
**说明**: 计算4xx错误的发生速率

#### 5xx错误率
```promql
rate(http_5xx_errors_total[5m])
```
**说明**: 计算5xx错误的发生速率

#### 总错误率
```promql
rate(http_4xx_errors_total[5m]) + rate(http_5xx_errors_total[5m])
```
**说明**: 计算总错误率

#### 错误率百分比
```promql
(rate(http_5xx_errors_total[5m]) / rate(http_requests_total[5m])) * 100
```
**说明**: 计算5xx错误率百分比

### 5. 业务指标

#### 检索请求数
```promql
search_requests_total
```
**说明**: 显示检索请求总数

#### 检索请求速率
```promql
rate(search_requests_total[5m])
```
**说明**: 计算检索请求速率

#### 检索成功率
```promql
rate(search_requests_total{status="success"}[5m]) / rate(search_requests_total[5m]) * 100
```
**说明**: 计算检索成功率百分比

#### 写入请求数
```promql
write_requests_total
```
**说明**: 显示写入请求总数

#### 写入请求速率
```promql
rate(write_requests_total[5m])
```
**说明**: 计算写入请求速率

#### 写入成功率
```promql
rate(write_requests_total{status="success"}[5m]) / rate(write_requests_total[5m]) * 100
```
**说明**: 计算写入成功率百分比

### 6. 消息队列指标

#### 队列深度
```promql
queue_depth
```
**说明**: 显示当前队列中的消息数量

#### 消息消费总数
```promql
messages_consumed_total
```
**说明**: 显示已消费的消息总数

#### 消息消费速率
```promql
rate(messages_consumed_total[5m])
```
**说明**: 计算消息消费速率

#### 消息消费成功率
```promql
rate(messages_consumed_total{status="success"}[5m]) / rate(messages_consumed_total[5m]) * 100
```
**说明**: 计算消息消费成功率

#### 消息处理延迟
```promql
histogram_quantile(0.95, rate(message_processing_duration_seconds_bucket[5m]))
```
**说明**: 计算95%的消息处理延迟

### 7. 系统资源指标

#### 内存使用量
```promql
process_resident_memory_bytes
```
**说明**: 显示进程内存使用量（字节）

#### 内存使用量 (MB)
```promql
process_resident_memory_bytes / 1024 / 1024
```
**说明**: 显示进程内存使用量（MB）

#### CPU使用率
```promql
rate(process_cpu_seconds_total[5m]) * 100
```
**说明**: 计算CPU使用率百分比

#### 文件描述符使用数
```promql
process_open_fds
```
**说明**: 显示当前打开的文件描述符数量

#### 线程数
```promql
process_threads
```
**说明**: 显示当前线程数

### 8. 服务运行时间

#### 服务运行时长
```promql
time() - service_start_time_seconds
```
**说明**: 计算服务运行时长（秒）

#### 服务运行时长 (小时)
```promql
(time() - service_start_time_seconds) / 3600
```
**说明**: 计算服务运行时长（小时）

## 🔍 高级查询

### 1. 多维度聚合

#### 按服务和接口聚合请求数
```promql
sum by (job, endpoint) (http_requests_total)
```
**说明**: 按作业和接口聚合请求数

#### 按状态码和接口聚合错误数
```promql
sum by (status_code, endpoint) (http_4xx_errors_total + http_5xx_errors_total)
```
**说明**: 按状态码和接口聚合错误数

### 2. 时间范围查询

#### 过去1小时的请求数
```promql
increase(http_requests_total[1h])
```
**说明**: 计算过去1小时内增加的请求数

#### 过去1天的请求数
```promql
increase(http_requests_total[1d])
```
**说明**: 计算过去1天内增加的请求数

### 3. 条件查询

#### 高延迟请求 (>1秒)
```promql
rate(http_request_duration_seconds_bucket{le="+Inf"}[5m]) - rate(http_request_duration_seconds_bucket{le="1.0"}[5m])
```
**说明**: 计算延迟超过1秒的请求速率

#### 特定接口的请求
```promql
http_requests_total{endpoint="/search"}
```
**说明**: 只显示搜索接口的请求数

#### 特定状态码的请求
```promql
http_requests_total{status_code="200"}
```
**说明**: 只显示200状态码的请求数

### 4. 计算和比较

#### 请求增长率
```promql
(rate(http_requests_total[5m]) - rate(http_requests_total[5m] offset 1h)) / rate(http_requests_total[5m] offset 1h) * 100
```
**说明**: 计算请求增长率（与1小时前比较）

#### 延迟变化趋势
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) - histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m] offset 1h))
```
**说明**: 计算延迟变化（与1小时前比较）

## 📈 仪表板查询

### 1. 概览面板

#### 总QPS
```promql
sum(rate(http_requests_total[5m]))
```

#### 平均延迟
```promql
avg(rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]))
```

#### 错误率
```promql
sum(rate(http_5xx_errors_total[5m])) / sum(rate(http_requests_total[5m])) * 100
```

#### 服务健康率
```promql
avg(up) * 100
```

### 2. 接口详情面板

#### 各接口QPS
```promql
sum by (endpoint) (rate(http_requests_total[5m]))
```

#### 各接口延迟
```promql
histogram_quantile(0.95, sum by (endpoint) (rate(http_request_duration_seconds_bucket[5m])))
```

#### 各接口错误率
```promql
sum by (endpoint) (rate(http_5xx_errors_total[5m])) / sum by (endpoint) (rate(http_requests_total[5m])) * 100
```

### 3. 业务指标面板

#### 检索QPS
```promql
sum(rate(search_requests_total[5m]))
```

#### 写入QPS
```promql
sum(rate(write_requests_total[5m]))
```

#### 消息消费速率
```promql
sum(rate(messages_consumed_total[5m]))
```

#### 队列深度
```promql
sum(queue_depth)
```

## 🚨 告警查询

### 1. 高错误率告警
```promql
rate(http_5xx_errors_total[5m]) / rate(http_requests_total[5m]) > 0.1
```
**说明**: 5xx错误率超过10%

### 2. 高延迟告警
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
```
**说明**: 95%延迟超过2秒

### 3. 队列积压告警
```promql
queue_depth > 10000
```
**说明**: 队列深度超过10000

### 4. 服务不健康告警
```promql
up == 0
```
**说明**: 服务不健康

### 5. 高内存使用告警
```promql
process_resident_memory_bytes / 1024 / 1024 / 1024 > 4
```
**说明**: 内存使用超过4GB

## 💡 查询技巧

### 1. 使用标签选择器
```promql
# 精确匹配
http_requests_total{job="dual-service-app"}

# 正则匹配
http_requests_total{endpoint=~"/search|/write"}

# 排除匹配
http_requests_total{endpoint!="/health"}
```

### 2. 使用聚合函数
```promql
# 求和
sum(http_requests_total)

# 平均值
avg(http_request_duration_seconds)

# 最大值
max(queue_depth)

# 计数
count(http_requests_total)
```

### 3. 使用时间函数
```promql
# 当前时间
time()

# 时间偏移
http_requests_total offset 1h

# 时间范围
increase(http_requests_total[1h])
```

## 🔧 实用查询示例

### 1. 服务性能概览
```promql
# QPS
sum(rate(http_requests_total[5m]))

# 平均延迟
avg(rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]))

# 95%延迟
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# 错误率
sum(rate(http_5xx_errors_total[5m])) / sum(rate(http_requests_total[5m])) * 100
```

### 2. 业务指标概览
```promql
# 检索成功率
rate(search_requests_total{status="success"}[5m]) / rate(search_requests_total[5m]) * 100

# 写入成功率
rate(write_requests_total{status="success"}[5m]) / rate(write_requests_total[5m]) * 100

# 消息处理成功率
rate(messages_consumed_total{status="success"}[5m]) / rate(messages_consumed_total[5m]) * 100
```

### 3. 系统资源概览
```promql
# 内存使用 (GB)
process_resident_memory_bytes / 1024 / 1024 / 1024

# CPU使用率
rate(process_cpu_seconds_total[5m]) * 100

# 文件描述符使用率
process_open_fds / process_max_fds * 100
```

## 📚 参考资源

- [Prometheus官方文档](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [PromQL查询语言](https://prometheus.io/docs/prometheus/latest/querying/)
- [Prometheus查询示例](https://prometheus.io/docs/prometheus/latest/querying/examples/)
