#!/bin/bash

# 为 Linux 服务器交叉编译

echo "================================"
echo "为 Linux 编译程序"
echo "================================"
echo ""

# 设置交叉编译环境变量
export GOOS=linux
export GOARCH=amd64

echo "编译目标: Linux AMD64"
echo "正在编译..."

# 编译
go build -o android-container-service .

if [ $? -eq 0 ]; then
    echo "✓ 编译成功"
    echo ""
    echo "生成的文件: android-container-service"
    ls -lh android-container-service
    echo ""
    echo "现在可以将此文件上传到服务器并运行 deploy.sh"
else
    echo "✗ 编译失败"
    exit 1
fi
