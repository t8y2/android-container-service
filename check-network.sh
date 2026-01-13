#!/bin/bash

echo "================================"
echo "网络访问诊断脚本"
echo "================================"
echo ""

# 1. 检查服务是否运行
echo "1. 检查服务状态:"
systemctl is-active android-container-service && echo "✓ 服务正在运行" || echo "✗ 服务未运行"
echo ""

# 2. 检查端口监听
echo "2. 检查端口监听 (8080):"
if command -v lsof &> /dev/null; then
    lsof -i :8080 || echo "端口8080未被监听"
elif command -v netstat &> /dev/null; then
    netstat -an | grep 8080 || echo "端口8080未被监听"
else
    echo "无法检查端口状态（需要lsof或netstat命令）"
fi
echo ""

# 3. 测试本地访问
echo "3. 测试本地访问:"
curl -s http://localhost:8080/api/container/health && echo "" || echo "✗ 本地访问失败"
echo ""

# 4. 获取本机IP
echo "4. 本机IP地址:"
if command -v ip &> /dev/null; then
    ip addr show | grep "inet " | grep -v 127.0.0.1
elif command -v ifconfig &> /dev/null; then
    ifconfig | grep "inet " | grep -v 127.0.0.1
fi
echo ""

# 5. 检查防火墙状态
echo "5. 检查防火墙状态:"
if command -v ufw &> /dev/null; then
    echo "UFW 防火墙:"
    sudo ufw status
elif command -v firewall-cmd &> /dev/null; then
    echo "Firewalld 防火墙:"
    sudo firewall-cmd --list-all
elif command -v iptables &> /dev/null; then
    echo "iptables 规则:"
    sudo iptables -L -n | grep 8080 || echo "未找到8080端口相关规则"
else
    echo "未检测到常见防火墙工具"
fi
echo ""

# 6. 测试公网IP访问（如果有）
echo "6. 建议测试命令:"
echo "从其他机器测试: curl http://YOUR_PUBLIC_IP:8080/api/container/health"
echo ""

echo "================================"
echo "诊断完成"
echo "================================"
