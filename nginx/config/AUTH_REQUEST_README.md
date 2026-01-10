# 鉴权代理使用指南

## 当前实现方案

**POST 鉴权方案**（推荐）：使用 OpenResty + Lua 实现 POST 请求到鉴权服务

## 快速开始

### 1. 启动 Nginx（POST 鉴权方案）

```bash
cd /Users/admin/workspace/tools/deploy/nginx

# 使用启动脚本（推荐）
./scripts/start_with_post_auth.sh

# 或手动启动
docker stop nginx-proxy 2>/dev/null || true
docker rm nginx-proxy 2>/dev/null || true

docker run -d --name nginx-proxy \
  -p 80:80 \
  -v $(pwd)/config/nginx_auth_request_post.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro \
  -v $(pwd)/config/proxy_with_auth.conf:/etc/nginx/proxy_with_auth.conf:ro \
  -v $(pwd)/html:/usr/share/nginx/html:ro \
  -v $(pwd)/logs:/var/log/nginx \
  --restart unless-stopped \
  openresty/openresty:alpine
```

### 2. 启动鉴权服务

确保鉴权服务运行在 `localhost:8888`，实现 `POST /auth/api_key` 接口。

### 3. 测试

```bash
# 健康检查
curl http://localhost/health

# 测试鉴权（会调用 POST /auth/api_key）
curl -H "Authorization: Bearer test-key" http://localhost/api/test
```

## 工作原理（POST 鉴权方案）

1. **客户端请求** → Nginx (80端口)
2. **Lua 脚本读取认证头** → Authorization 或 X-API-Key
3. **构建 JSON 请求体** → `{"auth_header":"...","uri":"...","method":"..."}`
4. **发送 POST 请求** → 鉴权服务 (8888端口) `POST /auth/api_key`
5. **鉴权服务响应**：
   - 200 OK + JSON 响应体（包含组织、账户等信息）
   - 或 401/403（拒绝）
6. **Lua 脚本解析 JSON** → 提取字段
7. **设置请求头变量** → X-Organization-ID, X-Account-ID 等
8. **转发原始请求** → 后端服务 (8000端口) + 添加的请求头

## 鉴权服务接口规范

### 请求

- **路径**: `/auth/api_key`
- **方法**: POST
- **Content-Type**: `application/json`
- **请求体**:
  ```json
  {
    "auth_header": "Bearer test-key",
    "uri": "/api/test",
    "method": "GET"
  }
  ```

### 响应（通过）

- **状态码**: `200 OK`
- **Content-Type**: `application/json`
- **响应体**:
  ```json
  {
    "organization_id": "org-123",
    "account_id": "account-456",
    "space_id": "space-789",
    "hash_key": "hash-key-value",
    "request_id": "req-12345"
  }
  ```

### 响应（拒绝）

- **状态码**: `401 Unauthorized` 或 `403 Forbidden`

## 配置文件说明

- `nginx_auth_request_post.conf`: 主配置文件（使用 OpenResty + Lua，支持 POST 鉴权）
- `proxy_with_auth.conf`: 鉴权服务和后端服务上游配置
- `start_with_post_auth.sh`: 启动脚本
- `auth_request_test_guide.md`: 详细测试指南和示例代码

## 关键配置点

### Lua 脚本处理鉴权

```lua
-- 读取认证头
local auth_header = ngx.var.http_authorization or ngx.var.http_x_api_key

-- 构建 JSON 请求体
local request_body = {
    auth_header = auth_header,
    uri = ngx.var.request_uri,
    method = ngx.var.request_method
}

-- 发送 POST 请求
local res = ngx.location.capture("/_auth_post", {
    method = ngx.HTTP_POST,
    body = cjson.encode(request_body)
})

-- 解析 JSON 响应
local auth_data = cjson.decode(res.body)

-- 设置变量
ngx.var.auth_organization_id = auth_data.organization_id
```

### 添加到后端请求

```nginx
# ⚠️ 注意：以下请求头是示例配置，请根据实际需求自定义
# 详细说明见：CUSTOMIZE_HEADERS.md
proxy_set_header X-Organization-ID $auth_organization_id;
proxy_set_header X-Account-ID $auth_account_id;
proxy_set_header X-Space-ID $auth_space_id;
```

**重要**：当前配置中的请求头（X-Organization-ID, X-Account-ID 等）是示例，基于鉴权服务返回的 JSON 字段。请根据实际需求自定义这些请求头。详见：`CUSTOMIZE_HEADERS.md`

## 优势

✅ **避免单点故障**：鉴权服务只负责鉴权，不负责转发  
✅ **性能更好**：鉴权服务响应快速  
✅ **职责分离**：鉴权服务和后端服务各司其职  
✅ **易于扩展**：可以添加多个鉴权服务实例

## 注意事项

1. 鉴权服务应该快速响应（建议 < 5秒）
2. 响应头中的横线会被转换为下划线（`X-User` → `$upstream_http_x_user`）
3. 如果变量为空，nginx不会设置该头部
4. auth_request默认不传递请求体（如需传递需要特殊配置）

## 故障排除

查看详细文档：`auth_request_test_guide.md`
