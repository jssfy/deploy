# 鉴权代理配置总览

## 当前使用的方案

**POST 鉴权方案**（推荐）：使用 OpenResty + Lua 实现 POST 请求到鉴权服务

### 快速开始

```bash
cd /Users/admin/workspace/tools/deploy/nginx

# 使用启动脚本
./scripts/start_with_post_auth.sh

# 测试
curl http://localhost/health
curl -H "Authorization: Bearer test-key" http://localhost/api/test
```

## 配置文件说明

### 主要配置文件

| 配置文件 | 说明 | 使用场景 |
|---------|------|---------|
| `nginx_auth_request_post.conf` | POST 鉴权方案（当前使用） | 鉴权服务使用 POST 接口 |
| `nginx_auth_request.conf` | GET 鉴权方案 | 鉴权服务使用 GET 接口 |
| `nginx_auth_chain.conf` | 链式代理方案 | 鉴权服务负责转发请求 |
| `proxy_with_auth.conf` | 上游服务配置 | 鉴权服务和后端服务地址 |

### 启动脚本

| 脚本 | 说明 |
|------|------|
| `start_with_post_auth.sh` | 启动 POST 鉴权方案（推荐） |
| `test_auth_request.sh` | 测试鉴权功能 |
| `find_auth_path.sh` | 查找鉴权服务路径 |

## 文档索引

### 快速指南
- **`auth_proxy_quick_start.md`** - 快速开始指南（推荐先看）
- **`AUTH_REQUEST_README.md`** - 鉴权代理使用指南
- **`POST_AUTH_SOLUTION.md`** - POST 鉴权方案详细说明

### 配置指南
- **`CUSTOMIZE_HEADERS.md`** - ⭐ 自定义请求头配置指南（重要）
- **`AUTH_PATH_CONFIG.md`** - 鉴权服务路径配置说明

### 详细文档
- **`auth_request_test_guide.md`** - 详细测试指南和示例代码
- **`DEBUG_HEADERS_GUIDE.md`** - 验证请求头指南
- **`VERIFY_HEADERS_QUICK.md`** - 快速验证请求头
- **`TROUBLESHOOTING.md`** - 故障排除指南

## 鉴权服务接口

### POST 方案（当前使用）

**接口**: `POST /auth/api_key`

**请求**:
```json
{
  "auth_header": "Bearer test-key",
  "uri": "/api/test",
  "method": "GET"
}
```

**响应**:
```json
{
  "organization_id": "org-123",
  "account_id": "account-456",
  "space_id": "space-789",
  "hash_key": "hash-key-value",
  "request_id": "req-12345"
}
```

### GET 方案（备选）

如果鉴权服务支持 GET 接口，可以使用 `nginx_auth_request.conf`。

## 技术架构

```
客户端请求
  ↓
Nginx (OpenResty + Lua)
  ↓ 读取认证头，构建 JSON
Lua 脚本
  ↓ POST /auth/api_key
鉴权服务 (localhost:8888)
  ↓ 返回 JSON
Lua 脚本解析 JSON
  ↓ 设置请求头变量
Nginx 转发请求
  ↓ 添加请求头
后端服务 (localhost:8000)
```

## 优势

✅ **避免单点故障**：鉴权服务只负责鉴权，不负责转发  
✅ **性能更好**：鉴权服务响应快速  
✅ **职责分离**：鉴权服务和后端服务各司其职  
✅ **易于扩展**：可以添加多个鉴权服务实例  
✅ **支持 POST**：使用 OpenResty + Lua 实现 POST 请求

## 重要提示

⚠️ **请求头配置是示例**：当前配置中的请求头（X-Organization-ID, X-Account-ID 等）是基于鉴权服务返回的 JSON 字段的示例配置。请根据实际需求自定义这些请求头。详见：`CUSTOMIZE_HEADERS.md`

## 常见问题

### 1. 如何自定义请求头？

查看 `CUSTOMIZE_HEADERS.md` 获取详细说明。

### 2. 如何切换鉴权方案？

修改启动脚本中的配置文件路径，或直接修改 docker run 命令。

### 3. 鉴权服务路径不对？

运行 `./scripts/find_auth_path.sh` 查找正确路径，或查看 `AUTH_PATH_CONFIG.md`。

### 4. 配置不生效？

检查：
- 配置文件路径是否正确（OpenResty 使用 `/usr/local/openresty/nginx/conf/nginx.conf`）
- mime.types 路径是否正确
- 容器是否重启

### 5. 如何验证请求头？

使用调试端点：`curl -H "Authorization: Bearer test-key" http://localhost/debug/headers`
或查看 `VERIFY_HEADERS_QUICK.md`

### 6. 需要帮助？

查看 `TROUBLESHOOTING.md` 获取故障排除指南。
