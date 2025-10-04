# Nginx 代理容器管理脚本

这个目录包含了用于管理 Nginx 代理容器的脚本工具。

## 文件说明

- `start-proxy.sh` - Nginx 代理容器启动脚本
- `README.md` - 使用说明文档

## 快速开始

### 启动 Nginx 代理容器

```bash
# 使用host网络模式启动（推荐）
./start-proxy.sh --host-network -d

# 使用bridge网络模式启动
./start-proxy.sh -d

# 指定端口和容器名称
./start-proxy.sh -n my-proxy -p 8080 -d
```

## 详细使用说明

### start-proxy.sh 脚本

#### 基本用法
```bash
./start-proxy.sh [选项]
```

#### 可用选项

| 选项 | 长选项 | 说明 | 默认值 |
|------|--------|------|--------|
| `-n` | `--name` | 容器名称 | `nginx-proxy` |
| `-p` | `--port` | 主机端口 | `80` |
| `-d` | `--detach` | 后台运行容器 | `false` |
| `-f` | `--force` | 强制重新创建容器 | `false` |
| `--host-network` | | 使用host网络模式 | `false` |
| `--help` | | 显示帮助信息 | |

#### 使用示例

```bash
# 1. Host网络模式启动（推荐）
./start-proxy.sh --host-network -d

# 2. Bridge网络模式启动
./start-proxy.sh -d

# 3. 自定义端口和名称
./start-proxy.sh -n web-proxy -p 8080 -d

# 4. 强制重新创建容器
./start-proxy.sh -f -d

# 5. 前台运行（调试模式）
./start-proxy.sh --host-network
```

## 目录结构

脚本会自动创建以下目录结构：

```
deploy/nginx/
├── start-proxy.sh
├── README.md
├── config/
│   ├── nginx.conf                    # Nginx主配置文件
│   ├── proxy.conf                    # 代理配置文件
│   └── 19720390_www.yeanhua.asia_nginx/  # SSL证书目录
│       ├── www.yeanhua.asia.pem
│       └── www.yeanhua.asia.key
├── html/
│   └── index.html                    # 默认HTML页面
└── logs/
    ├── access.log                    # 访问日志
    └── error.log                     # 错误日志
```

## 功能特性

### 网络模式

#### Host网络模式（推荐）
- 容器直接使用宿主机网络栈
- 可以直接访问 `localhost:33333`
- 性能更好，配置更简单
- 适合内网服务代理

#### Bridge网络模式
- 容器使用独立的网络命名空间
- 需要端口映射
- 网络隔离，更安全
- 适合多容器环境

### 代理功能
- 支持HTTP和HTTPS代理
- 自动SSL证书配置
- 健康检查和状态监控
- 静态文件缓存
- 错误处理和重定向

### 安全特性
- SSL/TLS加密
- 安全头部配置
- 代理头部传递
- 错误页面处理

## 访问测试

启动容器后，可以通过以下方式访问：

```bash
# 健康检查
curl http://localhost/health
curl https://localhost/health

# 代理状态
curl http://localhost/proxy-status
curl https://localhost/proxy-status

# 主应用（Apache Superset）
curl -L https://www.yeanhua.asia/
```

## 日志查看

```bash
# 查看容器日志
docker logs nginx-proxy

# 查看访问日志
tail -f logs/access.log

# 查看错误日志
tail -f logs/error.log
```

## 容器管理

```bash
# 停止容器
docker stop nginx-proxy

# 重启容器
docker restart nginx-proxy

# 删除容器
docker rm nginx-proxy

# 查看容器状态
docker ps
```

## 故障排除

### 常见问题

1. **端口被占用**
   ```
   错误: 端口 80 已被占用
   ```
   解决方案：使用 `-p` 选项指定其他端口

2. **Docker 未运行**
   ```
   错误: Docker未运行或无法访问
   ```
   解决方案：启动 Docker 服务
   ```bash
   sudo systemctl start docker
   ```

3. **配置文件不存在**
   ```
   错误: 配置文件不存在
   ```
   解决方案：确保配置文件已创建

4. **SSL证书问题**
   ```
   错误: SSL证书文件不存在
   ```
   解决方案：检查证书文件路径

### 调试模式

启用详细输出：
```bash
bash -x ./start-proxy.sh --host-network
```

## 注意事项

1. 确保 Docker 已安装并运行
2. 确保有足够的磁盘空间
3. 如果使用端口 80，可能需要 sudo 权限
4. 配置文件修改后需要重启容器
5. 日志文件会持续增长，注意定期清理
6. 推荐使用host网络模式以获得最佳性能

## 许可证

此脚本仅供学习和开发使用。


