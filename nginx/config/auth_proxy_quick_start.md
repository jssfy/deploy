# 鉴权代理快速开始指南

## 概述

实现请求流程：`客户端 -> Nginx -> 鉴权服务(8888) -> 目标服务(8000)`

**当前实现方案**：使用 OpenResty + Lua 实现 POST 鉴权请求

## 快速使用

### 1. 使用启动脚本（推荐）

```bash
cd /Users/admin/workspace/tools/deploy/nginx

# 使用启动脚本
./scripts/start_with_post_auth.sh
```

### 2. 手动启动

```bash
# 停止现有容器
docker stop nginx-proxy 2>/dev/null || true
docker rm nginx-proxy 2>/dev/null || true

# 使用 OpenResty 启动（支持 POST 鉴权）
docker run -d --name nginx-proxy \
  -p 80:80 \
  -v $(pwd)/config/nginx_auth_request_post.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro \
  -v $(pwd)/config/proxy_with_auth.conf:/etc/nginx/proxy_with_auth.conf:ro \
  -v $(pwd)/html:/usr/share/nginx/html:ro \
  -v $(pwd)/logs:/var/log/nginx \
  --restart unless-stopped \
  openresty/openresty:alpine
```

### 3. 测试

```bash
# 健康检查（跳过鉴权）
curl http://localhost/health

# 测试鉴权代理（会调用 POST /auth/api_key）
curl -H "Authorization: Bearer test-key" http://localhost/api/test

# 或使用 X-API-Key
curl -H "X-API-Key: test-key" http://localhost/api/test
```

## 鉴权服务实现要求

鉴权服务（`localhost:8888`）需要实现 POST 接口：`POST /auth/api_key`

### 接口规范

**请求：**
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

**响应（鉴权通过）：**
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

**响应（鉴权失败）：**
- **状态码**: `401 Unauthorized` 或 `403 Forbidden`
- **响应体**: 错误信息（可选）

### 工作流程

1. Nginx 读取客户端请求的认证头（`Authorization` 或 `X-API-Key`）
2. Nginx 构建 JSON 请求体，包含认证头和原始请求信息
3. Nginx 发送 POST 请求到鉴权服务
4. 鉴权服务验证认证信息，返回 JSON 响应
5. Nginx 解析 JSON 响应，提取字段
6. Nginx 将字段添加到请求头（当前配置为示例：`X-Organization-ID`, `X-Account-ID` 等）
7. Nginx 转发原始请求到后端服务

**⚠️ 重要**：步骤6中的请求头是示例配置，请根据实际需求自定义。详见：`CUSTOMIZE_HEADERS.md`

## 示例：Python Flask 鉴权服务

```python
from flask import Flask, request, jsonify
import time

app = Flask(__name__)

@app.route('/auth/api_key', methods=['POST'])
def auth():
    """
    鉴权服务接口
    接收 POST 请求，验证认证信息，返回用户和组织信息
    """
    # 1. 读取请求体
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Invalid request body'}), 400
    
    auth_header = data.get('auth_header', '')
    uri = data.get('uri', '/')
    method = data.get('method', 'GET')
    
    # 2. 验证认证信息
    if not auth_header:
        return jsonify({'error': 'Missing auth_header'}), 401
    
    # 3. 进行鉴权检查（示例）
    if not validate_auth(auth_header):
        return jsonify({'error': 'Invalid authentication'}), 401
    
    # 4. 提取用户和组织信息
    user_info = extract_user_info(auth_header)
    
    # 5. 返回 JSON 响应
    return jsonify({
        'organization_id': user_info.get('organization_id', ''),
        'account_id': user_info.get('account_id', ''),
        'space_id': user_info.get('space_id', ''),
        'hash_key': user_info.get('hash_key', ''),
        'request_id': generate_request_id()
    }), 200

def validate_auth(auth_header):
    """验证认证信息"""
    # 实现你的鉴权逻辑
    if auth_header and (auth_header.startswith('Bearer ') or auth_header.startswith('test-')):
        return True
    return False

def extract_user_info(auth_header):
    """从认证头中提取用户信息"""
    # 实现你的用户信息提取逻辑
    return {
        'organization_id': 'org-123',
        'account_id': 'account-456',
        'space_id': 'space-789',
        'hash_key': 'hash-key-value'
    }

def generate_request_id():
    """生成请求ID"""
    return f"req-{int(time.time() * 1000)}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8888, debug=True)
```

## 配置说明

### nginx_auth_request_post.conf（当前使用）

使用 OpenResty + Lua 实现 POST 鉴权请求。

**特点：**
- ✅ 支持 POST 请求到鉴权服务
- ✅ 支持 JSON 请求体和响应
- ✅ 自动解析 JSON 并添加到请求头
- ✅ 避免单点故障（鉴权服务只负责鉴权，不负责转发）

**技术实现：**
- 使用 `ngx.location.capture` 发送内部子请求
- 使用 `cjson` 模块解析 JSON
- 使用 Lua 脚本处理鉴权逻辑

### 其他配置方案

- `nginx_auth_request.conf`: GET 鉴权方案（如果鉴权服务支持 GET）
- `nginx_auth_chain.conf`: 链式代理方案（所有请求经过鉴权服务转发）

## 注意事项

1. **性能**：每次请求都会经过鉴权服务，确保鉴权服务响应快速
2. **超时**：链式代理的超时时间设置为 120 秒，可根据需要调整
3. **错误处理**：确保鉴权服务不可用时，能返回合适的错误码
4. **请求体**：确保鉴权服务能正确处理大文件上传等场景
5. **目标服务地址**：在 Docker 容器中，使用 `host.docker.internal` 访问宿主机服务

## 故障排除

### 1. 502 Bad Gateway

**原因**：鉴权服务不可用或响应超时

**解决**：
```bash
# 检查鉴权服务是否运行
curl http://localhost:8888/health

# 检查nginx日志
docker logs nginx-proxy
tail -f logs/error.log
```

### 2. 请求头未传递

**原因**：鉴权服务未正确读取或转发请求头

**解决**：检查鉴权服务代码，确保所有请求头都被传递

### 3. 目标服务无法访问

**原因**：目标服务地址配置错误

**解决**：检查 `X-Target-Host` 和 `X-Target-Port` 是否正确

## 高级配置

如果需要更复杂的配置，可以：
1. 修改 `nginx_auth_chain.conf` 中的超时设置
2. 添加缓存（如果鉴权结果可以缓存）
3. 添加负载均衡（如果有多个鉴权服务实例）
4. 添加日志记录
