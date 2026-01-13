#!/bin/bash

# API测试脚本

BASE_URL="http://localhost:8080"

echo "================================"
echo "Container Manager API 测试"
echo "================================"
echo ""

# 1. 健康检查
echo "1. 测试健康检查..."
curl -s "${BASE_URL}/api/container/health" | jq .
echo -e "\n"

# 2. 查询容器状态
echo "2. 查询容器状态..."
curl -s "${BASE_URL}/api/container/status" | jq .
echo -e "\n"

# 3. 创建容器
echo "3. 创建容器 (BASE_PORT=5000, 数量=2)..."
TASK_ID=$(curl -s -X POST "${BASE_URL}/api/container/create" \
  -H "Content-Type: application/json" \
  -d '{
    "base_port": 5000,
    "num_containers": 2,
    "api_server": "10.50.38.3:25718"
  }' | jq -r '.task_id')

echo "任务ID: $TASK_ID"
echo -e "\n"

# 4. 等待并查询任务状态
if [ ! -z "$TASK_ID" ]; then
    echo "4. 查询任务状态..."
    sleep 2
    curl -s "${BASE_URL}/api/container/task/${TASK_ID}" | jq .
    echo -e "\n"
fi

# 5. 删除容器示例（注释掉避免误删）
echo "5. 删除容器示例 (已注释，取消注释可测试)..."
echo "# curl -X DELETE \"${BASE_URL}/api/container/delete\" \\"
echo "#   -H \"Content-Type: application/json\" \\"
echo "#   -d '{\"mode\": \"range\", \"range_begin\": 0, \"range_end\": 1}'"
echo ""

echo "================================"
echo "测试完成"
echo "================================"
