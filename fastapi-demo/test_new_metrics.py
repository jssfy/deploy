#!/usr/bin/env python3
"""
新增指标测试脚本
用于验证所有新增的监控指标是否正常工作
"""

import asyncio
import requests
import time
import random

BASE_URL = "http://localhost:38000"
METRICS_URL = f"{BASE_URL}/metrics"

def print_section(title):
    """打印分隔线"""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)

def test_basic_endpoints():
    """测试基础端点"""
    print_section("测试基础端点")
    
    endpoints = [
        ("/", "GET"),
        ("/health", "GET"),
        ("/search?query_type=test&query=hello", "GET"),
    ]
    
    for endpoint, method in endpoints:
        try:
            url = BASE_URL + endpoint
            if method == "GET":
                response = requests.get(url)
            else:
                response = requests.post(url)
            print(f"✓ {method} {endpoint}: {response.status_code}")
        except Exception as e:
            print(f"✗ {method} {endpoint}: {e}")

def test_memorize_operations():
    """测试memorize操作"""
    print_section("测试Memorize操作")
    
    # 测试不同类型的memorize操作
    test_cases = [
        {
            "operation_type": "create",
            "memory_type": "short_term",
            "user_id": random.randint(1, 100),
            "description": "创建短期记忆"
        },
        {
            "operation_type": "create",
            "memory_type": "mid_term",
            "user_id": random.randint(1, 100),
            "description": "创建中期记忆"
        },
        {
            "operation_type": "create",
            "memory_type": "long_term",
            "user_id": random.randint(1, 100),
            "description": "创建长期记忆"
        },
        {
            "operation_type": "create",
            "memory_type": "memcell",
            "user_id": random.randint(1, 100),
            "source_type": "chat",
            "description": "创建memcell（chat源）"
        },
        {
            "operation_type": "create",
            "memory_type": "memcell",
            "user_id": random.randint(1, 100),
            "source_type": "note",
            "description": "创建memcell（note源）"
        },
    ]
    
    for case in test_cases:
        try:
            params = {k: v for k, v in case.items() if k != "description"}
            response = requests.post(f"{BASE_URL}/memorize", params=params)
            print(f"✓ {case['description']}: {response.status_code}")
            time.sleep(0.5)  # 避免请求过快
        except Exception as e:
            print(f"✗ {case['description']}: {e}")

def test_task_queue():
    """测试任务队列"""
    print_section("测试任务队列")
    
    # 添加多个任务
    for i in range(5):
        try:
            task_id = f"test_task_{int(time.time())}_{i}"
            response = requests.post(f"{BASE_URL}/tasks/add", params={"task_id": task_id})
            print(f"✓ 添加任务 {task_id}: {response.status_code}")
            time.sleep(0.2)
        except Exception as e:
            print(f"✗ 添加任务失败: {e}")

def test_memory_stats():
    """测试记忆统计"""
    print_section("测试记忆统计")
    
    try:
        response = requests.get(f"{BASE_URL}/memory/stats")
        if response.status_code == 200:
            stats = response.json()
            print(f"✓ 记忆统计获取成功")
            print(f"  记忆数量: {stats.get('memories', {})}")
            print(f"  用户数量: {stats.get('users', {})}")
            print(f"  Memcell源: {stats.get('memcell_sources', {})}")
        else:
            print(f"✗ 记忆统计获取失败: {response.status_code}")
    except Exception as e:
        print(f"✗ 记忆统计请求失败: {e}")

def test_system_stats():
    """测试系统统计"""
    print_section("测试系统统计")
    
    try:
        response = requests.get(f"{BASE_URL}/system/stats")
        if response.status_code == 200:
            stats = response.json()
            if "error" in stats:
                print(f"⚠ 系统统计不可用: {stats['error']}")
                print(f"  提示: 请安装psutil库（pip install psutil）")
            else:
                print(f"✓ 系统统计获取成功")
                print(f"  CPU使用率: {stats.get('cpu', {}).get('percent', 'N/A')}%")
                print(f"  内存使用率: {stats.get('memory', {}).get('percent', 'N/A')}%")
                print(f"  磁盘信息: {len(stats.get('disk', []))} 个分区")
        else:
            print(f"✗ 系统统计获取失败: {response.status_code}")
    except Exception as e:
        print(f"✗ 系统统计请求失败: {e}")

def check_metrics():
    """检查Prometheus指标"""
    print_section("检查Prometheus指标")
    
    try:
        response = requests.get(METRICS_URL)
        if response.status_code == 200:
            metrics_text = response.text
            
            # 检查关键指标是否存在
            key_metrics = [
                # 业务指标
                "memory_total",
                "memory_daily_change",
                "memcell_by_source_total",
                "memory_users_total",
                "memorize_duration_seconds",
                "memorize_operations_total",
                "memorize_concurrent",
                
                # 稳定性指标
                "http_requests_qps",
                "http_requests_qps_by_status",
                "system_cpu_usage_percent",
                "system_memory_usage_bytes",
                "system_memory_usage_percent",
                "system_disk_usage_bytes",
                "system_network_bytes_total",
                
                # 性能指标
                "queue_tasks_total",
                "queue_tasks_pending",
                "concurrent_tasks_count",
                "concurrent_tasks_max",
            ]
            
            print("检查关键指标:")
            found_count = 0
            for metric in key_metrics:
                if metric in metrics_text:
                    print(f"  ✓ {metric}")
                    found_count += 1
                else:
                    print(f"  ✗ {metric} (未找到)")
            
            print(f"\n总计: {found_count}/{len(key_metrics)} 个指标可用")
            
            # 统计指标总数
            metric_lines = [line for line in metrics_text.split('\n') 
                          if line and not line.startswith('#')]
            print(f"指标数据行数: {len(metric_lines)}")
            
        else:
            print(f"✗ 无法获取指标: {response.status_code}")
    except Exception as e:
        print(f"✗ 指标检查失败: {e}")

def generate_load():
    """生成一些负载以产生指标数据"""
    print_section("生成测试负载")
    
    print("正在生成测试负载...")
    
    # 并发请求
    import concurrent.futures
    
    def make_request(i):
        try:
            # 随机选择不同的端点
            endpoints = [
                "/",
                "/health",
                "/search?query_type=test&query=hello",
                "/memory/stats",
            ]
            endpoint = random.choice(endpoints)
            requests.get(BASE_URL + endpoint, timeout=5)
            return True
        except:
            return False
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(make_request, range(50)))
    
    success_count = sum(1 for r in results if r)
    print(f"✓ 完成 {success_count}/50 个请求")
    
    # 生成memorize操作
    memory_types = ["short_term", "mid_term", "long_term", "memcell"]
    source_types = ["chat", "note", "document", "image"]
    
    for i in range(20):
        try:
            memory_type = random.choice(memory_types)
            params = {
                "operation_type": "create",
                "memory_type": memory_type,
                "user_id": random.randint(1, 100)
            }
            if memory_type == "memcell":
                params["source_type"] = random.choice(source_types)
            
            requests.post(f"{BASE_URL}/memorize", params=params, timeout=5)
        except:
            pass
    
    print(f"✓ 完成 20 个memorize操作")

def main():
    """主函数"""
    print("\n" + "="*60)
    print("  新增监控指标测试脚本")
    print("="*60)
    print(f"\n目标服务器: {BASE_URL}")
    
    # 检查服务是否可用
    try:
        response = requests.get(BASE_URL, timeout=5)
        print(f"✓ 服务运行正常 (状态码: {response.status_code})")
    except Exception as e:
        print(f"✗ 无法连接到服务: {e}")
        print("\n请确保服务已启动:")
        print("  python monitoring_implementation.py")
        return
    
    # 运行测试
    try:
        test_basic_endpoints()
        test_memorize_operations()
        test_task_queue()
        test_memory_stats()
        test_system_stats()
        
        print("\n")
        print("等待3秒让指标收集器更新...")
        time.sleep(3)
        
        generate_load()
        
        print("\n")
        print("等待3秒让指标收集器更新...")
        time.sleep(3)
        
        check_metrics()
        
        print_section("测试完成")
        print("\n你可以通过以下方式查看指标:")
        print(f"  1. Prometheus指标: {METRICS_URL}")
        print(f"  2. Grafana仪表板: http://localhost:3000")
        print(f"  3. 记忆统计: {BASE_URL}/memory/stats")
        print(f"  4. 系统统计: {BASE_URL}/system/stats")
        print()
        
    except KeyboardInterrupt:
        print("\n\n测试被用户中断")
    except Exception as e:
        print(f"\n\n测试过程中出错: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

