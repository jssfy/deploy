# FastAPI 并发测试服务

这是一个极简的FastAPI服务，用于验证FastAPI的并发处理能力。

## 功能特性

- 提供 `/test` 接口，模拟1ms的计算消耗
- 支持异步处理，验证并发能力
- 返回处理时间信息
- 包含健康检查接口
- 全局请求计数器，跟踪所有请求
- 统计接口 `/stat`，提供QPS等性能指标

## 安装和运行

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 启动服务

```bash
# 方式1：直接运行
uv run python main.py

# 方式2：使用uvicorn命令
uvicorn main:app --host 0.0.0.0 --port 38000 --reload
```

### 3. 访问服务

- 服务地址：http://localhost:38000
- API文档：http://localhost:38000/docs
- 健康检查：http://localhost:38000/health
- 统计信息：http://localhost:38000/stat

## 接口说明

### GET /test
测试并发处理能力的主要接口
- 模拟1ms的计算消耗
- 返回处理时间信息
- 支持并发请求

响应示例：
```json
{
  "message": "请求处理完成",
  "processing_time_ms": 1.234,
  "timestamp": 1703123456.789,
  "request_count": 42
}
```

### GET /stat
获取服务统计信息接口
- 返回总请求数、运行时间、QPS等统计信息
- 不增加请求计数器

响应示例：
```json
{
  "total_requests": 100,
  "uptime_seconds": 45.67,
  "qps": 2.19,
  "current_timestamp": 1703123456.789,
  "service_start_time": 1703123411.123
}
```

### GET /health
健康检查接口
- 返回服务状态和当前请求计数

响应示例：
```json
{
  "status": "healthy",
  "timestamp": 1703123456.789,
  "request_count": 43
}
```

## 并发测试

### 使用curl进行并发测试

```bash
# 单个请求测试
curl http://localhost:38000/test

# 并发请求测试（10个并发请求）
for i in {1..10}; do
  curl http://localhost:38000/test &
done
wait
```

### 使用Python进行并发测试

```python
import asyncio
import aiohttp
import time

async def test_concurrent():
    async with aiohttp.ClientSession() as session:
        start_time = time.time()
        
        # 创建100个并发请求
        tasks = []
        for i in range(100):
            task = session.get('http://localhost:38000/test')
            tasks.append(task)
        
        # 等待所有请求完成
        responses = await asyncio.gather(*tasks)
        
        end_time = time.time()
        total_time = end_time - start_time
        
        print(f"总请求数: {len(responses)}")
        print(f"总耗时: {total_time:.3f}秒")
        print(f"平均每个请求耗时: {total_time/len(responses)*1000:.3f}ms")
        print(f"QPS: {len(responses)/total_time:.2f}")

# 运行测试
asyncio.run(test_concurrent())
```

## 性能优化建议

1. **调整uvicorn工作进程数**：
   ```bash
   uvicorn main:app --workers 4
   ```

2. **使用Gunicorn + Uvicorn**：
   ```bash
   gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker
   ```

3. **调整系统限制**：
   - 增加文件描述符限制
   - 调整TCP连接参数

## 监控和调试

- 查看uvicorn日志了解请求处理情况
- 使用系统监控工具观察CPU和内存使用
- 通过返回的处理时间分析性能瓶颈
