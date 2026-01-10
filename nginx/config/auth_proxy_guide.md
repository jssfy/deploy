# Nginx 鉴权代理配置指南

## 需求说明

实现请求流程：`客户端 -> Nginx -> 鉴权服务(localhost:8888) -> 原始目标服务`

要求：
1. 请求先经过鉴权服务进行鉴权
2. 鉴权服务可以修改请求头
3. 修改后的请求转发到原始目标服务

## 实现方案

### 方案1: 使用 auth_request 模块（标准方案）

**工作原理：**
- Nginx 使用 `auth_request` 模块先向鉴权服务发送子请求
- 鉴权服务返回 200 表示通过，其他状态码表示拒绝
- 如果通过，Nginx 继续处理原始请求并转发到目标服务

**限制：**
- 标准 `auth_request` 模块无法直接读取鉴权服务返回的响应头来修改请求头
- 需要配合 nginx-lua 模块才能实现请求头修改

**配置文件：** `nginx_with_auth.conf`

**鉴权服务要求：**
- 接收 GET/POST 请求（取决于原始请求方法）
- 返回状态码：
  - `200`: 鉴权通过
  - `401`: 未授权
  - `403`: 禁止访问
  - 其他: 鉴权失败
- 可选：在响应头中返回修改后的请求头（需要配合 lua 使用）

**示例鉴权服务响应：**
```http
HTTP/1.1 200 OK
X-User: user123
X-Token: token456
X-Custom-Header: custom-value
```

### 方案2: 使用链式代理（推荐，如果鉴权服务支持）

**工作原理：**
- Nginx 直接将请求转发到鉴权服务
- 鉴权服务负责：
  1. 接收请求
  2. 进行鉴权
  3. 修改请求头
  4. 转发到最终目标服务
  5. 返回响应给 Nginx
  6. Nginx 返回给客户端

**优点：**
- 实现简单，不需要特殊模块
- 鉴权服务完全控制请求头修改
- 支持复杂的鉴权逻辑

**缺点：**
- 需要鉴权服务实现代理转发功能
- 增加了鉴权服务的复杂度

**配置文件：** 使用 `nginx_with_auth.conf` 中的 `/chain-proxy` location

**鉴权服务要求：**
- 接收完整的 HTTP 请求（包括请求体）
- 进行鉴权检查
- 修改请求头
- 转发请求到目标服务（通过 `X-Target-*` 头部获取目标信息）
- 返回目标服务的响应

### 方案3: 使用 nginx-lua 模块（最灵活，当前使用）

**工作原理：**
- 使用 Lua 脚本先请求鉴权服务（支持 POST 请求）
- 读取鉴权服务返回的 JSON 响应体
- 解析 JSON，提取字段
- 将字段值设置为新的请求头变量
- 转发到目标服务，并添加这些请求头

**优点：**
- ✅ 完全支持请求头修改
- ✅ 支持 POST 请求到鉴权服务
- ✅ 支持 JSON 响应解析
- ✅ 灵活，可以实现复杂逻辑
- ✅ 避免单点故障（鉴权服务不负责转发）

**缺点：**
- 需要安装 nginx-lua 模块（使用 OpenResty）
- 配置相对复杂

**当前实现：**
- 使用 `start_with_post_auth.sh` 启动
- 配置文件：`nginx_auth_request_post.conf`
- 使用 OpenResty 镜像（包含 Lua 模块）
- 鉴权服务接口：`POST /auth/api_key`，返回 JSON 响应

## 配置使用

### 使用方案1（auth_request）

1. 使用 `nginx_with_auth.conf` 配置文件
2. 确保鉴权服务 `localhost:8888` 正常运行
3. 启动 Nginx：
```bash
# 修改 start-proxy.sh 使用新配置文件，或直接使用 docker 命令
docker run -d --name nginx-proxy \
  -p 80:80 \
  -v $(pwd)/config/nginx_with_auth.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/config/proxy_with_auth.conf:/etc/nginx/proxy_with_auth.conf:ro \
  nginx:1.23.2
```

### 使用方案2（链式代理）

1. 确保鉴权服务支持代理转发功能
2. 使用 `/chain-proxy` 路径访问
3. 鉴权服务需要读取 `X-Target-*` 头部获取目标信息

### 使用方案3（lua模块，当前使用）

**当前实现使用此方案**

1. 使用启动脚本：
```bash
./scripts/start_with_post_auth.sh
```

2. 或手动启动：
```bash
docker run -d --name nginx-proxy \
  -p 80:80 \
  -v $(pwd)/config/nginx_auth_request_post.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro \
  -v $(pwd)/config/proxy_with_auth.conf:/etc/nginx/proxy_with_auth.conf:ro \
  -v $(pwd)/html:/usr/share/nginx/html:ro \
  -v $(pwd)/logs:/var/log/nginx \
  --restart unless-stopped \
  openresty/openresty:alpine
```

**技术细节：**
- 使用 OpenResty（包含 Lua 模块）
- 使用 `ngx.location.capture` 发送内部子请求
- 使用 `cjson` 模块解析 JSON 响应
- 支持 POST 请求到鉴权服务

## 鉴权服务接口规范

### 方案1接口（auth_request）

**请求：**
```
GET /auth HTTP/1.1
Host: localhost:8888
X-Original-URI: /api/users
X-Original-Method: GET
X-Original-Host: example.com
... (其他原始请求头)
```

**响应（通过）：**
```
HTTP/1.1 200 OK
X-User: user123
X-Token: token456
```

**响应（拒绝）：**
```
HTTP/1.1 401 Unauthorized
```

### 方案2接口（链式代理）

**请求：**
```
GET /api/users HTTP/1.1
Host: localhost:8888
X-Target-Host: example.com
X-Target-Port: 8000
X-Target-Path: /api/users
... (原始请求的所有头部和请求体)
```

**响应：**
直接返回目标服务的响应

## 测试

### 当前实现（方案3）

```bash
# 测试健康检查（跳过鉴权）
curl http://localhost/health

# 测试代理状态（跳过鉴权）
curl http://localhost/proxy-status

# 测试鉴权代理（会调用 POST /auth/api_key）
curl -H "Authorization: Bearer test-key" http://localhost/api/test

# 查看请求头信息（调试端点）
curl -H "Authorization: Bearer test-key" http://localhost/debug/headers | python3 -m json.tool
```

### 其他方案测试

```bash
# 测试鉴权代理（方案1，如果使用）
curl http://localhost/api/users

# 测试链式代理（方案2，如果使用）
curl http://localhost/chain-proxy/api/users
```

## 注意事项

1. **请求体处理**：`auth_request` 默认不传递请求体，如果鉴权需要请求体，需要特殊配置
2. **性能**：每次请求都会先请求鉴权服务，可能影响性能，建议鉴权服务响应快速
3. **错误处理**：确保鉴权服务不可用时，Nginx 能正确处理（返回 502 或 503）
4. **超时设置**：合理设置鉴权服务的超时时间，避免请求长时间等待

## 推荐方案

- **✅ 当前使用**：方案3（lua模块）- 支持 POST 鉴权，灵活且避免单点故障
- **如果鉴权服务可以修改并支持转发**：使用方案2（链式代理）
- **如果只需要鉴权检查，不需要修改请求头，且鉴权服务支持 GET**：使用方案1（auth_request）

## 当前实现说明

**当前使用的是方案3（lua模块）**，具体特点：

1. **鉴权服务接口**：`POST /auth/api_key`
2. **请求格式**：JSON 请求体
   ```json
   {
     "auth_header": "Bearer test-key",
     "uri": "/api/test",
     "method": "GET"
   }
   ```
3. **响应格式**：JSON 响应体
   ```json
   {
     "organization_id": "org-123",
     "account_id": "account-456",
     ...
   }
   ```
4. **实现方式**：Lua 脚本解析 JSON，设置变量，添加到请求头
5. **启动方式**：使用 `start_with_post_auth.sh` 脚本

详细说明见：`AUTH_REQUEST_README.md` 和 `POST_AUTH_SOLUTION.md`
