#!/bin/bash

# 配置
API_SERVER=${API_SERVER:-"10.50.38.3:25718"}

# 使用方法说明
show_help() {
    echo "使用方法:"
    echo "  $0 UUID1 [UUID2 ...]              # 按UUID删除"
    echo "  $0 --port PORT1 [--port PORT2]    # 按端口删除"
    echo ""
    echo "示例:"
    echo "  $0 abc123                         # 删除指定UUID的容器"
    echo "  $0 abc123 def456 ghi789           # 删除多个UUID的容器"
    echo "  $0 --port 5012                    # 删除端口5012的容器"
    echo "  $0 --port 5012 --port 5013        # 删除多个端口的容器"
    echo ""
    echo "环境变量:"
    echo "  API_SERVER: API服务器地址 (默认: 10.50.38.3:25718)"
}

# 按端口删除容器
delete_by_port() {
    local port=$1
    
    echo "----------------------------------------"
    echo "处理端口: $port"
    
    container_name="android_world_${port}"
    echo "📝 容器名称: $container_name"
    
    # 删除Docker容器
    echo "🔍 检查容器: $container_name"
    
    if sudo docker ps -a --format 'table {{.Names}}' | grep -q "^${container_name}$"; then
        echo "✅ 找到容器，开始删除: $container_name"
        sudo docker stop "$container_name" 2>/dev/null
        sudo docker rm "$container_name" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✓ Docker容器删除成功"
        else
            echo "✗ Docker容器删除失败"
        fi
    else
        echo "⚠️  Docker容器 $container_name 不存在或已被删除"
    fi
    
    echo "📝 容器删除完成"
    echo ""
}

# 从API获取UUID对应的容器信息并删除
delete_by_uuid() {
    local uuid=$1
    
    echo "----------------------------------------"
    echo "处理UUID: $uuid"
    
    # 从API获取UUID对应的容器信息
    echo "正在从数据库查询容器信息..."
    local response=$(curl -s http://$API_SERVER/api/worlds/$uuid 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "✗ 无法连接到API服务器"
        return 1
    fi
    
    # 检查是否找到记录
    if echo "$response" | grep -q '"error"'; then
        echo "⚠️  数据库中未找到UUID: $uuid"
        echo "📋 API响应: $response"
        echo "🔄 记录可能已被主API删除，但继续尝试删除Docker容器"
        # 不返回，继续尝试删除容器
        # 因为无法从数据库获取port信息，尝试多种可能的容器名称
        container_names=(
            "android_world_${uuid}"
            "android-${uuid}"
            "android_${uuid}"
        )
        echo "📝 使用默认容器名称列表: ${container_names[*]}"
    else
        echo "✅ 从数据库获取到环境信息"
        
        # 只使用 control_port 来推断容器名称
        # 尝试多种方式提取 control_port（处理不同的JSON格式）
        control_port=$(echo "$response" | grep -oP '"control_port"\s*:\s*\K[0-9]+' 2>/dev/null)
        if [ -z "$control_port" ]; then
            # 备用方法：使用 sed
            control_port=$(echo "$response" | sed -n 's/.*"control_port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
        fi
        if [ -z "$control_port" ]; then
            # 再次备用：原始的 grep 方法
            control_port=$(echo "$response" | grep -o '"control_port":[0-9]*' | cut -d':' -f2)
        fi
        
        if [ -n "$control_port" ]; then
            # 使用 control_port 构造容器名称
            container_names=(
                "android_world_${control_port}"
            )
            echo "📝 使用 control_port=${control_port}，容器名称: ${container_names[*]}"
        else
            echo "❌ 无法从响应中提取 control_port"
            echo "� API响应: $response"
            return 1
        fi
    fi
    
    # 删除Docker容器
    if [ -n "${container_names[*]}" ]; then
        container_name="${container_names[0]}"
        echo "🔍 检查容器: $container_name"
        
        if sudo docker ps -a --format 'table {{.Names}}' | grep -q "^${container_name}$"; then
            echo "✅ 找到容器，开始删除: $container_name"
            sudo docker stop "$container_name" 2>/dev/null
            sudo docker rm "$container_name" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo "✓ Docker容器删除成功"
            else
                echo "✗ Docker容器删除失败"
            fi
        else
            echo "⚠️  Docker容器 $container_name 不存在或已被删除"
        fi
    else
        echo "❌ 无法确定容器名称，跳过删除"
    fi
    
    # 注意：数据库记录由主API删除，这里不删除
    echo "📝 容器删除完成，数据库记录将由主API统一删除"
    
    echo ""
}

# 主程序
if [ $# -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

echo "开始删除容器..."
echo ""

# 检查是否是端口模式
if [ "$1" == "--port" ]; then
    # 端口模式
    while [ $# -gt 0 ]; do
        if [ "$1" == "--port" ]; then
            shift
            if [ -n "$1" ]; then
                delete_by_port "$1"
                shift
            fi
        else
            shift
        fi
    done
else
    # UUID模式
    for uuid in "$@"; do
        delete_by_uuid "$uuid"
    done
fi

echo "所有容器删除完成。"
