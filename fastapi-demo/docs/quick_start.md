# 🚀 双服务监控系统快速开始指南

## 📊 服务状态

所有服务已成功启动并运行：

| 服务 | 地址 | 状态 | 说明 |
|------|------|------|------|
| **应用服务** | http://localhost:38000 | ✅ 运行中 | 双服务监控应用 |
| **Prometheus** | http://localhost:9090 | ✅ 运行中 | 指标收集和查询 |
| **Grafana** | http://localhost:3000 | ✅ 运行中 | 可视化仪表板 |

## 🎯 快速体验

### 1. 查看应用服务
```bash
# 健康检查
curl http://localhost:38000/health

# 查看API文档
open http://localhost:38000/docs

# 查看原始指标
curl http://localhost:38000/metrics
```

### 2. 使用Prometheus查询指标

#### 访问Prometheus Web界面
```bash
open http://localhost:9090
```

#### 常用查询语句
```promql
# 查看所有HTTP请求总数
http_requests_total

# 计算QPS（每秒请求数）
rate(http_requests_total[5m])

# 查看95%延迟
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# 查看错误率
rate(http_5xx_errors_total[5m])

# 查看消息队列深度
queue_depth

# 查看消息消费速率
rate(messages_consumed_total[5m])
```

#### 在Prometheus中测试查询
1. 访问 http://localhost:9090
2. 在查询框中输入上述查询语句
3. 点击"Execute"查看结果
4. 切换到"Graph"标签查看趋势图

### 3. 使用Grafana可视化

#### 登录Grafana
```bash
open http://localhost:3000
```
- 用户名：`admin`
- 密码：`admin`

#### 查看预配置仪表板
1. 登录后点击左侧菜单的"Dashboards"
2. 选择"API服务监控仪表板"
3. 查看各种监控指标的可视化图表

#### 创建自定义查询
1. 点击"+" → "Dashboard"
2. 点击"Add visualization"
3. 选择数据源为"Prometheus"
4. 输入PromQL查询语句
5. 配置图表类型和样式

## 📈 生成测试数据

### 生成API请求数据
```bash
# 并发检索请求
for i in {1..50}; do
  curl "http://localhost:38000/search?query_type=test&query=sample$i" &
done
wait

# 并发写入请求
for i in {1..30}; do
  curl -X POST "http://localhost:38000/write" \
    -H "Content-Type: application/json" \
    -d "{\"data_type\": \"test\", \"data\": {\"key\": \"value$i\"}}" &
done
wait
```

### 模拟消息队列数据
```bash
# 设置队列深度
curl -X POST "http://localhost:38000/simulate/queue?depth=100"

# 查看队列状态
curl "http://localhost:38000/metrics" | grep queue_depth
```

## 🔍 监控指标说明

### HTTP请求指标
- `http_requests_total`：HTTP请求总数
- `http_request_duration_seconds`：请求延迟分布
- `http_requests_in_flight`：当前并发请求数

### 业务指标
- `search_requests_total`：检索请求总数
- `write_requests_total`：写入请求总数
- `search_duration_seconds`：检索操作延迟
- `write_duration_seconds`：写入操作延迟

### 消息队列指标
- `messages_consumed_total`：消费消息总数
- `queue_depth`：队列深度
- `message_processing_duration_seconds`：消息处理延迟

### 系统指标
- `service_health_status`：服务健康状态
- `service_uptime_seconds`：服务运行时间

## 🎨 Grafana仪表板功能

### 预配置图表
1. **请求总数**：显示QPS趋势
2. **请求延迟**：显示95%和50%延迟
3. **错误率**：显示4xx和5xx错误趋势
4. **业务指标**：显示检索和写入请求速率

### 自定义仪表板
- 支持多种图表类型：时间序列、统计、表格等
- 支持告警配置
- 支持变量和模板
- 支持多数据源

## 🚨 告警配置

### 查看告警规则
```bash
# 访问Prometheus告警页面
open http://localhost:9090/alerts
```

### 主要告警规则
- **高错误率**：5xx错误率 > 10%
- **高延迟**：95%延迟 > 2秒
- **队列积压**：队列深度 > 10000
- **服务不健康**：健康检查失败

## 🛠️ 故障排查

### 检查服务状态
```bash
# 查看Docker容器状态
docker-compose ps

# 查看服务日志
docker-compose logs app
docker-compose logs prometheus
docker-compose logs grafana
```

### 检查指标收集
```bash
# 检查Prometheus目标状态
curl http://localhost:9090/api/v1/targets

# 检查指标是否正常收集
curl http://localhost:9090/api/v1/query?query=up
```

### 重启服务
```bash
# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart prometheus
```

## 📚 下一步

1. **自定义仪表板**：根据业务需求创建专门的监控面板
2. **配置告警**：设置邮件、Slack等告警通知
3. **扩展指标**：添加更多业务相关的监控指标
4. **性能调优**：根据监控数据优化服务性能
5. **集成其他工具**：集成日志分析、链路追踪等

## 🎉 恭喜！

您已经成功部署并运行了完整的双服务监控系统！现在可以：
- 实时监控服务性能
- 分析业务指标趋势
- 及时发现和解决问题
- 为系统优化提供数据支持

开始探索您的监控数据吧！🚀
