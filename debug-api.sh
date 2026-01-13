#!/bin/bash

# Android Container Service API 调试脚本
# 用于测试和调试API调用

HOST=${1:-"localhost:8080"}
UUID=${2:-"test-uuid-123"}

echo "=========================================="
echo "Android Container Service API 调试测试"
echo "Host: $HOST"
echo "UUID: $UUID"
echo "=========================================="

echo ""
echo "1. 测试健康检查..."
echo "GET /api/container/health"
curl -v http://$HOST/api/container/health
echo -e "\n"

echo ""
echo "2. 测试容器状态查询..."
echo "GET /api/container/status"
curl -v http://$HOST/api/container/status
echo -e "\n"

echo ""
echo "3. 测试删除API (正确格式)..."
echo "DELETE /api/container/delete"
echo "请求体: {\"mode\":\"uuid\",\"uuids\":[\"$UUID\"]}"
curl -v -X DELETE http://$HOST/api/container/delete \
  -H "Content-Type: application/json" \
  -d "{\"mode\":\"uuid\",\"uuids\":[\"$UUID\"]}"
echo -e "\n"

echo ""
echo "4. 测试错误的请求方法 (应该返回404)..."
echo "POST /api/container/delete (错误方法)"
curl -v -X POST http://$HOST/api/container/delete \
  -H "Content-Type: application/json" \
  -d "{\"mode\":\"uuid\",\"uuids\":[\"$UUID\"]}"
echo -e "\n"

echo ""
echo "5. 测试错误的路径 (应该返回404)..."
echo "DELETE /api/container/wrong-path"
curl -v -X DELETE http://$HOST/api/container/wrong-path \
  -H "Content-Type: application/json" \
  -d "{\"mode\":\"uuid\",\"uuids\":[\"$UUID\"]}"
echo -e "\n"

echo ""
echo "6. 测试错误的参数格式 (应该返回400)..."
echo "DELETE /api/container/delete (错误参数)"
curl -v -X DELETE http://$HOST/api/container/delete \
  -H "Content-Type: application/json" \
  -d "{\"wrong\":\"format\"}"
echo -e "\n"

echo ""
echo "7. 测试老格式参数 (应该返回400)..."
echo "DELETE /api/container/delete (老格式)"
curl -v -X DELETE http://$HOST/api/container/delete \
  -H "Content-Type: application/json" \
  -d "{\"mode\":\"range\",\"range_begin\":1,\"range_end\":5}"
echo -e "\n"

echo ""
echo "调试测试完成！"
echo ""
echo "如果看到404错误，可能的原因："
echo "1. 请求方法不正确 (应该用DELETE而不是POST)"
echo "2. URL路径不正确 (应该是/api/container/delete)"
echo "3. 服务没有正确启动"
echo "4. 路由注册有问题"
echo ""
echo "如果看到400错误，可能的原因："
echo "1. JSON格式不正确"
echo "2. 缺少必需字段(mode, uuids)"
echo "3. mode字段值不是'uuid'"
echo "4. uuids数组为空"