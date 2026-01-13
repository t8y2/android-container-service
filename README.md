# Android Container Service# Android Container Service# Container Manager Service

一个用 Go 编写的 Android 容器管理服务,提供 REST API 来批量创建和删除 Android 容器。专门用于管理 Android World 容器的 Go 服务,对接 cogagent-world-web 项目的 Android 环境创建和删除 API。Android 容器管理服务，基于 Go + Gin 框架，用于管理 Android World 容器的创建和删除。

## 🚀 快速部署到金属机## ⚠️ 重要说明## 功能特性

### 一键部署**此服务专门用于 Android 环境,不支持 android_web 或其他环境类型。**- ✅ 批量创建 Android 容器

`````bash- ✅ 多种方式删除容器（范围、UUID、全部）

# 1. 上传到目标机器

scp -r android-container-service/ root@目标机器IP:/tmp/## 🚀 快速开始- ✅ 查询容器状态



# 2. SSH登录并部署- ✅ 异步任务执行

ssh root@目标机器IP

cd /tmp/android-container-service````bash- ✅ 实时输出日志

sudo bash deploy.sh

```# 编译并运行- ✅ RESTful API 设计



**就这么简单!** 🎉make build



部署脚本会自动:./android-container-service## 目录结构

- ✅ 编译Go程序

- ✅ 创建安装目录 `/opt/android-container-service`

- ✅ 复制程序和脚本

- ✅ 安装systemd服务# 或直接运行```

- ✅ 启动服务(可选)

make runcontainer-manager/

### 本地编译后部署 (如果目标机没有Go)

├── main.go           # 主程序入口

```bash

# 在Mac上编译Linux版本# 测试API├── handlers.go       # API处理器

cd android-container-service

GOOS=linux GOARCH=amd64 go build -o android-container-service .curl http://localhost:8080/api/container/health├── go.mod           # Go模块依赖



# 然后上传并部署```├── scripts/         # Bash脚本目录

scp -r . root@目标机器IP:/tmp/android-container-service/

ssh root@目标机器IP "cd /tmp/android-container-service && sudo bash deploy.sh"│   ├── batch-create.sh

`````

## 📦 主要功能 │ └── batch-delete.sh

## 📡 API 接口

└── README.md

### 1. 健康检查

`bash1. **批量创建Android容器** - 自动计算端口,同步到主项目数据库`

GET /api/container/health

```````2. **删除容器** - 支持范围/UUID/全部删除,自动清理数据库



### 2. 创建容器3. **状态查询** - 实时查看所有容器状态## 安装运行

```bash

POST /api/container/create4. **任务追踪** - 异步任务执行,可查询进度

{

  "host": "10.50.38.3",### 1. 安装依赖

  "base_port": 5000,

  "num_containers": 3## 📝 详细文档

}

``````bash



### 3. 删除容器请查看 [QUICKSTART.md](./QUICKSTART.md) 了解更多使用方法。cd container-manager



按UUID删除:go mod download

```bash

POST /api/container/delete## 🔗 对接的API```

{

  "uuids": ["uuid1", "uuid2"]

}

```- 创建: `POST http://{API_SERVER}/api/worlds/create`### 2. 准备脚本



按范围删除:- 删除: `DELETE http://{API_SERVER}/api/worlds/{uuid}`

```bash

POST /api/container/delete将 `batch-create.sh` 和 `batch-delete.sh` 复制到 `scripts/` 目录：

{

  "start_index": 1,服务默认API服务器: `10.50.38.3:25718`

  "end_index": 3

}```bash

```mkdir -p scripts

cp ../参考/batch-create.sh scripts/

### 4. 查询任务状态cp ../参考/batch-delete.sh scripts/

```bashchmod +x scripts/*.sh

GET /api/container/task/:task_id````

```````

### 3. 运行服务

### 5. 查询容器状态

`bash`bash

GET /api/container/status# 默认端口 8080

````go run .



## 🔧 服务管理# 或指定端口

PORT=9000 go run .

部署完成后的管理命令:```



```bash### 4. 编译部署

# 查看服务状态

sudo systemctl status android-container-service```bash

# 编译

# 启动/停止/重启go build -o container-manager

sudo systemctl start android-container-service

sudo systemctl stop android-container-service# 运行

sudo systemctl restart android-container-service./container-manager



# 查看日志# 后台运行

sudo journalctl -u android-container-service -fnohup ./container-manager > container-manager.log 2>&1 &

````

# 或查看日志文件

tail -f /var/log/android-container-service/android-container-service.log## API 文档

````

### 1. 创建容器

## 🧪 测试

**POST** `/api/container/create`

```bash

# 测试服务是否正常请求体:

curl http://localhost:8080/api/container/health

```json

# 预期响应:{

# {  "base_port": 5000,

#   "status": "ok",  "num_containers": 10,

#   "service": "Android Container Service",  "api_server": "10.50.38.3:25718"

#   "message": "Service is running and ready to manage Android containers"}

# }```

````

响应:

## 📁 部署后的文件位置

````json

```{

/opt/android-container-service/  "success": true,

├── android-container-service      # 主程序  "message": "容器创建任务已启动",

└── scripts/  "task_id": "create_1698345678",

    ├── batch-create.sh           # 批量创建脚本  "data": {

    └── batch-delete.sh           # 批量删除脚本    "base_port": 5000,

    "num_containers": 10,

/etc/systemd/system/    "api_server": "10.50.38.3:25718"

└── android-container-service.service  # systemd服务  }

}

/var/log/android-container-service/```

├── android-container-service.log       # 输出日志

└── android-container-service-error.log # 错误日志### 2. 删除容器

````

**DELETE** `/api/container/delete`

## ⚙️ 配置

#### 2.1 按范围删除

环境变量 (在 `android-container-service.service` 中配置):

- `PORT`: 服务端口 (默认: 8080)```json

- `API_SERVER`: 主 API 服务器地址 (默认: 10.50.38.3:25718){

  "mode": "range",

## 📚 详细文档 "range_begin": 0,

"range_end": 9

- **[部署指南.md](./部署指南.md)** - 详细的部署步骤、配置和故障排查}

- **[QUICKSTART.md](./QUICKSTART.md)** - 快速开始指南```

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - 架构设计文档

#### 2.2 按 UUID 删除

## 🛠️ 本地开发

````json

```bash{

# 安装依赖  "mode": "uuid",

go mod download  "uuids": ["abc123de", "def456ab"]

}

# 编译```

make build

#### 2.3 删除所有

# 运行

make run```json

{

# 或直接运行  "mode": "all"

PORT=8080 ./android-container-service}

````

## 🔄 更新服务响应:

当代码更新后:```json

{

```bash "success": true,

# 停止服务  "message": "容器删除任务已启动",

sudo systemctl stop android-container-service  "task_id": "delete_1698345678",

  "data": {

# 重新编译    "mode": "range"

cd /path/to/source  }

GOOS=linux GOARCH=amd64 go build -o android-container-service .}

```

# 复制新程序

sudo cp android-container-service /opt/android-container-service/### 3. 查询容器状态

# 启动服务**GET** `/api/container/status`

sudo systemctl start android-container-service

````响应:



或直接重新运行部署脚本:```json

```bash{

sudo bash deploy.sh  "success": true,

```  "data": {

    "total_containers": 10,

## 📝 License    "running_containers": 8,

    "containers": [

MIT      {

        "name": "android_world_0",
        "status": "Up 2 hours",
        "ports": "0.0.0.0:5000->5000/tcp, 0.0.0.0:6556->5556/tcp",
        "created_at": "2024-10-27 10:30:00"
      }
    ]
  }
}
````

### 4. 查询任务状态

**GET** `/api/container/task/:id`

响应:

```json
{
  "success": true,
  "data": {
    "id": "create_1698345678",
    "type": "create",
    "status": "running",
    "output": ["[容器0] 开始处理容器: android_world_0", "[容器0] 容器 android_world_0 已启动"],
    "start_time": "2024-10-27T10:30:00Z",
    "end_time": "2024-10-27T10:35:00Z"
  }
}
```

### 5. 健康检查

**GET** `/api/container/health`

响应:

```json
{
  "status": "ok",
  "message": "Container Manager Service is running"
}
```

## 使用示例

### 使用 curl

```bash
# 创建10个容器，从端口5000开始
curl -X POST http://localhost:8080/api/container/create \
  -H "Content-Type: application/json" \
  -d '{
    "base_port": 5000,
    "num_containers": 10,
    "api_server": "10.50.38.3:25718"
  }'

# 删除容器0-9
curl -X DELETE http://localhost:8080/api/container/delete \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "range",
    "range_begin": 0,
    "range_end": 9
  }'

# 查询容器状态
curl http://localhost:8080/api/container/status

# 查询任务状态
curl http://localhost:8080/api/container/task/create_1698345678
```

### 使用 JavaScript (fetch)

```javascript
// 创建容器
const createContainers = async () => {
  const response = await fetch('http://localhost:8080/api/container/create', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      base_port: 5000,
      num_containers: 10,
      api_server: '10.50.38.3:25718',
    }),
  });
  const result = await response.json();
  console.log(result);
};

// 删除容器
const deleteContainers = async () => {
  const response = await fetch('http://localhost:8080/api/container/delete', {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      mode: 'range',
      range_begin: 0,
      range_end: 9,
    }),
  });
  const result = await response.json();
  console.log(result);
};

// 查询状态
const getStatus = async () => {
  const response = await fetch('http://localhost:8080/api/container/status');
  const result = await response.json();
  console.log(result);
};
```

## 环境变量

- `PORT`: 服务监听端口（默认: 8080）
- `API_SERVER`: 默认 API 服务器地址（可在请求中覆盖）

## 注意事项

1. **权限要求**: 脚本需要 sudo 权限执行 docker 命令，确保服务运行用户有相应权限
2. **脚本路径**: 确保 `scripts/` 目录下有可执行的 bash 脚本
3. **端口冲突**: 创建容器时注意端口不要冲突
4. **任务超时**: 创建任务最长 30 分钟，删除任务最长 10 分钟
5. **并发限制**: 脚本中的 `PARALLEL_JOBS` 控制并行数量

## 部署建议

### 使用 systemd 服务

创建 `/etc/systemd/system/container-manager.service`:

```ini
[Unit]
Description=Container Manager Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/container-manager
ExecStart=/path/to/container-manager/container-manager
Restart=on-failure
RestartSec=10
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
```

启动服务:

```bash
sudo systemctl daemon-reload
sudo systemctl start container-manager
sudo systemctl enable container-manager
sudo systemctl status container-manager
```

### 使用 Docker 部署

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN go build -o container-manager

FROM alpine:latest
RUN apk add --no-cache bash docker-cli sudo
WORKDIR /app
COPY --from=builder /app/container-manager .
COPY scripts/ ./scripts/
RUN chmod +x scripts/*.sh
EXPOSE 8080
CMD ["./container-manager"]
```

## 许可证

MIT License
