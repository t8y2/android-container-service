# 容器命名问题修复说明

## 问题描述

### 原来的问题

之前的脚本使用**索引**来命名容器：

```bash
CONTAINER_NAME="android_world_$i"  # i = 0, 1, 2, 3...
```

这导致了以下问题：

- 容器名称：`android_world_0`, `android_world_1`, ...
- 当你已经有 `android_world_0` 到 `android_world_9` (使用端口 5000-5009)
- 再用 `BASE_PORT=5010` 创建新容器时
- 脚本仍然尝试创建 `android_world_0`（索引从 0 开始）
- 发现容器已存在就跳过了，即使 5010 端口是空闲的

### 实际案例

```bash
# 已存在的容器（使用端口 5000-5009）
android_world_0  -> 5000:5000
android_world_1  -> 5001:5000
...
android_world_9  -> 5009:5000

# 尝试创建新容器（BASE_PORT=5010, NUM=1）
# 期望: 创建使用端口 5010 的新容器
# 实际: 检测到 android_world_0 已存在，跳过创建
```

## 解决方案

### 新的命名规则

现在使用**端口号**来命名容器：

```bash
CONTAINER_NAME="android_world_${HOST_PORT}"
```

### 命名示例

| BASE_PORT | 索引 | 控制端口 | 容器名称             | ADB 端口 |
| --------- | ---- | -------- | -------------------- | -------- |
| 5000      | 0    | 5000     | `android_world_5000` | 6556     |
| 5000      | 1    | 5001     | `android_world_5001` | 6557     |
| 5010      | 0    | 5010     | `android_world_5010` | 6566     |
| 5010      | 1    | 5011     | `android_world_5011` | 6567     |
| 6000      | 0    | 6000     | `android_world_6000` | 7556     |

## 优势

### 1. 避免命名冲突

- 不同端口的容器不会冲突
- 可以同时运行多组容器

### 2. 更清晰的识别

- 从容器名称就能知道控制端口
- 便于管理和调试

### 3. 灵活的端口分配

- 可以在任何端口范围创建容器
- 不受已有容器索引的影响

## 使用示例

### 创建不同端口范围的容器

```bash
# 第一组：端口 5000-5004
./batch-create.sh 5000 5
# 创建: android_world_5000, android_world_5001, ..., android_world_5004

# 第二组：端口 5010-5014 (不会冲突)
./batch-create.sh 5010 5
# 创建: android_world_5010, android_world_5011, ..., android_world_5014

# 第三组：端口 6000-6009
./batch-create.sh 6000 10
# 创建: android_world_6000, android_world_6001, ..., android_world_6009
```

### 查看容器

```bash
docker ps -a --filter "name=android_world_"

# 输出示例
NAMES
android_world_5000
android_world_5001
android_world_5010
android_world_6000
```

## 数据库记录

数据库中的容器记录也相应更新：

```json
{
  "uuid": "abc12345",
  "env_type": "android",
  "host": "10.253.207.190",
  "port": 5010,
  "name": "android_world_port_5010",
  "description": "Android容器 - 控制端口:5010, ADB端口:6566",
  "status": "running",
  "config": {
    "adb_port": 6566,
    "container_name": "android_world_5010"
  }
}
```

## 迁移指南

### 如果你已经有旧命名的容器

旧容器 (`android_world_0` 等) 仍然可以正常运行，不需要删除。新创建的容器会使用新的命名规则。

### 查看所有容器的端口映射

```bash
docker ps -a --format "table {{.Names}}\t{{.Ports}}" | grep android_world
```

### 清理旧容器（可选）

如果想统一使用新命名规则：

```bash
# 1. 停止并删除旧容器
docker stop android_world_0 android_world_1 # ... 等等
docker rm android_world_0 android_world_1 # ... 等等

# 2. 使用新脚本重新创建
./batch-create.sh 5000 10
```

## 注意事项

1. **端口冲突检测**

   - 脚本会检查容器名称是否存在
   - 如果 `android_world_5010` 已存在且运行，会跳过创建
   - 如果容器存在但状态异常，会重新创建

2. **端口范围规划**

   - 建议规划好端口范围，避免重叠
   - 例如：5000-5099 用于测试，6000-6999 用于生产

3. **ADB 端口计算**
   - ADB 端口 = 控制端口 + 1556
   - 确保 ADB 端口也不冲突

## 重新部署

```bash
# 1. 上传修改后的脚本
scp -r . a@10.253.207.190:/home/a/tty/android-container-service

# 2. SSH到服务器
ssh a@10.253.207.190

# 3. 测试创建新容器
cd /home/a/tty/android-container-service
./scripts/batch-create.sh 5010 1

# 4. 查看结果
docker ps -a | grep android_world_5010
```

## 验证

创建成功后应该看到：

```bash
# 日志输出
[容器0] 开始处理容器: android_world_5010 (端口: 5010)
[容器0] 容器 android_world_5010 已启动
...

# Docker 列表
docker ps | grep android_world_5010
# android_world_5010   ...   0.0.0.0:5010->5000/tcp   ...
```
