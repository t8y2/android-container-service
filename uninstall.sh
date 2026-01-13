#!/bin/bash

# Android Container Service 卸载脚本

set -e

INSTALL_DIR="/opt/android-container-service"
LOG_DIR="/var/log/android-container-service"
SERVICE_FILE="/etc/systemd/system/android-container-service.service"

echo "================================"
echo "Android Container Service 卸载脚本"
echo "================================"
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行此脚本"
    echo "使用: sudo $0"
    exit 1
fi

# 1. 停止服务
echo "1. 停止服务..."
if systemctl is-active --quiet android-container-service; then
    systemctl stop android-container-service
    echo "✓ 服务已停止"
else
    echo "服务未运行"
fi

# 2. 禁用服务
echo ""
echo "2. 禁用服务..."
if systemctl is-enabled --quiet android-container-service 2>/dev/null; then
    systemctl disable android-container-service
    echo "✓ 服务已禁用"
else
    echo "服务未启用"
fi

# 3. 删除systemd服务文件
echo ""
echo "3. 删除systemd服务文件..."
if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl reset-failed
    echo "✓ 服务文件已删除"
else
    echo "服务文件不存在"
fi

# 4. 删除安装目录
echo ""
echo "4. 删除安装目录..."
read -p "是否删除安装目录 $INSTALL_DIR? (y/n): " delete_install
if [ "$delete_install" = "y" ] || [ "$delete_install" = "Y" ]; then
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "✓ 安装目录已删除"
    else
        echo "安装目录不存在"
    fi
else
    echo "保留安装目录"
fi

# 5. 删除日志目录
echo ""
echo "5. 删除日志目录..."
read -p "是否删除日志目录 $LOG_DIR? (y/n): " delete_logs
if [ "$delete_logs" = "y" ] || [ "$delete_logs" = "Y" ]; then
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"
        echo "✓ 日志目录已删除"
    else
        echo "日志目录不存在"
    fi
else
    echo "保留日志目录"
fi

# 6. 显示结果
echo ""
echo "================================"
echo "卸载完成!"
echo "================================"
echo ""
echo "服务已完全移除"
echo ""
echo "如果需要重新安装，运行: sudo ./deploy.sh"
echo ""
