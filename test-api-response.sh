#!/bin/bash
# 测试 API 响应内容
UUID=${1:-"b3f5d3d5"}
API_SERVER=${2:-"10.50.38.3:25718"}

echo "测试 UUID: $UUID"
echo "API Server: $API_SERVER"
echo "=========================================="
echo ""

response=$(curl -s "http://$API_SERVER/api/worlds/$UUID")
echo "完整响应:"
echo "$response" | jq . 2>/dev/null || echo "$response"
echo ""
echo "=========================================="
echo "提取 control_port:"
echo "$response" | grep -o '"control_port":[0-9]*' | cut -d':' -f2
echo ""
echo "提取 container_name:"
echo "$response" | grep -o '"container_name":"[^"]*"' | cut -d'"' -f4
