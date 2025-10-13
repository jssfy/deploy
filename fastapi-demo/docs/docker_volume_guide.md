# Docker Volume管理指南

## 📋 Docker Compose命令对比

### 1. `docker-compose stop`
```bash
docker-compose stop
```
- **作用**: 停止所有服务容器
- **Volume**: ✅ 保留
- **数据**: ✅ 保留
- **网络**: ✅ 保留
- **用途**: 临时停止服务，数据不丢失

### 2. `docker-compose down`
```bash
docker-compose down
```
- **作用**: 停止并删除容器、网络
- **Volume**: ✅ 保留
- **数据**: ✅ 保留
- **网络**: ❌ 删除
- **用途**: 完全清理，但保留数据

### 3. `docker-compose down -v`
```bash
docker-compose down -v
```
- **作用**: 停止并删除容器、网络、Volume
- **Volume**: ❌ 删除
- **数据**: ❌ 删除
- **网络**: ❌ 删除
- **用途**: 完全清理，包括所有数据

### 4. `docker-compose down --volumes --remove-orphans`
```bash
docker-compose down --volumes --remove-orphans
```
- **作用**: 完全清理，包括孤立容器
- **Volume**: ❌ 删除
- **数据**: ❌ 删除
- **网络**: ❌ 删除
- **用途**: 最彻底的清理

## 🗂️ Volume管理命令

### 查看Volume
```bash
# 查看所有Volume
docker volume ls

# 查看项目相关Volume
docker volume ls | grep fastapi-demo

# 查看Volume详细信息
docker volume inspect fastapi-demo_prometheus_data
```

### 删除Volume
```bash
# 删除单个Volume
docker volume rm fastapi-demo_prometheus_data

# 删除多个Volume
docker volume rm fastapi-demo_prometheus_data fastapi-demo_grafana_data

# 删除所有未使用的Volume
docker volume prune
```

### 备份Volume
```bash
# 备份Prometheus数据
docker run --rm -v fastapi-demo_prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus_backup.tar.gz -C /data .

# 恢复Prometheus数据
docker run --rm -v fastapi-demo_prometheus_data:/data -v $(pwd):/backup alpine tar xzf /backup/prometheus_backup.tar.gz -C /data
```

## ⚠️ 注意事项

### 数据持久化
- Volume数据在容器删除后仍然存在
- 只有显式删除Volume才会丢失数据
- 这是Docker的设计特性，用于数据持久化

### 磁盘空间
- 未使用的Volume会占用磁盘空间
- 定期使用 `docker volume prune` 清理
- 检查Volume大小: `docker system df -v`

### 生产环境建议
- 使用 `docker-compose stop` 进行日常维护
- 使用 `docker-compose down` 进行配置更新
- 谨慎使用 `docker-compose down -v`，会丢失所有数据
- 定期备份重要数据

## 🔧 实用脚本

### 安全停止脚本
```bash
#!/bin/bash
# 安全停止服务，保留数据
docker-compose stop
echo "服务已停止，数据已保留"
```

### 完全清理脚本
```bash
#!/bin/bash
# 完全清理，包括数据
read -p "确认删除所有数据? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down -v
    echo "所有数据已删除"
else
    echo "操作已取消"
fi
```

### 数据备份脚本
```bash
#!/bin/bash
# 备份所有Volume数据
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

docker volume ls -q | grep fastapi-demo | while read volume; do
    echo "备份 $volume..."
    docker run --rm -v "$volume":/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf "/backup/${volume}.tar.gz" -C /data .
done

echo "备份完成: $BACKUP_DIR"
```
