# 验证 Nginx 请求头指南

## 概述

本指南说明如何验证：
1. Nginx 从鉴权服务收到的响应信息（解析后的变量）
2. Nginx 转发给下游服务的请求头

## 方法1: 使用调试端点（推荐）

### 配置说明

配置文件中已添加 `/debug/headers` 端点，会：
1. 进行鉴权检查
2. 解析鉴权服务返回的 JSON
3. 返回所有请求头信息（包括鉴权信息）

### 使用方法

```bash
# 测试调试端点
curl -H "Authorization: Bearer test-key" http://localhost/debug/headers | python3 -m json.tool
```

### 响应格式

```json
{
  "auth_info": {
    "organization_id": "org-123",
    "account_id": "account-456",
    "space_id": "space-789",
    "hash_key": "hash-key-value",
    "request_id": "req-12345"
  },
  "request_headers": {
    "host": "localhost",
    "authorization": "Bearer test-key",
    "user-agent": "curl/8.7.1",
    ...
  },
  "forwarded_headers": {
    "X-Organization-ID": "org-123",
    "X-Account-ID": "account-456",
    "X-Space-ID": "space-789",
    "X-Hash-Key": "hash-key-value",
    "X-Request-ID": "req-12345"
  },
  "request_info": {
    "uri": "/debug/headers",
    "method": "GET",
    "host": "localhost",
    "remote_addr": "192.168.65.1"
  }
}
```

## 方法2: 查看日志文件

### 请求头日志

配置中已添加 `headers.log`，记录所有请求的鉴权信息：

```bash
# 查看请求头日志
docker exec nginx-proxy tail -f /var/log/nginx/headers.log

# 查看最近的请求
docker exec nginx-proxy tail -20 /var/log/nginx/headers.log
```

### 日志格式

```
192.168.65.1 [10/Jan/2026:16:50:58 +0000] "GET /api/test HTTP/1.1" org_id="org-123" account_id="account-456" space_id="space-789" hash_key="hash-key-value" request_id="req-12345" x_org="" x_account="" x_space=""
```

### 访问日志

查看标准访问日志：

```bash
# 查看访问日志
docker exec nginx-proxy tail -f /var/log/nginx/access.log

# 或从宿主机查看
tail -f logs/access.log
```

## 方法3: 使用检查脚本

运行检查脚本：

```bash
./scripts/check_headers.sh
```

脚本会：
1. 测试调试端点
2. 显示日志文件内容
3. 提供其他查看方法

## 方法4: 查看转发给下游的请求头

### 选项1: 在后端服务中打印请求头

在后端服务中添加代码，打印所有收到的请求头：

**Python Flask 示例：**
```python
@app.route('/api/debug/headers')
def debug_headers():
    return jsonify({
        'headers': dict(request.headers),
        'remote_addr': request.remote_addr
    })
```

**测试：**
```bash
curl -H "Authorization: Bearer test-key" http://localhost/api/debug/headers
```

### 选项2: 使用 tcpdump 抓包

在容器中抓包查看实际发送的请求：

```bash
# 安装 tcpdump（如果未安装）
docker exec nginx-proxy apk add tcpdump

# 抓包查看发送到后端服务的请求
docker exec nginx-proxy tcpdump -i any -A -s 0 'tcp port 8000' -n
```

### 选项3: 使用代理工具

在 nginx 和后端服务之间添加代理（如 mitmproxy），查看实际请求。

### 选项4: 修改后端服务地址为测试服务

临时将后端服务地址改为一个可以显示请求头的测试服务：

```nginx
# 在 proxy_with_auth.conf 中临时修改
upstream backend_server {
    server httpbin.org:80;  # 测试服务，会返回请求头
}
```

然后访问：
```bash
curl -H "Authorization: Bearer test-key" http://localhost/headers
```

## 方法5: 在 Lua 脚本中添加日志

修改 `nginx_auth_request_post.conf`，在 Lua 脚本中添加日志：

```lua
-- 在 access_by_lua_block 中添加
ngx.log(ngx.ERR, "Auth response: ", res.body)
ngx.log(ngx.ERR, "Organization ID: ", auth_data.organization_id)
ngx.log(ngx.ERR, "Account ID: ", auth_data.account_id)
```

然后查看错误日志：
```bash
docker exec nginx-proxy tail -f /var/log/nginx/error.log
```

## 验证步骤

### 1. 验证鉴权服务响应

```bash
# 直接测试鉴权服务
curl -X POST http://localhost:8888/auth/api_key \
  -H "Content-Type: application/json" \
  -d '{"auth_header":"Bearer test-key","uri":"/test","method":"GET"}' | python3 -m json.tool
```

### 2. 验证 Nginx 收到的信息

```bash
# 使用调试端点
curl -H "Authorization: Bearer test-key" http://localhost/debug/headers | python3 -m json.tool
```

### 3. 验证转发给下游的请求头

```bash
# 如果后端服务有调试端点
curl -H "Authorization: Bearer test-key" http://localhost/api/debug/headers

# 或查看日志
docker exec nginx-proxy tail -f /var/log/nginx/headers.log
```

## 常见问题

### Q: 调试端点返回 401？

A: 检查认证头是否正确：
```bash
# 使用 Authorization 头
curl -H "Authorization: Bearer test-key" http://localhost/debug/headers

# 或使用 X-API-Key
curl -H "X-API-Key: test-key" http://localhost/debug/headers
```

### Q: 日志文件不存在？

A: 重启容器以应用新配置：
```bash
docker restart nginx-proxy
```

### Q: 看不到请求头？

A: 确保：
1. 鉴权服务返回了正确的 JSON
2. Lua 脚本成功解析了 JSON
3. 变量已正确设置

### Q: 如何实时监控？

A: 使用以下命令：
```bash
# 实时查看请求头日志
docker exec nginx-proxy tail -f /var/log/nginx/headers.log

# 实时查看错误日志
docker exec nginx-proxy tail -f /var/log/nginx/error.log

# 实时查看所有日志
docker logs -f nginx-proxy
```

## 快速参考

```bash
# 检查脚本
./scripts/check_headers.sh

# 调试端点
curl -H "Authorization: Bearer test-key" http://localhost/debug/headers | python3 -m json.tool

# 查看日志
docker exec nginx-proxy tail -f /var/log/nginx/headers.log

# 查看错误日志
docker exec nginx-proxy tail -f /var/log/nginx/error.log
```
