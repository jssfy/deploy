# POST 鉴权服务配置方案

## 问题

鉴权服务使用 POST 请求：`POST /auth/api_key`，需要 JSON 请求体。

但标准 nginx 的 `auth_request` 模块只支持 GET 请求，不支持 POST 和请求体。

## 解决方案

### 方案1: 使用 OpenResty（推荐）

OpenResty 包含 nginx + lua 模块，可以轻松实现 POST 请求。

#### 1. 使用 OpenResty 镜像

```bash
# 停止现有容器
docker stop nginx-proxy
docker rm nginx-proxy

# 使用 openresty 镜像启动
docker run -d --name nginx-proxy \
  -p 80:80 \
  -v $(pwd)/config/nginx_auth_request_post.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/config/proxy_with_auth.conf:/etc/nginx/proxy_with_auth.conf:ro \
  -v $(pwd)/html:/usr/share/nginx/html:ro \
  -v $(pwd)/logs:/var/log/nginx \
  --restart unless-stopped \
  openresty/openresty:alpine
```

#### 2. 配置文件

使用 `nginx_auth_request_post.conf`，它使用 lua 脚本实现 POST 请求到鉴权服务。

### 方案2: 修改鉴权服务支持 GET（如果可能）

如果鉴权服务可以修改，添加一个 GET 接口：

```
GET /auth/api_key?auth_header=xxx&uri=/test&method=GET
```

然后使用标准的 `auth_request` 配置。

### 方案3: 使用外部鉴权脚本

创建一个独立的鉴权脚本（Python/Node.js），作为中间层：

1. 接收 nginx 的 GET 请求（auth_request）
2. 转换为 POST 请求发送到鉴权服务
3. 返回结果给 nginx

### 方案4: 后端服务处理鉴权

如果无法在 nginx 层实现，可以让后端服务处理鉴权：

1. nginx 直接转发请求到后端
2. 后端服务调用鉴权服务
3. 后端服务处理鉴权逻辑

## 推荐实现（OpenResty + Lua）

### 配置文件说明

`nginx_auth_request_post.conf` 使用 lua 脚本：

1. 读取客户端请求的认证头（Authorization 或 X-API-Key）
2. 构建 JSON 请求体
3. 使用 `ngx.location.capture` 发送内部子请求到 `/_auth_post` location
4. `/_auth_post` location 转发 POST 请求到鉴权服务
5. 解析 JSON 响应
6. 将响应中的字段添加到请求头（X-Organization-ID, X-Account-ID 等）
7. 转发原始请求到后端服务

**技术要点：**
- 使用 `ngx.location.capture` 而不是 `resty.http`（无需额外模块）
- 使用 `cjson` 模块解析 JSON（OpenResty 内置）
- 使用内部 location `/_auth_post` 处理 POST 请求转发

### 请求流程

```
客户端请求
  ↓
Nginx (lua 脚本)
  ↓ POST /auth/api_key
鉴权服务 (localhost:8888)
  ↓ 返回 JSON
Nginx (解析 JSON，添加请求头)
  ↓
后端服务 (localhost:8000)
```

### 测试

```bash
# 测试鉴权服务
curl -X POST http://localhost:8888/auth/api_key \
  -H "Content-Type: application/json" \
  -d '{"auth_header":"test-key","uri":"/test","method":"GET"}'

# 测试通过 nginx
curl http://localhost/api/test \
  -H "Authorization: Bearer test-key"
```

## 快速开始（OpenResty）

```bash
cd /Users/admin/workspace/tools/deploy/nginx

# 停止现有容器
docker stop nginx-proxy 2>/dev/null || true
docker rm nginx-proxy 2>/dev/null || true

# 启动 OpenResty 容器
docker run -d --name nginx-proxy \
  -p 80:80 \
  -v $(pwd)/config/nginx_auth_request_post.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/config/proxy_with_auth.conf:/etc/nginx/proxy_with_auth.conf:ro \
  -v $(pwd)/html:/usr/share/nginx/html:ro \
  -v $(pwd)/logs:/var/log/nginx \
  --restart unless-stopped \
  openresty/openresty:alpine

# 测试
curl http://localhost/health
curl -H "Authorization: Bearer test-key" http://localhost/api/test
```

## 注意事项

1. **OpenResty 镜像**：使用 `openresty/openresty:alpine` 或 `openresty/openresty`
2. **配置文件路径**：OpenResty 使用 `/usr/local/openresty/nginx/conf/nginx.conf`
3. **mime.types 路径**：使用 `/usr/local/openresty/nginx/conf/mime.types`
4. **Lua 模块**：使用 OpenResty 内置的 `cjson` 模块（无需安装）
5. **HTTP 请求**：使用 `ngx.location.capture`（无需额外模块）
6. **错误处理**：确保正确处理鉴权服务不可用的情况

## 故障排除

### 配置文件路径错误

如果出现 `404 Not Found`，检查配置文件路径：

```bash
# OpenResty 使用不同的配置文件路径
-v $(pwd)/config/nginx_auth_request_post.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro
```

### mime.types 路径错误

如果出现 `mime.types not found`，确保配置中使用：

```nginx
include /usr/local/openresty/nginx/conf/mime.types;
```

### JSON 解析错误

确保响应是有效的 JSON，检查鉴权服务的响应格式。

### 超时错误

调整 lua 脚本中的超时时间（默认 5 秒）。
