#!/bin/bash

# 基础镜像和配置
IMAGE="android_world:setup"
BASE_PORT=${1:-5000}  # 基础控制端口，默认为5000，可通过第一个参数传递
NUM_CONTAINERS=${2:-2} # 新建容器数量，默认为2，可通过第二个参数传递
API_SERVER=${3:-"10.50.38.3:25718"} # API服务器地址，默认为10.50.38.3:25718，可通过第三个参数传递
PORT_OFFSET=1556  # ADB端口和控制端口之间的固定间隔
MAX_RETRIES=5
CHECK_INTERVAL=30  # 检查间隔（秒）
SUCCESS_TIMEOUT=600  # 成功超时时间（秒，10分钟）
PARALLEL_JOBS=10  # 并行作业数

# 启动单个容器的函数
start_single_container() {
    local i=$1
    local HOST_PORT=$((BASE_PORT + i))
    local ADB_PORT=$((HOST_PORT + PORT_OFFSET))  # ADB端口 = 控制端口 + 1556
    local CONTAINER_NAME="android_world_${HOST_PORT}"  # 使用端口号命名，避免冲突
    local start_time=$(date +%s)
    
    echo "[容器$i] 开始处理容器: $CONTAINER_NAME (端口: $HOST_PORT)"
    
    for ((retry=1; retry<=MAX_RETRIES; retry++)); do
        echo "[容器$i] 尝试 $retry/$MAX_RETRIES: 启动容器 $CONTAINER_NAME, 端口: $HOST_PORT:5000, ADB 端口: $ADB_PORT:5556"
        
        # 清理可能存在的同名容器
        sudo docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
        
        # 启动容器（后台运行）
        sudo docker run -d \
            --name "$CONTAINER_NAME" \
            --privileged \
            -p $HOST_PORT:5000 \
            -p $ADB_PORT:5556 \
            -v /home/a/liwenkai/android_world:/aw \
            -e HTTP_PROXY=http://host.docker.internal:7897 \
            -e HTTPS_PROXY=http://host.docker.internal:7897 \
            -e NO_PROXY=localhost,127.0.0.1 \
            --add-host host.docker.internal:host-gateway \
            "$IMAGE" 
        
        if [ $? -eq 0 ]; then
            echo "[容器$i] 容器 $CONTAINER_NAME 已启动"
            
            # 立即同步到数据库（状态为启动中）
            sync_to_database $i "starting"
            
            echo "[容器$i] 开始监控容器状态..."
            
            # 监控容器状态
            local monitor_start=$(date +%s)
            local container_stable=false
            
            while true; do
                local current_time=$(date +%s)
                local elapsed=$((current_time - monitor_start))
                
                # 检查容器状态
                local status=$(sudo docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
                
                if [ "$status" != "running" ]; then
                    echo "[容器$i] ✗ 容器 $CONTAINER_NAME 状态异常: $status (监控时间: ${elapsed}s)"
                    sudo docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
                    break  # 跳出监控循环，进入下次重试
                else
                    echo "[容器$i] 容器 $CONTAINER_NAME 运行正常 (监控时间: ${elapsed}s)"
                fi
                
                # 检查是否达到成功超时时间
                if [ $elapsed -ge $SUCCESS_TIMEOUT ]; then
                    echo "[容器$i] ✓ 容器 $CONTAINER_NAME 运行稳定 (${SUCCESS_TIMEOUT}s)，视为成功启动"
                    # 更新数据库状态为运行中
                    sync_to_database $i "running"
                    container_stable=true
                    break
                fi
                
                # 显示监控进度（每分钟显示一次）
                # if [ $((elapsed % 60)) -eq 0 ] && [ $elapsed -gt 0 ]; then
                #     local remaining=$((SUCCESS_TIMEOUT - elapsed))
                #     echo "[容器$i] 容器 $CONTAINER_NAME 运行正常，剩余监控时间: ${remaining}s"
                # fi
                
                sleep $CHECK_INTERVAL
            done
            
            # 如果容器稳定运行，返回成功
            if [ "$container_stable" = true ]; then
                return 0
            fi
        else
            echo "[容器$i] ✗ 容器 $CONTAINER_NAME 启动失败"
        fi
        
        # 如果不是最后一次重试，等待一下再重试
        if [ $retry -lt $MAX_RETRIES ]; then
            echo "[容器$i] 等待10秒后重试..."
            sleep 10
        fi
    done
    
    echo "[容器$i] ✗ 容器 $CONTAINER_NAME 启动失败，已达到最大重试次数"
    return 1
}

# 检查现有容器状态的函数
check_existing_container() {
    local i=$1
    local HOST_PORT=$((BASE_PORT + i))
    local CONTAINER_NAME="android_world_${HOST_PORT}"  # 使用端口号命名
    
    # 检查容器是否存在及其状态
    if sudo docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "^${CONTAINER_NAME}\s"; then
        local status=$(sudo docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
        if [ "$status" == "running" ]; then
            echo "[容器$i] ✓ 容器 $CONTAINER_NAME 已运行，跳过"
            return 0
        else
            echo "[容器$i] 容器 $CONTAINER_NAME 状态异常 ($status)，将重新创建"
            return 1
        fi
    else
        echo "[容器$i] 容器 $CONTAINER_NAME 不存在，需要创建"
        return 1
    fi
}

# 安装 socat 并配置转发
install_socat_and_forward() {
    local i=$1
    local HOST_PORT=$((BASE_PORT + i))
    local CONTAINER_NAME="android_world_${HOST_PORT}"  # 使用端口号命名

    echo "[容器$i] 安装socat..."
    if sudo docker exec "$CONTAINER_NAME" bash -c "apt install -y socat"; then
        echo "[容器$i] socat安装成功"
        
        # 启动socat端口转发（后台运行）
        echo "[容器$i] 启动socat端口转发..."
        sudo docker exec -d "$CONTAINER_NAME" socat TCP-LISTEN:5556,bind=0.0.0.0,fork,reuseaddr TCP:127.0.0.1:5555
        
        if [ $? -eq 0 ]; then
            echo "[容器$i] socat端口转发启动成功"
            return 0
        else
            echo "[容器$i] ✗ socat端口转发启动失败"
        fi
    else
        echo "[容器$i] ✗ socat安装失败"
    fi
}

# 调用API同步容器信息到数据库
sync_to_database() {
    local i=$1
    local status=${2:-"starting"}  # 默认状态为starting，可以传入其他状态如running
    local HOST_PORT=$((BASE_PORT + i))
    local ADB_PORT=$((HOST_PORT + PORT_OFFSET))  # ADB端口 = 控制端口 + 1556
    local CONTAINER_NAME="android_world_${HOST_PORT}"  # 使用端口号命名
    local LOCAL_IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i !~ /^127\./) {print $i; exit}}')
    
    echo "[容器$i] 开始同步容器信息到数据库(状态: $status)..."
    
    # 使用全局变量存储UUID，确保同一容器使用相同UUID
    local uuid_var="CONTAINER_${i}_UUID"
    local uuid=${!uuid_var}
    
    if [ -z "$uuid" ]; then
        # 第一次调用，生成新UUID并存储到全局变量
        uuid=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c8)
        declare -g "$uuid_var=$uuid"
        echo "[容器$i] 生成新UUID: $uuid (首次创建)"
    else
        echo "[容器$i] 使用现有UUID: $uuid (状态更新)"
    fi

    # 构建API请求的JSON数据
    local json_data=$(cat <<EOF
{
    "uuid": "$uuid",
    "env_type": "android",
    "host": "$LOCAL_IP",
    "port": $HOST_PORT,
    "name": "android_world_port_${HOST_PORT}",
    "description": "Android容器 - 控制端口:$HOST_PORT, ADB端口:$ADB_PORT",
    "status": "$status",
    "config": {
        "adb_port": $ADB_PORT,
        "container_name": "$CONTAINER_NAME"
    }
}
EOF
)
    
    # 调用API（现在create-android-world.js支持upsert操作）
    local response=$(curl -s -X POST http://$API_SERVER/api/worlds/create \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$response" | grep -q '"success":true'; then
        echo "[容器$i] ✓ 数据库同步成功，UUID: $uuid, 状态: $status"
        return 0
    else
        echo "[容器$i] ✗ 数据库同步失败，响应: $response"
        return 1
    fi
}

# 处理单个容器（检查+启动）
process_container() {
    local i=$1
    
    # 先检查现有容器
    if check_existing_container $i; then
        return 0
    fi
    
    # 需要启动容器
    if start_single_container $i; then
        # 安装socat并配置转发
        install_socat_and_forward $i
        return 0
    fi
    
    return 1
}

# 显示使用说明
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "使用方法: $0 [BASE_PORT] [容器数量] [API服务器地址]"
    echo "参数说明:"
    echo "  BASE_PORT: 基础控制端口 (默认: 5000)"
    echo "             容器命名: android_world_{端口号}"
    echo "             ADB端口将自动计算为: BASE_PORT + i + 1556"
    echo "             例如: BASE_PORT=5000, 第0个容器控制端口=5000, ADB端口=6556, 容器名=android_world_5000"
    echo "  容器数量: 要创建的容器数量 (默认: 2)"
    echo "  API服务器地址: API服务器的地址和端口 (默认: 10.50.38.3:25718)"
    echo ""
    echo "示例:"
    echo "  $0                                # 使用默认配置: BASE_PORT=5000, 容器数=2"
    echo "  $0 5000 5                         # BASE_PORT=5000, 创建5个容器 (android_world_5000 到 android_world_5004)"
    echo "  $0 6000 10                        # BASE_PORT=6000, 创建10个容器 (android_world_6000 到 android_world_6009)"
    echo "  $0 5000 3 192.168.1.100:3000     # BASE_PORT=5000, 3个容器, 指定API服务器"
    echo ""
    echo "端口分配示例 (BASE_PORT=5000, 容器数=3):"
    echo "  容器0: 名称=android_world_5000, 控制端口=5000, ADB端口=6556"
    echo "  容器1: 名称=android_world_5001, 控制端口=5001, ADB端口=6557"
    echo "  容器2: 名称=android_world_5002, 控制端口=5002, ADB端口=6558"
    exit 0
fi

# 参数验证
if ! [[ "$BASE_PORT" =~ ^[0-9]+$ ]] || [ "$BASE_PORT" -lt 1024 ] || [ "$BASE_PORT" -gt 65535 ]; then
    echo "❌ 错误: BASE_PORT必须是1024-65535之间的数字"
    echo "使用 $0 --help 查看使用说明"
    exit 1
fi
if ! [[ "$NUM_CONTAINERS" =~ ^[0-9]+$ ]] || [ "$NUM_CONTAINERS" -lt 1 ]; then
    echo "❌ 错误: 容器数量必须是大于0的正整数"
    echo "使用 $0 --help 查看使用说明"
    exit 1
fi

# 导出函数供 parallel 使用
export -f start_single_container check_existing_container process_container install_socat_and_forward sync_to_database
export IMAGE BASE_PORT PORT_OFFSET MAX_RETRIES CHECK_INTERVAL SUCCESS_TIMEOUT API_SERVER

echo "开始并行处理 $NUM_CONTAINERS 个容器..."
echo "配置: BASE_PORT=${BASE_PORT}, 端口间隔=${PORT_OFFSET}, 检查间隔=${CHECK_INTERVAL}s, 成功超时=${SUCCESS_TIMEOUT}s, 最大重试=${MAX_RETRIES}次, 并行数量=${PARALLEL_JOBS}"
echo "API服务器: $API_SERVER"
echo ""
echo "端口分配:"
for ((i=0; i<NUM_CONTAINERS && i<5; i++)); do
    echo "  容器$i: 控制端口=$((BASE_PORT + i)), ADB端口=$((BASE_PORT + i + PORT_OFFSET))"
done
if [ $NUM_CONTAINERS -gt 5 ]; then
    echo "  ..."
fi
echo ""

# 使用 parallel 并行执行
seq 0 $((NUM_CONTAINERS-1)) | parallel --line-buffer -j $PARALLEL_JOBS process_container {}

echo "所有容器处理任务完成"

# 显示最终状态统计
echo ""
echo "=== 最终状态统计 ==="
running_count=$(sudo docker ps --filter "name=android_world_" --format "table {{.Names}}" | grep -c "android_world_" || echo "0")
total_count=$(sudo docker ps -a --filter "name=android_world_" --format "table {{.Names}}" | grep -c "android_world_" || echo "0")

echo "运行中的容器: $running_count/$NUM_CONTAINERS"
echo "总创建容器: $total_count"

# 显示异常容器
echo ""
echo "=== 异常容器状态 ==="
sudo docker ps -a --filter "name=android_world_" --format "table {{.Names}}\t{{.Status}}" | grep -v "Up " | head -10