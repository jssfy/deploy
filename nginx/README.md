# Nginx 代理容器管理脚本

这个目录包含了用于管理 Nginx 代理容器的脚本工具。

## 快速参考

### macOS/Windows 用户（推荐命令）

```bash
# 启动（无SSL，HTTP模式）
./start-proxy.sh --no-ssl -d

# 访问测试
curl http://localhost/health
curl http://localhost/proxy-status

# 查看日志
docker logs -f nginx-proxy

# 停止容器
docker stop nginx-proxy
```

### Linux 用户（推荐命令）

```bash
# 启动（host网络模式）
./start-proxy.sh --host-network -d

# 访问测试
curl http://localhost/health

# 查看日志
docker logs -f nginx-proxy
```

## 文件说明

- `start-proxy.sh` - Nginx 代理容器启动脚本
   - 调试：root@f450f25644fe:/var/log/nginx# tail -f error.log
- `README.md` - 使用说明文档

## 快速开始

### 启动 Nginx 代理容器

**重要提示：**
- **macOS/Windows 用户**：必须使用 `--bridge-network` 模式（或默认模式），因为 Docker Desktop 在虚拟机中运行，host 网络模式无法映射端口到宿主机
- **Linux 用户**：可以使用 `--host-network` 模式获得更好性能

```bash
# macOS/Windows推荐：使用bridge网络模式（默认）
./start-proxy.sh --no-ssl --bridge-network -d

# 或者简写（bridge是默认模式）
./start-proxy.sh --no-ssl -d

# Linux推荐：使用host网络模式
./start-proxy.sh --host-network -d

# 指定端口和容器名称
./start-proxy.sh -n my-proxy -p 8080 --no-ssl -d
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
| `--host-network` | | 使用host网络模式 | `true` |
| `--bridge-network` | | 使用bridge网络模式 | `false` |
| `--no-ssl` | | 禁用SSL，仅使用HTTP | `false` |
| `--help` | | 显示帮助信息 | |

#### 使用示例

```bash
# 1. macOS/Windows推荐：禁用SSL + bridge网络模式
./start-proxy.sh --no-ssl --bridge-network -d

# 2. Linux推荐：host网络模式启动
./start-proxy.sh --host-network -d

# 3. 禁用SSL，仅使用HTTP（无需证书，macOS/Windows推荐）
./start-proxy.sh --no-ssl -d

# 4. 自定义端口和名称
./start-proxy.sh -n web-proxy -p 8080 --no-ssl -d

# 5. 强制重新创建容器
./start-proxy.sh -f --no-ssl -d

# 6. 前台运行（调试模式）
./start-proxy.sh --no-ssl --bridge-network

# 7. 启用SSL模式（需要证书文件）
./start-proxy.sh --bridge-network -d
```

## 目录结构

脚本会自动创建以下目录结构：

```
deploy/nginx/
├── start-proxy.sh
├── README.md
├── config/
│   ├── nginx.conf                    # Nginx主配置文件（含SSL）
│   ├── nginx_no_ssl.conf             # Nginx配置文件（无SSL）
│   ├── proxy.conf                    # 代理配置文件
│   ├── data.yeanhua.asia.pem         # SSL证书（可选）
│   └── data.yeanhua.asia.key         # SSL私钥（可选）
├── html/
│   └── index.html                    # 默认HTML页面
└── logs/
    ├── access.log                    # 访问日志
    └── error.log                     # 错误日志
```

## 功能特性

### 网络模式

#### Host网络模式（仅Linux推荐）
- 容器直接使用宿主机网络栈
- 可以直接访问 `localhost:33333`
- 性能更好，配置更简单
- 适合内网服务代理
- **⚠️ 在macOS/Windows上不工作**：Docker Desktop 在虚拟机中运行，host 网络模式仅影响虚拟机内部，无法将端口映射到宿主机

#### Bridge网络模式（macOS/Windows推荐，默认模式）
- 容器使用独立的网络命名空间
- 通过端口映射访问（如 `-p 80:80`）
- 网络隔离，更安全
- 适合多容器环境
- **✅ macOS/Windows上必须使用此模式才能从宿主机访问**
- 默认端口映射：`80:80`（HTTP），`443:443`（HTTPS，如果启用SSL）

### 代理功能
- 支持HTTP和HTTPS代理
- 可选的SSL证书配置
- 支持无SSL模式（使用`--no-ssl`选项）
- 健康检查和状态监控
- 静态文件缓存
- 错误处理和重定向

### 安全特性
- SSL/TLS加密（可选）
- 安全头部配置
- 代理头部传递
- 错误页面处理

### SSL 模式说明

#### 启用SSL（默认）
- 需要提供SSL证书文件（`.pem`和`.key`）
- 同时支持HTTP（80端口）和HTTPS（443端口）
- 自动配置安全头部

#### 禁用SSL（`--no-ssl`）
- 不需要SSL证书文件
- 仅支持HTTP（80端口）
- 适合开发环境或内网使用
- 使用`config/nginx_no_ssl.conf`配置文件

## 访问测试

启动容器后，可以通过以下方式访问：

### Bridge网络模式（macOS/Windows默认）

```bash
# 健康检查
curl http://localhost/health
# 或指定端口
curl http://localhost:80/health

# 代理状态
curl http://localhost/proxy-status

# 访问根路径（会代理到后端服务）
curl http://localhost/

# 如果启用了SSL
curl https://localhost/health
curl https://localhost/proxy-status
```

### Host网络模式（仅Linux）

```bash
# 直接访问localhost（无需端口号）
curl http://localhost/health
curl http://localhost/proxy-status

# 如果启用了SSL
curl https://localhost/health
```

### 浏览器访问

- **Bridge模式**：`http://localhost` 或 `http://localhost:80`
- **Host模式（Linux）**：`http://localhost`
- **HTTPS（如果启用）**：`https://localhost`

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
# 查看容器状态和端口映射
docker ps --filter "name=nginx-proxy"

# 查看容器详细信息
docker inspect nginx-proxy

# 停止容器
docker stop nginx-proxy

# 重启容器
docker restart nginx-proxy

# 删除容器
docker rm nginx-proxy

# 删除容器（如果正在运行，先停止）
docker rm -f nginx-proxy

# 查看容器日志
docker logs nginx-proxy

# 实时查看容器日志
docker logs -f nginx-proxy
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
   解决方案：
   - 方案1：检查证书文件路径是否正确
   - 方案2：使用 `--no-ssl` 选项禁用SSL，仅使用HTTP
   ```bash
   ./start-proxy.sh --no-ssl -d
   ```

5. **macOS/Windows上无法访问服务**
   ```
   容器启动成功，但curl localhost失败
   警告: 在macOS上，--network host模式不会将端口映射到宿主机
   ```
   **原因**：macOS/Windows上的Docker Desktop运行在虚拟机中，host网络模式仅影响虚拟机内部，无法将端口映射到宿主机。
   
   **解决方案**：使用bridge网络模式
   ```bash
   # 停止当前容器
   docker stop nginx-proxy
   docker rm nginx-proxy
   
   # 使用bridge网络模式重启（推荐）
   ./start-proxy.sh --no-ssl --bridge-network -d
   
   # 或者简写（bridge是默认模式）
   ./start-proxy.sh --no-ssl -d
   
   # 验证访问
   curl http://localhost/health
   curl http://localhost/proxy-status
   ```
   
   **验证容器端口映射**：
   ```bash
   # 查看容器端口映射
   docker ps --filter "name=nginx-proxy" --format "table {{.Names}}\t{{.Ports}}"
   
   # 应该显示类似：0.0.0.0:80->80/tcp
   ```

### 调试模式

启用详细输出：
```bash
bash -x ./start-proxy.sh --host-network
```

## 注意事项

1. **网络模式选择**：
   - **macOS/Windows用户**：必须使用 `--bridge-network` 模式（默认），否则无法从宿主机访问
   - **Linux用户**：推荐使用 `--host-network` 模式以获得最佳性能

2. **端口访问**：
   - Bridge模式：通过 `http://localhost:80` 访问（或简写 `http://localhost`）
   - Host模式（Linux）：直接通过 `http://localhost` 访问

3. **SSL证书**：
   - 启用SSL需要提供证书文件（`.pem` 和 `.key`）
   - 开发环境建议使用 `--no-ssl` 选项，仅使用HTTP

4. **其他注意事项**：
   - 确保 Docker 已安装并运行
   - 确保有足够的磁盘空间
   - 配置文件修改后需要重启容器：`docker restart nginx-proxy`
   - 日志文件会持续增长，注意定期清理
   - 后端服务地址在 `config/proxy.conf` 中配置（默认：`host.docker.internal:8000`）

## 许可证

此脚本仅供学习和开发使用。


