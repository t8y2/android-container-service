# Container Manager 项目结构

```
container-manager/
├── main.go                      # 主程序入口，定义路由和中间件
├── handlers.go                  # API处理器，包含业务逻辑
├── go.mod                       # Go模块依赖文件
├── README.md                    # 完整项目文档
├── QUICKSTART.md               # 快速启动指南
├── Makefile                     # 编译和部署命令
├── .env.example                 # 环境变量示例
├── .gitignore                   # Git忽略文件
├── container-manager.service    # systemd服务配置
├── deploy.sh                    # 自动部署脚本
├── test-api.sh                  # API测试脚本
└── scripts/                     # Bash脚本目录
    ├── batch-create.sh          # 批量创建容器脚本
    └── batch-delete.sh          # 批量删除容器脚本
```

## 文件说明

### Go 源代码

- **main.go**: 程序入口

  - 创建 Gin 引擎
  - 配置 CORS 中间件
  - 定义 API 路由
  - 启动 HTTP 服务器

- **handlers.go**: API 处理器
  - `CreateContainers`: 创建容器的 API 处理器
  - `DeleteContainers`: 删除容器的 API 处理器
  - `GetContainerStatus`: 查询容器状态
  - `GetTaskStatus`: 查询任务执行状态
  - `TaskManager`: 任务管理器，跟踪异步任务

### 配置文件

- **go.mod**: Go 模块依赖

  - gin 框架及其依赖

- **.env.example**: 环境变量示例

  - PORT: 服务端口
  - API_SERVER: 默认 API 服务器地址

- **container-manager.service**: systemd 服务配置
  - 用于在 Linux 服务器上作为系统服务运行

### 脚本文件

- **deploy.sh**: 自动部署脚本

  - 创建安装目录
  - 编译程序
  - 复制文件
  - 安装 systemd 服务
  - 启动服务

- **test-api.sh**: API 测试脚本

  - 测试健康检查
  - 测试容器状态查询
  - 测试创建容器
  - 测试任务状态查询

- **scripts/batch-create.sh**: 批量创建容器

  - 支持指定 BASE_PORT
  - 支持并行创建
  - 自动同步到数据库
  - 容器健康监控

- **scripts/batch-delete.sh**: 批量删除容器
  - 支持按范围删除
  - 支持按 UUID 删除
  - 支持删除所有容器
  - 自动清理数据库记录

### 工具文件

- **Makefile**: 常用命令封装
  - `make help`: 显示帮助
  - `make install`: 安装依赖
  - `make build`: 编译程序
  - `make run`: 运行程序
  - `make clean`: 清理文件
  - `make setup`: 初始化项目

### 文档

- **README.md**: 完整项目文档

  - 功能介绍
  - 安装运行
  - API 文档
  - 部署指南

- **QUICKSTART.md**: 快速启动指南
  - 本地开发步骤
  - 服务器部署步骤
  - 常用命令
  - 故障排查

## API 端点

### 容器管理

- `POST /api/container/create` - 创建容器
- `DELETE /api/container/delete` - 删除容器
- `GET /api/container/status` - 查询容器状态
- `GET /api/container/task/:id` - 查询任务状态
- `GET /api/container/health` - 健康检查

## 工作流程

### 创建容器流程

1. 接收 API 请求 (base_port, num_containers, api_server)
2. 创建异步任务
3. 调用 `batch-create.sh` 脚本
4. 脚本并行创建 Docker 容器
5. 容器启动后立即同步到数据库 (状态: starting)
6. 监控容器稳定性
7. 容器稳定后更新状态 (状态: running)
8. 返回任务 ID 供查询

### 删除容器流程

1. 接收 API 请求 (mode, range/uuids)
2. 创建异步任务
3. 调用 `batch-delete.sh` 脚本
4. 脚本查询容器 UUID
5. 停止并删除 Docker 容器
6. 删除数据库记录
7. 返回任务 ID 供查询

## 依赖关系

```
container-manager (Go服务)
    ↓
    ├─→ batch-create.sh (创建脚本)
    │       ↓
    │       └─→ Docker命令
    │           └─→ API调用 (同步到数据库)
    │
    └─→ batch-delete.sh (删除脚本)
            ↓
            ├─→ API查询 (获取UUID)
            ├─→ Docker命令
            └─→ API删除 (清理数据库)
```

## 环境要求

- Go 1.21+
- Docker
- Bash
- sudo 权限
- curl (用于 API 调用)
- parallel (用于并行执行)

## 端口使用

- 8080: 默认 HTTP 服务端口
- 5000+: Android 容器控制端口 (可配置)
- 6556+: Android 容器 ADB 端口 (自动计算: BASE_PORT + 1556)
