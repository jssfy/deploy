#!/bin/bash
# Prometheus数据清理脚本

echo "🧹 Prometheus数据清理工具"
echo "=========================="

# 检查当前数据
echo "📊 当前数据统计:"
docker exec fastapi-demo-prometheus-1 du -sh /prometheus/
docker exec fastapi-demo-prometheus-1 ls -la /prometheus/

echo ""
echo "⚠️  警告: 以下操作将删除所有历史数据!"
echo "1. 停止Prometheus服务"
echo "2. 删除数据卷"
echo "3. 重新启动服务"
echo ""

read -p "确认删除所有数据? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 停止Prometheus服务..."
    docker-compose stop prometheus
    
    echo "🗑️  删除数据卷..."
    docker volume rm fastapi-demo_prometheus_data
    
    echo "🚀 重新启动服务..."
    docker-compose up -d prometheus
    
    echo "✅ 数据清理完成!"
    echo "📊 新的数据统计:"
    sleep 5
    docker exec fastapi-demo-prometheus-1 ls -la /prometheus/
else
    echo "❌ 操作已取消"
fi
