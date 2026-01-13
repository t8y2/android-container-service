#!/bin/bash

# 开放8080端口的防火墙脚本

echo "================================"
echo "开放8080端口防火墙"
echo "================================"
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行此脚本"
    echo "使用: sudo $0"
    exit 1
fi

# 检测并配置防火墙
if command -v ufw &> /dev/null; then
    echo "检测到 UFW 防火墙"
    ufw allow 8080/tcp
    ufw status
    echo "✓ UFW规则已添加"
    
elif command -v firewall-cmd &> /dev/null; then
    echo "检测到 Firewalld 防火墙"
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --reload
    firewall-cmd --list-ports
    echo "✓ Firewalld规则已添加"
    
elif command -v iptables &> /dev/null; then
    echo "检测到 iptables 防火墙"
    iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
    # 保存规则（不同系统命令不同）
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        iptables-save > /etc/sysconfig/iptables 2>/dev/null || \
        echo "⚠️  请手动保存iptables规则"
    fi
    echo "✓ iptables规则已添加"
    
else
    echo "⚠️  未检测到常见防火墙工具"
    echo "如果在云服务器上，请检查云服务商的安全组设置"
fi

echo ""
echo "================================"
echo "配置完成"
echo "================================"
echo ""
echo "如果在云服务器上（阿里云/腾讯云/AWS等），还需要："
echo "1. 登录云服务商控制台"
echo "2. 找到安全组/防火墙设置"
echo "3. 添加入站规则：允许TCP 8080端口"
echo ""
