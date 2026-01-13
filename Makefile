.PHONY: help build run clean install dev

help: ## 显示帮助信息
	@echo "可用命令:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## 安装依赖
	go mod download
	go mod tidy

build: ## 编译程序
	go build -o android-container-service .
	@echo "✓ 编译完成: ./android-container-service"

run: ## 运行程序
	go run .

dev: ## 开发模式运行(自动重载需要air工具)
	@if command -v air > /dev/null; then \
		air; \
	else \
		echo "请先安装air: go install github.com/cosmtrek/air@latest"; \
		echo "或直接运行: make run"; \
	fi

clean: ## 清理编译文件
	rm -f android-container-service
	rm -f *.log
	@echo "✓ 清理完成"

test: ## 运行测试
	go test -v ./...

docker-build: ## 构建Docker镜像
	docker build -t android-container-service:latest .

docker-run: ## 运行Docker容器
	docker run -d \
		--name android-container-service \
		-p 8080:8080 \
		-v /var/run/docker.sock:/var/run/docker.sock \
		android-container-service:latest

logs: ## 查看日志
	tail -f android-container-service.log

setup: ## 初始化项目(安装依赖+复制脚本)
	@echo "初始化项目..."
	mkdir -p scripts
	@if [ -f ../参考/batch-create.sh ]; then \
		cp ../参考/batch-create.sh scripts/; \
		echo "✓ 复制 batch-create.sh"; \
	fi
	@if [ -f ../参考/batch-delete.sh ]; then \
		cp ../参考/batch-delete.sh scripts/; \
		echo "✓ 复制 batch-delete.sh"; \
	fi
	chmod +x scripts/*.sh
	go mod download
	@echo "✓ 项目初始化完成"

.DEFAULT_GOAL := help
