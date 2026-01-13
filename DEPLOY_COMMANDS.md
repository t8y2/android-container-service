# 部署命令 - 在目标机器上执行

## 已完成: ✅ 文件上传

```bash
scp -r . a@10.253.207.190:/tmp/
```

## 接下来在目标机器上执行:

### 1. SSH 登录到目标机器

```bash
ssh a@10.253.207.190
```

### 2. 切换到上传的目录

```bash
cd /tmp/android-container-service
```

### 3. 给脚本添加执行权限

```bash
chmod +x deploy.sh
chmod +x scripts/*.sh
```

### 4. 运行部署脚本 (需要 sudo 权限)

```bash
sudo bash deploy.sh
```

**输出示例:**

```
================================
Android Container Service 部署脚本
================================

1. 创建安装目录...
✓ 目录创建完成

2. 编译程序...
✓ 编译完成 (如果已编译会跳过)

3. 复制文件到 /opt/android-container-service...
✓ 文件复制完成

4. 安装systemd服务...
✓ systemd服务安装完成

5. 配置服务...
是否启动服务? (y/n):
```

**输入 `y` 启动服务**

### 5. 验证部署成功

```bash
# 查看服务状态
sudo systemctl status android-container-service

# 测试健康检查
curl http://localhost:8080/api/container/health

# 预期响应:
# {
#   "status": "ok",
#   "service": "Android Container Service",
#   "message": "Service is running and ready to manage Android containers"
# }
```

### 6. 查看日志 (可选)

```bash
# 实时查看日志
sudo journalctl -u android-container-service -f

# 或查看日志文件
tail -f /var/log/android-container-service/android-container-service.log
```

## 常用管理命令

```bash
# 启动服务
sudo systemctl start android-container-service

# 停止服务
sudo systemctl stop android-container-service

# 重启服务
sudo systemctl restart android-container-service

# 查看服务状态
sudo systemctl status android-container-service

# 开机自启 (部署时已设置)
sudo systemctl enable android-container-service
```

## 故障排查

### 如果服务启动失败

```bash
# 查看详细错误日志
sudo journalctl -u android-container-service -n 100 --no-pager

# 手动运行测试
cd /opt/android-container-service
PORT=8080 sudo ./android-container-service
```

### 如果 Docker 命令失败

```bash
# 检查Docker是否运行
sudo systemctl status docker

# 启动Docker
sudo systemctl start docker

# 测试Docker
docker ps
```

### 如果端口被占用

```bash
# 检查8080端口
sudo netstat -tlnp | grep 8080
# 或
sudo lsof -i :8080

# 如需修改端口,编辑服务文件:
sudo vi /etc/systemd/system/android-container-service.service
# 修改 Environment="PORT=8080" 这一行
# 然后重启:
sudo systemctl daemon-reload
sudo systemctl restart android-container-service
```

## 完成! 🎉

现在你的 Android Container Service 已经部署并运行在 `10.253.207.190:8080` 上了!

可以从其他机器测试:

```bash
curl http://10.253.207.190:8080/api/container/health
```
