import asyncio
import time
from fastapi import FastAPI
from typing import Dict, Union
import threading

app = FastAPI(title="FastAPI并发测试服务", description="用于验证FastAPI并发处理能力的极简服务")

# 全局计数器
request_counter = 0
counter_lock = threading.Lock()
start_time = time.time()

def increment_counter():
    """线程安全地增加计数器"""
    global request_counter
    with counter_lock:
        request_counter += 1
        return request_counter

@app.get("/")
async def root() -> Dict[str, Union[str, int]]:
    """根路径接口"""
    current_count = increment_counter()
    return {
        "message": "FastAPI并发测试服务正在运行",
        "request_count": current_count
    }

@app.get("/test")
async def test_concurrent() -> Dict[str, Union[str, float, int]]:
    """
    测试并发处理能力的接口
    模拟1ms的计算消耗
    """
    current_count = increment_counter()
    start_time = time.time()
    
    # 模拟1ms的计算消耗
    await asyncio.sleep(0.001)  # 1ms = 0.001秒
    
    end_time = time.time()
    processing_time = (end_time - start_time) * 1000  # 转换为毫秒
    
    return {
        "message": "请求处理完成",
        "processing_time_ms": round(processing_time, 3),
        "timestamp": time.time(),
        "request_count": current_count
    }

@app.get("/health")
async def health_check() -> Dict[str, Union[str, float, int]]:
    """健康检查接口"""
    current_count = increment_counter()
    return {
        "status": "healthy", 
        "timestamp": time.time(),
        "request_count": current_count
    }

@app.get("/stat")
async def get_statistics() -> Dict[str, Union[str, float, int]]:
    """获取服务统计信息接口"""
    current_time = time.time()
    uptime = current_time - start_time
    
    with counter_lock:
        total_requests = request_counter
    
    # 计算QPS (每秒请求数)
    qps = total_requests / uptime if uptime > 0 else 0
    
    return {
        "total_requests": total_requests,
        "uptime_seconds": round(uptime, 2),
        "qps": round(qps, 2),
        "current_timestamp": current_time,
        "service_start_time": start_time
    }

@app.get("/benchmark")
async def benchmark_test() -> Dict[str, str]:
    """专门用于性能测试的接口，返回固定长度响应"""
    increment_counter()  # 仍然计数，但不影响响应长度
    return {"status": "ok", "message": "benchmark test"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=38000)
