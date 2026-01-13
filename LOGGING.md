# Android Container Service 日志改进说明

## 问题描述

之前的日志只显示 GIN 框架的 HTTP 访问日志，缺少详细的业务逻辑和错误信息：

```
[GIN] 2025/10/28 - 16:57:05 | 200 |     135.157µs |  10.253.215.170 | POST     "/api/container/create"
```

## 改进内容

### 1. 添加详细的日志级别

- `[INFO]` - 普通信息日志
- `[WARN]` - 警告日志
- `[ERROR]` - 错误日志
- `[STDOUT]` - 脚本标准输出
- `[STDERR]` - 脚本错误输出

### 2. 请求处理日志

**创建容器 (CreateContainers)**

```
[INFO] CreateContainers - 收到创建容器请求: BasePort=5000, NumContainers=2, APIServer=10.50.38.3:25718
[INFO] CreateContainers - 使用默认API服务器: 10.50.38.3:25718
[INFO] CreateContainers - 生成任务ID: create_1698465425
[INFO] CreateContainers - 任务已创建并加入任务管理器
```

**删除容器 (DeleteContainers)**

```
[INFO] DeleteContainers - 收到删除容器请求: Mode=range
[INFO] DeleteContainers - range模式: begin=0, end=10
```

### 3. 任务执行日志

```
[INFO] Task[create_1698465425] - 开始执行异步任务
[INFO] Task[create_1698465425] - 脚本路径: ./scripts/batch-create.sh
[INFO] Task[create_1698465425] - 命令参数: [5000 2 10.50.38.3:25718]
[INFO] Task[create_1698465425] - 执行命令: /bin/bash ./scripts/batch-create.sh [5000 2 10.50.38.3:25718]
[INFO] Task[create_1698465425] - 脚本已启动，PID: 12345
```

### 4. 脚本输出实时日志

```
[STDOUT] Task[create_1698465425]: 开始并行处理 2 个容器...
[STDOUT] Task[create_1698465425]: [容器0] 开始处理容器: android_world_0
[STDOUT] Task[create_1698465425]: [容器0] 容器 android_world_0 已启动
[STDERR] Task[create_1698465425]: Error: Container failed to start
```

### 5. 任务完成日志

**成功**

```
[INFO] Task[create_1698465425] - 脚本执行成功
[INFO] Task[create_1698465425] - 任务完成，状态: completed, 耗时: 5m30s
```

**失败**

```
[ERROR] Task[create_1698465425] - 启动脚本失败: exec: "bash": executable file not found
[INFO] Task[create_1698465425] - 任务完成，状态: failed, 耗时: 10s
```

### 6. 状态查询日志

```
[INFO] GetContainerStatus - 收到获取容器状态请求
[INFO] GetContainerStatus - 查询到10个容器，其中8个运行中
[INFO] GetTaskStatus - 查询任务状态: create_1698465425
[INFO] GetTaskStatus - 任务[create_1698465425]状态: running, 输出行数: 45
```

## 使用示例

### 查看实时日志

```bash
# 实时查看所有日志
tail -f /var/log/android-container-service/android-container-service.log

# 只查看错误日志
tail -f /var/log/android-container-service/android-container-service.log | grep ERROR

# 查看特定任务的日志
tail -f /var/log/android-container-service/android-container-service.log | grep "Task\[create_"

# 查看脚本输出
tail -f /var/log/android-container-service/android-container-service.log | grep -E "STDOUT|STDERR"
```

### 通过 API 查看任务详情

创建容器后会返回 task_id，可以通过 API 查询详细信息：

```bash
# 创建容器
curl -X POST http://localhost:8080/api/container/create \
  -H "Content-Type: application/json" \
  -d '{
    "base_port": 5000,
    "num_containers": 2,
    "api_server": "10.50.38.3:25718"
  }'

# 返回示例
{
  "success": true,
  "message": "容器创建任务已启动",
  "task_id": "create_1698465425",
  ...
}

# 查询任务状态（包含所有输出）
curl http://localhost:8080/api/container/task/create_1698465425
```

## 重新部署

修改代码后需要重新编译和部署服务：

```bash
cd /home/a/tty/android_backend/android-container-service

# 编译
make build

# 重启服务
sudo systemctl restart android-container-service

# 查看日志
tail -f /var/log/android-container-service/android-container-service.log
```

## 日志文件位置

- 服务日志: `/var/log/android-container-service/android-container-service.log`
- systemd 日志: `journalctl -u android-container-service -f`

## 日志轮转

如果日志文件过大，建议配置 logrotate：

```bash
# 创建配置文件
sudo vim /etc/logrotate.d/android-container-service
```

配置内容：

```
/var/log/android-container-service/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 a a
    postrotate
        systemctl reload android-container-service > /dev/null 2>&1 || true
    endscript
}
```

## 故障排查

### 1. 看不到详细日志

- 确认已重新编译和部署
- 检查日志文件权限
- 查看 systemd 日志: `journalctl -u android-container-service -n 100`

### 2. 脚本执行失败但没有错误信息

- 检查脚本路径是否正确
- 检查脚本权限: `ls -l scripts/batch-create.sh`
- 手动执行脚本测试: `bash scripts/batch-create.sh 5000 1`

### 3. 日志过多影响性能

- 配置日志轮转
- 调整日志级别（需要修改代码）
- 使用 grep 过滤只看重要日志
