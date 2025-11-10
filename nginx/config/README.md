# Nginx 配置文件说明

本目录包含Nginx代理服务器的配置文件。

## 配置文件

### 1. nginx.conf
完整的Nginx配置文件，包含HTTP和HTTPS服务器配置。

**特点：**
- 同时支持HTTP（80端口）和HTTPS（443端口）
- 需要SSL证书文件
- 包含完整的安全头部配置
- 默认配置文件

**使用场景：**
- 生产环境
- 需要HTTPS加密的场景
- 公网访问

### 2. nginx_no_ssl.conf
仅HTTP的Nginx配置文件，不包含HTTPS服务器配置。

**特点：**
- 仅支持HTTP（80端口）
- 不需要SSL证书文件
- 简化的配置
- 通过`--no-ssl`选项使用

**使用场景：**
- 开发环境
- 测试环境
- 内网服务
- 无法获取SSL证书的情况

### 3. proxy.conf
代理配置文件，包含上游服务器配置和代理参数。

**内容：**
- 上游服务器地址（backend_server）
- 代理超时设置
- 代理缓冲设置
- 代理头部设置

## SSL 证书文件

### data.yeanhua.asia.pem
SSL证书文件（公钥）

### data.yeanhua.asia.key
SSL私钥文件

**注意：**
- 这两个文件仅在启用SSL时需要
- 使用`--no-ssl`选项时不需要这些文件
- 证书文件应妥善保管，不要泄露私钥

## 使用方式

### 使用SSL配置（默认）

```bash
# 确保证书文件存在
ls config/data.yeanhua.asia.pem
ls config/data.yeanhua.asia.key

# 启动容器
./start-proxy.sh -d
```

### 使用无SSL配置

```bash
# 不需要证书文件，直接启动
./start-proxy.sh --no-ssl -d
```

## 修改配置

### 修改后端服务器地址

编辑 `proxy.conf` 文件：

```nginx
upstream backend_server {
    server localhost:8000;  # 修改为你的后端服务地址
}
```

### 修改服务器域名

编辑 `nginx.conf` 或 `nginx_no_ssl.conf`：

```nginx
server {
    listen 80;
    server_name localhost your-domain.com;  # 修改为你的域名
    ...
}
```

### 修改SSL证书路径

如果证书文件名称不同，编辑 `start-proxy.sh`：

```bash
CERT_PATH="${CONFIG_DIR}/your-cert.pem"
KEY_PATH="${CONFIG_DIR}/your-cert.key"
```

## 配置重载

修改配置文件后，需要重启容器使配置生效：

```bash
# 停止容器
docker stop nginx-proxy

# 重新启动
./start-proxy.sh -d
```

或者使用强制重新创建选项：

```bash
./start-proxy.sh -f -d
```

## 健康检查端点

两个配置文件都包含以下健康检查端点：

- `/health` - 基本健康检查
- `/proxy-status` - 代理状态信息

测试方法：

```bash
# HTTP方式
curl http://localhost/health
curl http://localhost/proxy-status

# HTTPS方式（仅在启用SSL时可用）
curl https://localhost/health
curl https://localhost/proxy-status
```

## 日志文件

Nginx日志会输出到 `logs/` 目录：

- `logs/access.log` - 访问日志
- `logs/error.log` - 错误日志

查看日志：

```bash
# 实时查看访问日志
tail -f logs/access.log

# 实时查看错误日志
tail -f logs/error.log
```

