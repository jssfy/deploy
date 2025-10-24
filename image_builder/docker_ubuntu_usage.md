# Ubuntu Docker 镜像使用说明

本文档说明如何使用基于 Ubuntu 24.04 ARM64 的 Docker 镜像来运行 Memsys 项目。

## 文件说明

- `Dockerfile.ubuntu`: 基于华为云 Ubuntu 24.04 ARM64 镜像的优化 Dockerfile
- `build_ubuntu.sh`: 构建和运行脚本
- 环境变量配置：需要设置必要的环境变量

## 快速开始

### 1. 准备环境变量

设置必要的环境变量：

```bash
# 设置Tanka仓库认证信息
export UV_INDEX_TANKA_USERNAME="your_username"
export UV_INDEX_TANKA_PASSWORD="your_password"

# 设置其他必要的环境变量
export GEMINI_API_KEY="your_gemini_api_key"
```

必需的环境变量：
- `UV_INDEX_TANKA_USERNAME`: Tanka 仓库用户名
- `UV_INDEX_TANKA_PASSWORD`: Tanka 仓库密码  
- `GEMINI_API_KEY`: Gemini API 密钥

### 2. 构建镜像

```bash
# 使用构建脚本（推荐）
./build_ubuntu.sh

# 或者直接使用 docker build
docker build -f Dockerfile.ubuntu -t memsys-ubuntu:latest \
  --build-arg UV_INDEX_TANKA_USERNAME=$UV_INDEX_TANKA_USERNAME \
  --build-arg UV_INDEX_TANKA_PASSWORD=$UV_INDEX_TANKA_PASSWORD \
  .
```

### 3. 运行容器

```bash
# 使用构建脚本运行
./build_ubuntu.sh --run-only

# 或者直接使用 docker run
docker run --rm -it -p 1995:1995 memsys-ubuntu:v0.1.0
```

## 构建脚本使用

`build_ubuntu.sh` 脚本提供了便捷的构建和运行功能：

### 基本用法

```bash
# 构建并运行（交互式）
./build_ubuntu.sh

# 只构建镜像
./build_ubuntu.sh --build-only

# 只运行容器
./build_ubuntu.sh --run-only
```

### 高级选项

```bash
# 自定义镜像名称和标签
./build_ubuntu.sh -n my-memsys -t v1.0

# 不使用构建缓存
./build_ubuntu.sh --no-cache

# 使用自定义 Dockerfile
./build_ubuntu.sh -f Dockerfile.custom
```

### 帮助信息

```bash
./build_ubuntu.sh --help
```

## 镜像特性

### 基础镜像
- **基础镜像**: `swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/ubuntu:24.04-linuxarm64`
- **架构**: ARM64
- **Python 版本**: 3.12
- **镜像源**: 阿里云国内镜像源 (ubuntu-ports)
- **PyPI源**: 清华大学镜像源

### 已安装组件
- Python 3.12 + pip (通过 ensurepip)
- uv 包管理器
- 构建工具 (gcc, g++, build-essential)
- 系统库 (libgl1, libgomp1, ffmpeg 等)
- 基础工具 (curl, wget, git, vim 等)

### 端口配置
- **默认端口**: 1995
- **协议**: HTTP

## 环境变量

### 构建时变量
- `UV_INDEX_TANKA_USERNAME`: Tanka 仓库用户名
- `UV_INDEX_TANKA_PASSWORD`: Tanka 仓库密码

### 运行时变量
- `GEMINI_API_KEY`: Gemini API 密钥（必需）
- `MOCK_MODE`: 是否启用 Mock 模式（可选，默认 false）
- `TANKA_KAFKA_SIMPLE_MODE`: Kafka 简单模式（可选）
- `MONGODB_DATABASE`: MongoDB 数据库名（可选）
- `KAFKA_TOPIC`: Kafka 主题名（可选）

## 故障排除

### 常见问题

1. **构建失败：权限错误**
   ```bash
   # 确保环境变量已设置
   export UV_INDEX_TANKA_USERNAME="your_username"
   export UV_INDEX_TANKA_PASSWORD="your_password"
   ```

2. **运行失败：端口占用**
   ```bash
   # 检查端口占用
   lsof -i :1995
   
   # 使用不同端口
   docker run --rm -it -p 8080:1995 memsys-ubuntu:latest
   ```

3. **pip 安装 uv 失败**
   ```bash
   # 问题已在新版本中修复，使用以下方法重新构建
   ./build_ubuntu.sh --no-cache
   
   # 如果仍有问题，检查网络连接
   curl -I https://pypi.tuna.tsinghua.edu.cn/simple
   ```

4. **镜像源访问慢或失败**
   ```bash
   # 海外环境可能需要使用原始源，修改 Dockerfile.ubuntu：
   # 注释掉镜像源配置行，使用默认源
   ```

5. **依赖安装失败**
   ```bash
   # 清理构建缓存重新构建
   ./build_ubuntu.sh --no-cache
   
   # 查看详细构建日志
   docker build --progress=plain --no-cache -f Dockerfile.ubuntu .
   ```

### 调试模式

启动容器进入调试模式：

```bash
# 进入容器 shell
docker run --rm -it --entrypoint /bin/bash memsys-ubuntu:latest

# 手动运行应用
uv run python src/run.py --help
```

## 生产部署建议

1. **多阶段构建**: 考虑使用多阶段构建减小镜像大小
2. **健康检查**: 添加健康检查端点
3. **日志管理**: 配置适当的日志输出
4. **资源限制**: 设置内存和 CPU 限制
5. **安全扫描**: 定期扫描镜像安全漏洞

## 相关文档

- [项目 README](../README.md)
- [API 文档](./api_docs/)
- [开发文档](./dev_docs/)
