# 快速启动指南

## 本地开发

### 1. 安装依赖

```bash
cd container-manager
make install
```

### 2. 运行服务

```bash
# 方式1: 使用make
make run

# 方式2: 直接运行
go run .

# 方式3: 编译后运行
make build
./container-manager
```

### 3. 测试 API

```bash
# 健康检查
curl http://localhost:8080/api/container/health

# 或使用测试脚本
./test-api.sh
```

## 服务器部署

### 方式 1: 使用部署脚本 (推荐)

```bash
# 1. 上传整个container-manager目录到服务器
scp -r container-manager user@server:/tmp/

# 2. SSH到服务器
ssh user@server

# 3. 运行部署脚本
cd /tmp/container-manager
sudo ./deploy.sh
```

### 方式 2: 手动部署

```bash
# 1. 编译
go build -o container-manager

# 2. 创建目录
sudo mkdir -p /opt/container-manager/scripts
sudo mkdir -p /var/log/container-manager

# 3. 复制文件
sudo cp container-manager /opt/container-manager/
sudo cp scripts/*.sh /opt/container-manager/scripts/
sudo chmod +x /opt/container-manager/container-manager
sudo chmod +x /opt/container-manager/scripts/*.sh

# 4. 安装systemd服务
sudo cp container-manager.service /etc/systemd/system/
sudo systemctl daemon-reload

# 5. 启动服务
sudo systemctl start container-manager
sudo systemctl enable container-manager

# 6. 查看状态
sudo systemctl status container-manager
```

## 常用命令

### 服务管理

```bash
# 查看状态
sudo systemctl status container-manager

# 启动服务
sudo systemctl start container-manager

# 停止服务
sudo systemctl stop container-manager

# 重启服务
sudo systemctl restart container-manager

# 查看日志
sudo journalctl -u container-manager -f
# 或
tail -f /var/log/container-manager/container-manager.log
```

### Make 命令

```bash
make help      # 查看所有可用命令
make install   # 安装依赖
make build     # 编译程序
make run       # 运行程序
make clean     # 清理编译文件
make setup     # 初始化项目
```

## API 使用示例

### 创建 10 个容器

```bash
curl -X POST http://localhost:8080/api/container/create \
  -H "Content-Type: application/json" \
  -d '{
    "base_port": 5000,
    "num_containers": 10,
    "api_server": "10.50.38.3:25718"
  }'
```

### 删除容器 0-9

```bash
curl -X DELETE http://localhost:8080/api/container/delete \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "range",
    "range_begin": 0,
    "range_end": 9
  }'
```

### 查询容器状态

```bash
curl http://localhost:8080/api/container/status
```

### 查询任务状态

```bash
curl http://localhost:8080/api/container/task/create_1698345678
```

## 故障排查

### 服务无法启动

```bash
# 查看详细错误日志
sudo journalctl -u container-manager -n 50

# 检查端口是否被占用
sudo lsof -i :8080

# 检查脚本权限
ls -la /opt/container-manager/scripts/
```

### 脚本执行失败

```bash
# 手动测试脚本
cd /opt/container-manager/scripts
sudo bash batch-create.sh --help

# 查看脚本日志
tail -f /var/log/container-manager/container-manager.log
```

### Docker 权限问题

```bash
# 确保服务以root运行，或添加用户到docker组
sudo usermod -aG docker $USER
```

## 配置修改

### 修改端口

```bash
# 编辑systemd服务文件
sudo vim /etc/systemd/system/container-manager.service

# 修改Environment="PORT=8080"为其他端口
# 保存后重新加载
sudo systemctl daemon-reload
sudo systemctl restart container-manager
```

### 修改 API 服务器地址

在创建容器时指定 `api_server` 参数，或修改默认值。

## 更新部署

```bash
# 1. 拉取最新代码
git pull

# 2. 重新编译
make build

# 3. 停止服务
sudo systemctl stop container-manager

# 4. 替换二进制文件
sudo cp container-manager /opt/container-manager/

# 5. 启动服务
sudo systemctl start container-manager

# 6. 查看状态
sudo systemctl status container-manager
```
