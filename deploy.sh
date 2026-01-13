#!/bin/bash

# Android Container Service 部署脚本

set -e

INSTALL_DIR="/opt/android-container-service"
LOG_DIR="/var/log/android-container-service"
SERVICE_FILE="android-container-service.service"

echo "================================"
echo "Android Container Service 部署脚本"
echo "================================"
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行此脚本"
    echo "使用: sudo $0"
    exit 1
fi

# 1. 创建目录
echo "1. 创建安装目录..."
mkdir -p $INSTALL_DIR
mkdir -p $INSTALL_DIR/scripts
mkdir -p $LOG_DIR
echo "✓ 目录创建完成"

# 2. 编译程序
echo ""
echo "2. 检查程序文件..."
if [ ! -f "android-container-service" ]; then
    if command -v go &> /dev/null; then
        echo "编译Go程序..."
        go build -o android-container-service .
        echo "✓ 编译完成"
    else
        echo "❌ 错误: 未找到可执行文件 'android-container-service'"
        echo ""
        echo "请先编译程序："
        echo "  方法1: 在本地编译后上传"
        echo "    本地运行: ./build-linux.sh"
        echo "    然后上传 android-container-service 文件到服务器"
        echo ""
        echo "  方法2: 在服务器上安装 Go"
        echo "    参考: https://golang.org/doc/install"
        echo ""
        exit 1
    fi
else
    echo "✓ 找到可执行文件"
fi

# 3. 复制文件
echo ""
echo "3. 复制文件到 $INSTALL_DIR..."
cp android-container-service $INSTALL_DIR/
cp scripts/*.sh $INSTALL_DIR/scripts/
chmod +x $INSTALL_DIR/android-container-service
chmod +x $INSTALL_DIR/scripts/*.sh
echo "✓ 文件复制完成"

# 4. 安装systemd服务
echo ""
echo "4. 安装systemd服务..."
cp $SERVICE_FILE /etc/systemd/system/
systemctl daemon-reload
echo "✓ systemd服务安装完成"

# 5. 配置服务
echo ""
echo "5. 配置服务..."
read -p "是否启动服务? (y/n): " start_service
if [ "$start_service" = "y" ] || [ "$start_service" = "Y" ]; then
    systemctl start android-container-service
    systemctl enable android-container-service
    echo "✓ 服务已启动并设置为开机自启"
else
    echo "跳过服务启动"
    echo "稍后可使用以下命令启动:"
    echo "  sudo systemctl start android-container-service"
    echo "  sudo systemctl enable android-container-service"
fi

# 6. 显示状态
echo ""
echo "================================"
echo "部署完成!"
echo "================================"
echo ""
echo "服务状态:"
systemctl status android-container-service --no-pager || true
echo ""
echo "有用的命令:"
echo "  查看状态: sudo systemctl status android-container-service"
echo "  启动服务: sudo systemctl start android-container-service"
echo "  停止服务: sudo systemctl stop android-container-service"
echo "  重启服务: sudo systemctl restart android-container-service"
echo "  查看日志: sudo journalctl -u android-container-service -f"
echo "  或查看: tail -f $LOG_DIR/android-container-service.log"
echo ""
echo "测试API:"
echo "  curl http://localhost:8080/api/container/health"
echo ""
