# PromQL 语法修正

## ❌ 错误的语法

### 1. 错误的 `by` 语法
```promql
# ❌ 错误 - up 不能直接使用 by
up by (job)

# 错误信息: parse error: unexpected <by>
```

## ✅ 正确的语法

### 1. 正确的分组语法
```promql
# ✅ 正确 - 使用 group by
group by (job) (up)

# ✅ 正确 - 使用 sum by (适用于聚合函数)
sum by (job) (up)

# ✅ 正确 - 使用 avg by (适用于聚合函数)
avg by (job) (up)
```

### 2. 验证结果
```bash
# 测试正确的语法
curl -s "http://localhost:9090/api/v1/query?query=group%20by%20(job)%20(up)" | jq '.data.result[]'
```

结果:
```json
{
  "metric": {"job": "dual-service-app"},
  "value": ["1760087915.031", "1"]
}
{
  "metric": {"job": "prometheus"},
  "value": ["1760087915.031", "1"]
}
```

## 📚 PromQL 语法规则

### 1. 聚合函数语法
```promql
# 聚合函数 + by + 标签列表 + (指标)
sum by (job, instance) (up)
avg by (job) (up)
max by (job) (up)
min by (job) (up)
count by (job) (up)
```

### 2. 分组函数语法
```promql
# group by + 标签列表 + (指标)
group by (job) (up)
group by (job, instance) (up)
```

### 3. 基础指标查询
```promql
# 直接查询指标
up
up{job="dual-service-app"}
up{job=~"dual-service.*"}
```

## 🔍 常用正确的查询

### 1. 服务健康检查
```promql
# 所有服务状态
up

# 特定服务状态
up{job="dual-service-app"}

# 服务健康率
avg(up) * 100
```

### 2. 按作业分组
```promql
# 按作业分组的健康状态
group by (job) (up)

# 按作业分组的健康率
avg by (job) (up) * 100
```

### 3. 聚合统计
```promql
# 总健康服务数
sum(up)

# 按作业统计健康服务数
sum by (job) (up)

# 健康服务数量
count(up)
```

## ⚠️ 常见语法错误

### 1. 错误的 by 使用
```promql
# ❌ 错误
up by (job)
http_requests_total by (endpoint)

# ✅ 正确
group by (job) (up)
sum by (endpoint) (http_requests_total)
```

### 2. 错误的聚合函数使用
```promql
# ❌ 错误 - 对单个指标使用 sum
sum(up)

# ✅ 正确 - 对多个指标使用 sum
sum(up)  # 实际上这个是正确的，会返回所有 up 指标的和
```

### 3. 错误的标签选择器
```promql
# ❌ 错误 - 标签值需要引号
up{job=dual-service-app}

# ✅ 正确
up{job="dual-service-app"}
```

## 🧪 测试语法

### 1. 使用 curl 测试
```bash
# 测试基础查询
curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.status'

# 测试分组查询
curl -s "http://localhost:9090/api/v1/query?query=group%20by%20(job)%20(up)" | jq '.status'

# 测试聚合查询
curl -s "http://localhost:9090/api/v1/query?query=sum%20by%20(job)%20(up)" | jq '.status'
```

### 2. 在 Prometheus Web 界面测试
1. 访问: http://localhost:9090
2. 在查询框输入查询语句
3. 点击 "Execute" 查看结果
4. 如果语法错误，会显示错误信息

## 📖 学习资源

### 1. PromQL 官方文档
- [PromQL 基础](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [PromQL 函数](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- [PromQL 操作符](https://prometheus.io/docs/prometheus/latest/querying/operators/)

### 2. 语法检查工具
```bash
# 使用 Prometheus API 检查语法
curl -s "http://localhost:9090/api/v1/query?query=YOUR_QUERY" | jq '.status'
```

## 💡 最佳实践

### 1. 语法验证
- 先在 Prometheus Web 界面测试
- 使用 curl 验证 API 查询
- 检查返回的 status 字段

### 2. 查询优化
- 使用合适的聚合函数
- 避免不必要的标签选择器
- 合理使用时间范围

### 3. 错误处理
- 检查语法错误信息
- 验证指标名称和标签
- 确认时间范围设置
