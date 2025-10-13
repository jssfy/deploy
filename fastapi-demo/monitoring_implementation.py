"""
监控指标实现示例代码
包含对外API服务和数据处理服务的监控指标收集
"""

import time
import asyncio
from typing import Dict, Any
from prometheus_client import (
    Counter, Histogram, Gauge, start_http_server,
    CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST
)
from fastapi import FastAPI, Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import threading
from contextlib import asynccontextmanager
import logging
from collections import defaultdict, deque
from datetime import datetime, timedelta
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    logging.warning("psutil not available, system metrics will not be collected")

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==================== 对外API服务监控指标 ====================

# HTTP请求相关指标
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

http_request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint', 'status_code'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

http_requests_in_flight = Gauge(
    'http_requests_in_flight',
    'Current number of HTTP requests being processed',
    ['endpoint']
)

# 业务相关指标
search_requests_total = Counter(
    'search_requests_total',
    'Total search requests',
    ['query_type', 'status']
)

write_requests_total = Counter(
    'write_requests_total',
    'Total write requests',
    ['data_type', 'status']
)

search_duration = Histogram(
    'search_duration_seconds',
    'Search operation duration in seconds',
    ['query_type'],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

write_duration = Histogram(
    'write_duration_seconds',
    'Write operation duration in seconds',
    ['data_type'],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

# ==================== 业务指标：记忆相关 ====================

# 各类记忆数量
memory_total = Gauge(
    'memory_total',
    'Total count of memories',
    ['memory_type']  # 如: short_term, mid_term, long_term, memcell等
)

# 记忆日变化量
memory_daily_change = Gauge(
    'memory_daily_change',
    'Daily change in memory count',
    ['memory_type', 'change_type']  # change_type: increase/decrease
)

# 按源消息类型划分的memcell数量
memcell_by_source = Gauge(
    'memcell_by_source_total',
    'Total memcells by source message type',
    ['source_type']  # 如: chat, note, document, image等
)

# 记忆相关人员数量
memory_users_total = Gauge(
    'memory_users_total',
    'Total users associated with memories',
    ['memory_type']
)

# 人员日变化量
memory_users_daily_change = Gauge(
    'memory_users_daily_change',
    'Daily change in user count for memories',
    ['memory_type', 'change_type']
)

# 记忆操作计数
memory_operations_total = Counter(
    'memory_operations_total',
    'Total memory operations',
    ['operation_type', 'memory_type', 'status']  # operation_type: create, update, delete, query
)

# ==================== 稳定性指标 ====================

# QPS指标（按路径区分）
http_requests_qps = Gauge(
    'http_requests_qps',
    'Real-time QPS (queries per second)',
    ['path']
)

# 按状态码统计的QPS
http_requests_qps_by_status = Gauge(
    'http_requests_qps_by_status',
    'Real-time QPS by HTTP status code',
    ['path', 'status']
)

# 系统资源指标
system_cpu_usage = Gauge(
    'system_cpu_usage_percent',
    'System CPU usage percentage',
    ['cpu']  # 可以是 'total' 或 'cpu0', 'cpu1' 等
)

system_memory_usage = Gauge(
    'system_memory_usage_bytes',
    'System memory usage in bytes',
    ['memory_type']  # total, used, available, free
)

system_memory_usage_percent = Gauge(
    'system_memory_usage_percent',
    'System memory usage percentage'
)

system_disk_usage = Gauge(
    'system_disk_usage_bytes',
    'System disk usage in bytes',
    ['disk', 'usage_type']  # usage_type: total, used, free
)

system_disk_usage_percent = Gauge(
    'system_disk_usage_percent',
    'System disk usage percentage',
    ['disk']
)

system_network_bytes = Counter(
    'system_network_bytes_total',
    'Total network bytes',
    ['interface', 'direction']  # direction: sent/received
)

system_network_packets = Counter(
    'system_network_packets_total',
    'Total network packets',
    ['interface', 'direction']
)

system_network_errors = Counter(
    'system_network_errors_total',
    'Total network errors',
    ['interface', 'error_type']  # error_type: send_errors, recv_errors
)

# ==================== 性能 & 追踪指标 ====================

# 队列任务情况
queue_tasks_total = Gauge(
    'queue_tasks_total',
    'Total tasks in queue',
    ['queue_name', 'status']  # status: pending, processing, completed, failed
)

queue_tasks_pending = Gauge(
    'queue_tasks_pending',
    'Number of pending tasks in queue',
    ['queue_name']
)

queue_tasks_processing = Gauge(
    'queue_tasks_processing',
    'Number of currently processing tasks',
    ['queue_name']
)

# 并发任务数量
concurrent_tasks_count = Gauge(
    'concurrent_tasks_count',
    'Current number of concurrent tasks',
    ['task_type']
)

concurrent_tasks_max = Gauge(
    'concurrent_tasks_max',
    'Maximum concurrent tasks threshold',
    ['task_type']
)

# memorize操作耗时（支持pxx统计）
memorize_duration = Histogram(
    'memorize_duration_seconds',
    'Memorize operation duration in seconds',
    ['operation_type', 'status'],  # operation_type: create, update, retrieve, delete
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 10.0, 30.0]  # 支持p50, p90, p95, p99
)

# 更详细的memorize操作计数
memorize_operations_total = Counter(
    'memorize_operations_total',
    'Total memorize operations',
    ['operation_type', 'memory_type', 'status']
)

# memorize并发处理数
memorize_concurrent = Gauge(
    'memorize_concurrent',
    'Current number of concurrent memorize operations',
    ['operation_type']
)

# 错误指标
http_4xx_errors = Counter(
    'http_4xx_errors_total',
    'Total 4xx HTTP errors',
    ['endpoint', 'status_code']
)

http_5xx_errors = Counter(
    'http_5xx_errors_total',
    'Total 5xx HTTP errors',
    ['endpoint', 'status_code']
)

business_exceptions = Counter(
    'business_exceptions_total',
    'Total business exceptions',
    ['exception_type', 'endpoint']
)

# ==================== 数据处理服务监控指标 ====================

# 消息队列相关指标
messages_consumed_total = Counter(
    'messages_consumed_total',
    'Total messages consumed from queue',
    ['queue_name', 'status']
)

messages_consumed_per_second = Gauge(
    'messages_consumed_per_second',
    'Current message consumption rate',
    ['queue_name']
)

queue_depth = Gauge(
    'queue_depth',
    'Number of messages in queue',
    ['queue_name']
)

message_consumption_delay = Histogram(
    'message_consumption_delay_seconds',
    'Time from message creation to consumption',
    ['queue_name'],
    buckets=[1, 5, 10, 30, 60, 300, 600, 1800, 3600]
)

# 消息处理指标
message_processing_duration = Histogram(
    'message_processing_duration_seconds',
    'Message processing duration in seconds',
    ['message_type', 'status'],
    buckets=[0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 300.0]
)

messages_processing_concurrent = Gauge(
    'messages_processing_concurrent',
    'Current number of messages being processed',
    ['message_type']
)

# 数据存储指标
storage_operations_total = Counter(
    'storage_operations_total',
    'Total storage operations',
    ['operation_type', 'table', 'status']
)

storage_operation_duration = Histogram(
    'storage_operation_duration_seconds',
    'Storage operation duration in seconds',
    ['operation_type', 'table'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

db_connections_active = Gauge(
    'db_connections_active',
    'Active database connections',
    ['database']
)

storage_errors = Counter(
    'storage_errors_total',
    'Total storage errors',
    ['error_type', 'table']
)

# ==================== 通用系统指标 ====================

# 服务健康指标
service_health_status = Gauge(
    'service_health_status',
    'Service health status (0=unhealthy, 1=healthy)',
    ['service_name']
)

service_start_time = Gauge(
    'service_start_time_seconds',
    'Service start time in Unix timestamp',
    ['service_name']
)

service_uptime = Gauge(
    'service_uptime_seconds',
    'Service uptime in seconds',
    ['service_name']
)

# 依赖服务指标
external_api_calls = Counter(
    'external_api_calls_total',
    'Total external API calls',
    ['service', 'endpoint', 'status']
)

external_api_duration = Histogram(
    'external_api_duration_seconds',
    'External API call duration in seconds',
    ['service', 'endpoint'],
    buckets=[0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0]
)

dependency_health_status = Gauge(
    'dependency_health_status',
    'Dependency service health status',
    ['dependency_name']
)

# ==================== FastAPI中间件 ====================

class MetricsMiddleware(BaseHTTPMiddleware):
    """Prometheus指标收集中间件"""
    
    async def dispatch(self, request: Request, call_next):
        # 记录请求开始时间
        start_time = time.time()
        
        # 增加正在处理的请求数
        endpoint = request.url.path
        http_requests_in_flight.labels(endpoint=endpoint).inc()
        
        try:
            # 处理请求
            response = await call_next(request)
            
            # 记录请求指标
            duration = time.time() - start_time
            status_code = str(response.status_code)
            method = request.method
            
            http_requests_total.labels(
                method=method,
                endpoint=endpoint,
                status_code=status_code
            ).inc()
            
            http_request_duration.labels(
                method=method,
                endpoint=endpoint,
                status_code=status_code
            ).observe(duration)
            
            # 记录错误指标
            if 400 <= response.status_code < 500:
                http_4xx_errors.labels(
                    endpoint=endpoint,
                    status_code=status_code
                ).inc()
            elif response.status_code >= 500:
                http_5xx_errors.labels(
                    endpoint=endpoint,
                    status_code=status_code
                ).inc()
            
            return response
            
        except Exception as e:
            # 记录异常
            business_exceptions.labels(
                exception_type=type(e).__name__,
                endpoint=endpoint
            ).inc()
            raise
            
        finally:
            # 减少正在处理的请求数
            http_requests_in_flight.labels(endpoint=endpoint).dec()

# ==================== 对外API服务类 ====================

class APIService:
    """对外API服务，提供检索和写入接口"""
    
    def __init__(self):
        self.service_name = "api_service"
        self.start_time = time.time()
        service_start_time.labels(service_name=self.service_name).set(self.start_time)
        service_health_status.labels(service_name=self.service_name).set(1)
    
    async def search_data(self, query_type: str, query: str) -> Dict[str, Any]:
        """检索数据接口"""
        start_time = time.time()
        
        try:
            # 模拟检索操作
            await asyncio.sleep(0.1)  # 模拟检索耗时
            
            # 记录成功指标
            search_requests_total.labels(
                query_type=query_type,
                status="success"
            ).inc()
            
            return {"status": "success", "data": f"search result for {query}"}
            
        except Exception as e:
            # 记录失败指标
            search_requests_total.labels(
                query_type=query_type,
                status="failed"
            ).inc()
            raise
            
        finally:
            # 记录处理时间
            duration = time.time() - start_time
            search_duration.labels(query_type=query_type).observe(duration)
    
    async def write_data(self, data_type: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """写入数据接口"""
        start_time = time.time()
        
        try:
            # 模拟写入操作
            await asyncio.sleep(0.05)  # 模拟写入耗时
            
            # 记录成功指标
            write_requests_total.labels(
                data_type=data_type,
                status="success"
            ).inc()
            
            return {"status": "success", "message": "data written successfully"}
            
        except Exception as e:
            # 记录失败指标
            write_requests_total.labels(
                data_type=data_type,
                status="failed"
            ).inc()
            raise
            
        finally:
            # 记录处理时间
            duration = time.time() - start_time
            write_duration.labels(data_type=data_type).observe(duration)
    
    def update_uptime(self):
        """更新服务运行时间"""
        uptime = time.time() - self.start_time
        service_uptime.labels(service_name=self.service_name).set(uptime)

# ==================== 数据处理服务类 ====================

class DataProcessingService:
    """数据处理服务，消费消息队列并处理数据"""
    
    def __init__(self, queue_name: str = "default_queue"):
        self.service_name = "data_processing_service"
        self.queue_name = queue_name
        self.start_time = time.time()
        self.processing_count = 0
        self.processing_lock = threading.Lock()
        
        service_start_time.labels(service_name=self.service_name).set(self.start_time)
        service_health_status.labels(service_name=self.service_name).set(1)
    
    async def consume_messages(self):
        """消费消息队列"""
        while True:
            try:
                # 模拟从队列获取消息
                message = await self._get_message_from_queue()
                if message:
                    await self._process_message(message)
                else:
                    # 没有消息时短暂等待
                    await asyncio.sleep(0.1)
                    
            except Exception as e:
                logger.error(f"Error consuming messages: {e}")
                await asyncio.sleep(1)
    
    async def _get_message_from_queue(self) -> Dict[str, Any]:
        """从队列获取消息（模拟）"""
        # 模拟队列深度
        current_depth = queue_depth.labels(queue_name=self.queue_name)._value._value
        if current_depth > 0:
            queue_depth.labels(queue_name=self.queue_name).dec()
            return {
                "id": f"msg_{int(time.time())}",
                "type": "data_processing",
                "content": {"data": "sample data"},
                "created_at": time.time()
            }
        return None
    
    async def _process_message(self, message: Dict[str, Any]):
        """处理单个消息"""
        message_type = message.get("type", "unknown")
        start_time = time.time()
        
        # 增加并发处理计数
        with self.processing_lock:
            self.processing_count += 1
            messages_processing_concurrent.labels(message_type=message_type).set(self.processing_count)
        
        try:
            # 计算消费延迟
            consumption_delay = time.time() - message.get("created_at", time.time())
            message_consumption_delay.labels(queue_name=self.queue_name).observe(consumption_delay)
            
            # 模拟数据处理
            await asyncio.sleep(0.2)  # 模拟处理耗时
            
            # 模拟存储操作
            await self._store_result(message)
            
            # 记录成功指标
            messages_consumed_total.labels(
                queue_name=self.queue_name,
                status="success"
            ).inc()
            
            logger.info(f"Successfully processed message: {message['id']}")
            
        except Exception as e:
            # 记录失败指标
            messages_consumed_total.labels(
                queue_name=self.queue_name,
                status="failed"
            ).inc()
            logger.error(f"Failed to process message {message['id']}: {e}")
            
        finally:
            # 减少并发处理计数
            with self.processing_lock:
                self.processing_count -= 1
                messages_processing_concurrent.labels(message_type=message_type).set(self.processing_count)
            
            # 记录处理时间
            duration = time.time() - start_time
            message_processing_duration.labels(
                message_type=message_type,
                status="success" if self.processing_count >= 0 else "failed"
            ).observe(duration)
    
    async def _store_result(self, message: Dict[str, Any]):
        """存储处理结果（模拟）"""
        start_time = time.time()
        
        try:
            # 模拟存储操作
            await asyncio.sleep(0.05)
            
            # 记录存储操作指标
            storage_operations_total.labels(
                operation_type="insert",
                table="results",
                status="success"
            ).inc()
            
        except Exception as e:
            # 记录存储错误
            storage_operations_total.labels(
                operation_type="insert",
                table="results",
                status="failed"
            ).inc()
            storage_errors.labels(
                error_type=type(e).__name__,
                table="results"
            ).inc()
            raise
            
        finally:
            # 记录存储操作时间
            duration = time.time() - start_time
            storage_operation_duration.labels(
                operation_type="insert",
                table="results"
            ).observe(duration)
    
    def update_uptime(self):
        """更新服务运行时间"""
        uptime = time.time() - self.start_time
        service_uptime.labels(service_name=self.service_name).set(uptime)
    
    def simulate_queue_depth(self, depth: int):
        """模拟队列深度（用于测试）"""
        queue_depth.labels(queue_name=self.queue_name).set(depth)

# ==================== 新增功能类（需要在这里定义） ====================

class SystemMetricsCollector:
    """系统资源指标收集器"""
    
    def __init__(self):
        self.enabled = PSUTIL_AVAILABLE
        if not self.enabled:
            logger.warning("System metrics collector disabled - psutil not available")
    
    def collect_cpu_metrics(self):
        """收集CPU指标"""
        if not self.enabled:
            return
        
        try:
            # 总体CPU使用率
            cpu_percent = psutil.cpu_percent(interval=0.1)
            system_cpu_usage.labels(cpu='total').set(cpu_percent)
            
            # 各核心CPU使用率
            per_cpu = psutil.cpu_percent(interval=0.1, percpu=True)
            for idx, percent in enumerate(per_cpu):
                system_cpu_usage.labels(cpu=f'cpu{idx}').set(percent)
        except Exception as e:
            logger.error(f"Error collecting CPU metrics: {e}")
    
    def collect_memory_metrics(self):
        """收集内存指标"""
        if not self.enabled:
            return
        
        try:
            mem = psutil.virtual_memory()
            system_memory_usage.labels(memory_type='total').set(mem.total)
            system_memory_usage.labels(memory_type='used').set(mem.used)
            system_memory_usage.labels(memory_type='available').set(mem.available)
            system_memory_usage.labels(memory_type='free').set(mem.free)
            system_memory_usage_percent.set(mem.percent)
        except Exception as e:
            logger.error(f"Error collecting memory metrics: {e}")
    
    def collect_disk_metrics(self):
        """收集磁盘指标"""
        if not self.enabled:
            return
        
        try:
            # 获取所有磁盘分区
            partitions = psutil.disk_partitions()
            for partition in partitions:
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    disk_label = partition.device.split('/')[-1] if '/' in partition.device else partition.device
                    
                    system_disk_usage.labels(disk=disk_label, usage_type='total').set(usage.total)
                    system_disk_usage.labels(disk=disk_label, usage_type='used').set(usage.used)
                    system_disk_usage.labels(disk=disk_label, usage_type='free').set(usage.free)
                    system_disk_usage_percent.labels(disk=disk_label).set(usage.percent)
                except PermissionError:
                    continue
        except Exception as e:
            logger.error(f"Error collecting disk metrics: {e}")
    
    def collect_network_metrics(self):
        """收集网络指标"""
        if not self.enabled:
            return
        
        try:
            net_io = psutil.net_io_counters(pernic=True)
            for interface, counters in net_io.items():
                # 忽略回环接口
                if interface.startswith('lo'):
                    continue
                
                system_network_bytes.labels(interface=interface, direction='sent').inc(counters.bytes_sent)
                system_network_bytes.labels(interface=interface, direction='received').inc(counters.bytes_recv)
                
                system_network_packets.labels(interface=interface, direction='sent').inc(counters.packets_sent)
                system_network_packets.labels(interface=interface, direction='received').inc(counters.packets_recv)
                
                system_network_errors.labels(interface=interface, error_type='send_errors').inc(counters.errout)
                system_network_errors.labels(interface=interface, error_type='recv_errors').inc(counters.errin)
        except Exception as e:
            logger.error(f"Error collecting network metrics: {e}")
    
    def collect_all_metrics(self):
        """收集所有系统指标"""
        self.collect_cpu_metrics()
        self.collect_memory_metrics()
        self.collect_disk_metrics()
        self.collect_network_metrics()


class QPSCalculator:
    """QPS计算器"""
    
    def __init__(self, window_seconds: int = 60):
        self.window_seconds = window_seconds
        self.requests = defaultdict(lambda: deque())  # path -> deque of timestamps
        self.requests_by_status = defaultdict(lambda: defaultdict(lambda: deque()))  # path -> status -> deque
        self.lock = threading.Lock()
    
    def record_request(self, path: str, status: str):
        """记录一次请求"""
        now = time.time()
        with self.lock:
            self.requests[path].append(now)
            self.requests_by_status[path][status].append(now)
    
    def calculate_qps(self):
        """计算并更新QPS指标"""
        now = time.time()
        cutoff_time = now - self.window_seconds
        
        with self.lock:
            # 计算每个路径的总QPS
            for path, timestamps in self.requests.items():
                # 移除过期的时间戳
                while timestamps and timestamps[0] < cutoff_time:
                    timestamps.popleft()
                
                # 计算QPS
                qps = len(timestamps) / self.window_seconds
                http_requests_qps.labels(path=path).set(qps)
            
            # 计算按状态码分组的QPS
            for path, status_dict in self.requests_by_status.items():
                for status, timestamps in status_dict.items():
                    # 移除过期的时间戳
                    while timestamps and timestamps[0] < cutoff_time:
                        timestamps.popleft()
                    
                    # 计算QPS
                    qps = len(timestamps) / self.window_seconds
                    http_requests_qps_by_status.labels(path=path, status=status).set(qps)


class MemoryService:
    """记忆服务模拟类"""
    
    def __init__(self):
        self.memories = {
            'short_term': [],
            'mid_term': [],
            'long_term': [],
            'memcell': []
        }
        self.users = {
            'short_term': set(),
            'mid_term': set(),
            'long_term': set(),
            'memcell': set()
        }
        self.daily_stats = {}
        self.memcell_sources = defaultdict(int)
        self.lock = threading.Lock()
        
        # 初始化一些模拟数据
        self._initialize_mock_data()
    
    def _initialize_mock_data(self):
        """初始化模拟数据"""
        with self.lock:
            # 模拟一些记忆数据
            self.memories['short_term'] = list(range(100))
            self.memories['mid_term'] = list(range(50))
            self.memories['long_term'] = list(range(200))
            self.memories['memcell'] = list(range(150))
            
            # 模拟用户
            self.users['short_term'] = set(range(20))
            self.users['mid_term'] = set(range(15))
            self.users['long_term'] = set(range(30))
            self.users['memcell'] = set(range(25))
            
            # 模拟memcell源类型
            self.memcell_sources['chat'] = 60
            self.memcell_sources['note'] = 40
            self.memcell_sources['document'] = 30
            self.memcell_sources['image'] = 20
            
            self._update_metrics()
    
    def _update_metrics(self):
        """更新所有记忆相关指标"""
        # 更新记忆数量
        for memory_type, memories in self.memories.items():
            memory_total.labels(memory_type=memory_type).set(len(memories))
        
        # 更新用户数量
        for memory_type, users in self.users.items():
            memory_users_total.labels(memory_type=memory_type).set(len(users))
        
        # 更新memcell源类型统计
        for source_type, count in self.memcell_sources.items():
            memcell_by_source.labels(source_type=source_type).set(count)
    
    async def memorize(self, operation_type: str, memory_type: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """执行memorize操作（带指标记录）"""
        start_time = time.time()
        
        # 增加并发计数
        memorize_concurrent.labels(operation_type=operation_type).inc()
        
        try:
            # 模拟memorize操作
            await asyncio.sleep(0.1 + (asyncio.get_event_loop().time() % 0.3))  # 模拟0.1-0.4秒的处理时间
            
            with self.lock:
                if operation_type == 'create':
                    self.memories[memory_type].append(data)
                    if 'user_id' in data:
                        self.users[memory_type].add(data['user_id'])
                    
                    if memory_type == 'memcell' and 'source_type' in data:
                        self.memcell_sources[data['source_type']] += 1
                
                self._update_metrics()
            
            # 记录成功指标
            memorize_operations_total.labels(
                operation_type=operation_type,
                memory_type=memory_type,
                status='success'
            ).inc()
            
            memory_operations_total.labels(
                operation_type=operation_type,
                memory_type=memory_type,
                status='success'
            ).inc()
            
            return {"status": "success", "operation": operation_type}
            
        except Exception as e:
            # 记录失败指标
            memorize_operations_total.labels(
                operation_type=operation_type,
                memory_type=memory_type,
                status='failed'
            ).inc()
            
            memory_operations_total.labels(
                operation_type=operation_type,
                memory_type=memory_type,
                status='failed'
            ).inc()
            
            raise
            
        finally:
            # 减少并发计数
            memorize_concurrent.labels(operation_type=operation_type).dec()
            
            # 记录处理时间
            duration = time.time() - start_time
            memorize_duration.labels(
                operation_type=operation_type,
                status='success'
            ).observe(duration)
    
    def update_daily_changes(self):
        """更新日变化量（应该每天运行一次）"""
        with self.lock:
            today = datetime.now().date()
            
            for memory_type, memories in self.memories.items():
                current_count = len(memories)
                yesterday_key = f"{memory_type}_{today - timedelta(days=1)}"
                yesterday_count = self.daily_stats.get(yesterday_key, current_count)
                
                change = current_count - yesterday_count
                if change > 0:
                    memory_daily_change.labels(memory_type=memory_type, change_type='increase').set(abs(change))
                elif change < 0:
                    memory_daily_change.labels(memory_type=memory_type, change_type='decrease').set(abs(change))
                
                # 保存今天的统计
                today_key = f"{memory_type}_{today}"
                self.daily_stats[today_key] = current_count
            
            # 用户日变化量
            for memory_type, users in self.users.items():
                current_count = len(users)
                yesterday_key = f"users_{memory_type}_{today - timedelta(days=1)}"
                yesterday_count = self.daily_stats.get(yesterday_key, current_count)
                
                change = current_count - yesterday_count
                if change > 0:
                    memory_users_daily_change.labels(memory_type=memory_type, change_type='increase').set(abs(change))
                elif change < 0:
                    memory_users_daily_change.labels(memory_type=memory_type, change_type='decrease').set(abs(change))
                
                # 保存今天的统计
                today_key = f"users_{memory_type}_{today}"
                self.daily_stats[today_key] = current_count


class TaskQueueManager:
    """任务队列管理器"""
    
    def __init__(self, queue_name: str = "default", max_concurrent: int = 10):
        self.queue_name = queue_name
        self.max_concurrent = max_concurrent
        self.pending_tasks = []
        self.processing_tasks = []
        self.completed_tasks = []
        self.failed_tasks = []
        self.lock = threading.Lock()
        
        concurrent_tasks_max.labels(task_type=queue_name).set(max_concurrent)
    
    def add_task(self, task_id: str):
        """添加任务到队列"""
        with self.lock:
            self.pending_tasks.append(task_id)
            self._update_metrics()
    
    def start_task(self, task_id: str):
        """开始处理任务"""
        with self.lock:
            if task_id in self.pending_tasks:
                self.pending_tasks.remove(task_id)
                self.processing_tasks.append(task_id)
                self._update_metrics()
    
    def complete_task(self, task_id: str, success: bool = True):
        """完成任务"""
        with self.lock:
            if task_id in self.processing_tasks:
                self.processing_tasks.remove(task_id)
                if success:
                    self.completed_tasks.append(task_id)
                else:
                    self.failed_tasks.append(task_id)
                self._update_metrics()
    
    def _update_metrics(self):
        """更新队列指标"""
        queue_tasks_total.labels(queue_name=self.queue_name, status='pending').set(len(self.pending_tasks))
        queue_tasks_total.labels(queue_name=self.queue_name, status='processing').set(len(self.processing_tasks))
        queue_tasks_total.labels(queue_name=self.queue_name, status='completed').set(len(self.completed_tasks))
        queue_tasks_total.labels(queue_name=self.queue_name, status='failed').set(len(self.failed_tasks))
        
        queue_tasks_pending.labels(queue_name=self.queue_name).set(len(self.pending_tasks))
        queue_tasks_processing.labels(queue_name=self.queue_name).set(len(self.processing_tasks))
        
        concurrent_tasks_count.labels(task_type=self.queue_name).set(len(self.processing_tasks))


# 创建全局实例（在中间件之前）
system_metrics_collector = SystemMetricsCollector()
qps_calculator = QPSCalculator()
memory_service = MemoryService()
task_queue_manager = TaskQueueManager(queue_name="memorize_queue", max_concurrent=20)


# ==================== 更新中间件以支持QPS计算 ====================

class EnhancedMetricsMiddleware(BaseHTTPMiddleware):
    """增强的Prometheus指标收集中间件"""
    
    async def dispatch(self, request: Request, call_next):
        # 记录请求开始时间
        start_time = time.time()
        
        # 增加正在处理的请求数
        endpoint = request.url.path
        http_requests_in_flight.labels(endpoint=endpoint).inc()
        
        try:
            # 处理请求
            response = await call_next(request)
            
            # 记录请求指标
            duration = time.time() - start_time
            status_code = str(response.status_code)
            method = request.method
            
            http_requests_total.labels(
                method=method,
                endpoint=endpoint,
                status_code=status_code
            ).inc()
            
            http_request_duration.labels(
                method=method,
                endpoint=endpoint,
                status_code=status_code
            ).observe(duration)
            
            # 记录QPS
            qps_calculator.record_request(endpoint, status_code)
            
            # 记录错误指标
            if 400 <= response.status_code < 500:
                http_4xx_errors.labels(
                    endpoint=endpoint,
                    status_code=status_code
                ).inc()
            elif response.status_code >= 500:
                http_5xx_errors.labels(
                    endpoint=endpoint,
                    status_code=status_code
                ).inc()
            
            return response
            
        except Exception as e:
            # 记录异常
            business_exceptions.labels(
                exception_type=type(e).__name__,
                endpoint=endpoint
            ).inc()
            raise
            
        finally:
            # 减少正在处理的请求数
            http_requests_in_flight.labels(endpoint=endpoint).dec()


# ==================== FastAPI应用 ====================

# 创建服务实例
api_service = APIService()
data_processing_service = DataProcessingService()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时
    logger.info("Starting services...")
    
    # 启动数据处理服务
    processing_task = asyncio.create_task(data_processing_service.consume_messages())
    
    # 启动指标更新任务
    async def update_metrics():
        while True:
            api_service.update_uptime()
            data_processing_service.update_uptime()
            await asyncio.sleep(10)  # 每10秒更新一次
    
    # 启动QPS计算任务
    async def update_qps():
        while True:
            qps_calculator.calculate_qps()
            await asyncio.sleep(1)  # 每1秒计算一次QPS
    
    # 启动系统指标收集任务
    async def collect_system_metrics():
        while True:
            system_metrics_collector.collect_all_metrics()
            await asyncio.sleep(5)  # 每5秒收集一次系统指标
    
    # 启动日变化量更新任务
    async def update_daily_changes():
        while True:
            memory_service.update_daily_changes()
            await asyncio.sleep(3600)  # 每小时更新一次（实际应用中可以设置为每天更新一次）
    
    metrics_task = asyncio.create_task(update_metrics())
    qps_task = asyncio.create_task(update_qps())
    system_metrics_task = asyncio.create_task(collect_system_metrics())
    daily_changes_task = asyncio.create_task(update_daily_changes())
    
    yield
    
    # 关闭时
    logger.info("Shutting down services...")
    processing_task.cancel()
    metrics_task.cancel()
    qps_task.cancel()
    system_metrics_task.cancel()
    daily_changes_task.cancel()
    
    try:
        await processing_task
        await metrics_task
        await qps_task
        await system_metrics_task
        await daily_changes_task
    except asyncio.CancelledError:
        pass

# 创建FastAPI应用
app = FastAPI(
    title="双服务监控示例",
    description="包含对外API服务和数据处理服务的监控指标示例",
    lifespan=lifespan
)

# 添加增强的监控中间件
app.add_middleware(EnhancedMetricsMiddleware)

@app.get("/")
async def root():
    """根路径"""
    return {"message": "双服务监控示例正在运行"}

@app.get("/search")
async def search(query_type: str = "default", query: str = "test"):
    """检索接口"""
    return await api_service.search_data(query_type, query)

@app.post("/write")
async def write_data(data_type: str = "default", data: dict = None):
    """写入接口"""
    if data is None:
        data = {"sample": "data"}
    return await api_service.write_data(data_type, data)

@app.get("/metrics")
async def metrics():
    """Prometheus指标端点"""
    return Response(
        generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

@app.get("/health")
async def health():
    """健康检查接口"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "services": {
            "api_service": "healthy",
            "data_processing_service": "healthy"
        }
    }

@app.post("/simulate/queue")
async def simulate_queue(depth: int = 100):
    """模拟队列深度（用于测试）"""
    data_processing_service.simulate_queue_depth(depth)
    return {"message": f"Queue depth set to {depth}"}

# ==================== 添加新的API端点 ====================

@app.post("/memorize")
async def memorize_endpoint(
    operation_type: str = "create",
    memory_type: str = "short_term",
    user_id: int = None,
    source_type: str = None
):
    """Memorize操作端点"""
    data = {}
    if user_id is not None:
        data['user_id'] = user_id
    if source_type is not None:
        data['source_type'] = source_type
    
    result = await memory_service.memorize(operation_type, memory_type, data)
    return result


@app.get("/memory/stats")
async def get_memory_stats():
    """获取记忆统计信息"""
    with memory_service.lock:
        return {
            "memories": {k: len(v) for k, v in memory_service.memories.items()},
            "users": {k: len(v) for k, v in memory_service.users.items()},
            "memcell_sources": dict(memory_service.memcell_sources)
        }


@app.post("/tasks/add")
async def add_task(task_id: str = None):
    """添加任务到队列"""
    if task_id is None:
        task_id = f"task_{int(time.time() * 1000)}"
    task_queue_manager.add_task(task_id)
    return {"message": f"Task {task_id} added to queue"}


@app.get("/system/stats")
async def get_system_stats():
    """获取系统资源统计（需要psutil）"""
    if not PSUTIL_AVAILABLE:
        return {"error": "psutil not available"}
    
    try:
        return {
            "cpu": {
                "percent": psutil.cpu_percent(interval=0.1),
                "per_cpu": psutil.cpu_percent(interval=0.1, percpu=True)
            },
            "memory": {
                "total": psutil.virtual_memory().total,
                "used": psutil.virtual_memory().used,
                "percent": psutil.virtual_memory().percent
            },
            "disk": [
                {
                    "device": p.device,
                    "mountpoint": p.mountpoint,
                    "usage": psutil.disk_usage(p.mountpoint).percent
                }
                for p in psutil.disk_partitions()
            ]
        }
    except Exception as e:
        return {"error": str(e)}


# ==================== 启动脚本 ====================

if __name__ == "__main__":
    import uvicorn
    
    # 启动Prometheus指标服务器（可选）
    # start_http_server(8001)
    
    # 启动FastAPI应用
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=38000,
        log_level="info"
    )
