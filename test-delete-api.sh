#!/bin/bash

# 测试删除 API
# 用法: ./test-delete-api.sh <host> <uuid>

HOST=${1:-"localhost"}
UUID=${2:-"test-uuid-123"}

echo "========================================="
echo "测试 Android Container Service 删除 API"
echo "========================================="
echo "目标主机: $HOST"
echo "测试 UUID: $UUID"
echo ""

# 测试 DELETE 方法
echo "1. 测试 DELETE /api/container/delete"
echo "-----------------------------------"
curl -v -X DELETE "http://${HOST}:8080/api/container/delete" \
  -H "Content-Type: application/json" \
  -d "{\"mode\":\"uuid\",\"uuids\":[\"${UUID}\"]}" \
  2>&1 | grep -E "HTTP|404|200|error|success"

echo ""
echo ""

# 测试 POST 方法（兼容模式）
echo "2. 测试 POST /api/container/delete (兼容模式)"
echo "-----------------------------------"
curl -v -X POST "http://${HOST}:8080/api/container/delete" \
  -H "Content-Type: application/json" \
  -d "{\"mode\":\"uuid\",\"uuids\":[\"${UUID}\"]}" \
  2>&1 | grep -E "HTTP|404|200|error|success"

echo ""
echo ""

# 测试健康检查
echo "3. 测试 GET /api/container/health"
echo "-----------------------------------"
curl -s "http://${HOST}:8080/api/container/health" | jq . || echo "服务未响应"

echo ""
echo "========================================="
echo "测试完成"
echo "========================================="
