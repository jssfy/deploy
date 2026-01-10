# 快速验证请求头

## 方法1: 使用调试端点（最简单）

```bash
# 查看所有请求头信息（包括鉴权信息）
curl -H "Authorization: Bearer test-key" http://localhost/debug/headers | python3 -m json.tool
```

**响应包含：**
- `auth_info`: 从鉴权服务收到的信息（organization_id, account_id 等）
- `request_headers`: 客户端发送的所有请求头
- `forwarded_headers`: 将要转发给下游的请求头（X-Organization-ID 等）
- `request_info`: 请求基本信息

## 方法2: 使用检查脚本

```bash
./scripts/check_headers.sh
```

## 方法3: 查看日志

```bash
# 查看请求头日志
docker exec nginx-proxy tail -f /var/log/nginx/headers.log

# 查看错误日志（包含 Lua 调试信息）
docker exec nginx-proxy tail -f /var/log/nginx/error.log
```

## 方法4: 在后端服务中查看

如果后端服务有调试端点，可以查看实际收到的请求头：

```bash
curl -H "Authorization: Bearer test-key" http://localhost/api/debug/headers
```

## 验证转发给下游的请求头

### 选项1: 使用 tcpdump 抓包

```bash
# 在容器中安装 tcpdump（如果未安装）
docker exec nginx-proxy apk add tcpdump

# 抓包查看发送到后端服务的请求
docker exec nginx-proxy tcpdump -i any -A -s 0 'tcp port 8000' -n
```

### 选项2: 使用测试服务

临时修改后端服务地址为 httpbin.org（会返回请求头）：

```nginx
# 在 proxy_with_auth.conf 中临时修改
upstream backend_server {
    server httpbin.org:80;
}
```

然后访问：
```bash
curl -H "Authorization: Bearer test-key" http://localhost/headers
```

## 示例输出

```json
{
  "auth_info": {
    "organization_id": "mock-org-id",
    "account_id": "mock-account-id",
    "space_id": "mock-space-id",
    "hash_key": "mock-hash-key",
    "request_id": "mock-request-id"
  },
  "request_headers": {
    "authorization": "Bearer test-key",
    "host": "localhost",
    "user-agent": "curl/8.7.1"
  },
  "forwarded_headers": {
    "X-Organization-ID": "mock-org-id",
    "X-Account-ID": "mock-account-id",
    "X-Space-ID": "mock-space-id",
    "X-Hash-Key": "mock-hash-key",
    "X-Request-ID": "mock-request-id"
  }
}
```

## 说明

- **auth_info**: 从鉴权服务返回的 JSON 解析后的信息
- **forwarded_headers**: 这些头部会被添加到转发给后端服务的请求中
- **request_headers**: 客户端原始请求头

详细说明见：`DEBUG_HEADERS_GUIDE.md`

## 记录

(base) [26-01-11 1:18:43 localhost:~/workspace/tools/deploy/nginx/scripts]
admin ➜ curl -H "Authorization: Bearer test-key" http://localhost/ | python3 -m json.tool
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    69  100    69    0     0   6506      0 --:--:-- --:--:-- --:--:--  6900
{
    "message": "FastAPI\u5e76\u53d1\u6d4b\u8bd5\u670d\u52a1\u6b63\u5728\u8fd0\u884c",
    "request_count": 1
}

(base) [26-01-11 1:23:40 localhost:~/workspace/tools/deploy/nginx/scripts]
admin ➜ curl -H "Authorization: Bearer test-key" http://localhost/ | python3 -m json.tool
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   496  100   496    0     0  77415      0 --:--:-- --:--:-- --:--:-- 82666
{
    "message": "FastAPI\u5e76\u53d1\u6d4b\u8bd5\u670d\u52a1\u6b63\u5728\u8fd0\u884c",
    "request_count": 1,
    "headers": {
        "host": "localhost",
        "x-real-ip": "192.168.65.1",
        "x-forwarded-for": "192.168.65.1",
        "x-forwarded-proto": "http",
        "x-forwarded-host": "localhost",
        "x-forwarded-port": "80",
        "x-organization-id": "mock-org-id",
        "x-account-id": "mock-account-id",
        "x-space-id": "mock-space-id",
        "x-hash-key": "mock-hash-key",
        "x-request-id": "mock-request-id",
        "connection": "close",
        "user-agent": "curl/8.7.1",
        "accept": "*/*",
        "authorization": "Bearer test-key"
    }
}


