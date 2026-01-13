package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	// 设置日志输出到标准输出和标准错误
	// systemd会自动捕获并写入日志文件
	log.SetOutput(os.Stdout)
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// 配置GIN的日志也输出到标准输出
	gin.DefaultWriter = os.Stdout
	gin.DefaultErrorWriter = os.Stderr

	// 设置GIN模式（生产环境使用release模式）
	mode := os.Getenv("GIN_MODE")
	if mode == "" {
		gin.SetMode(gin.DebugMode) // 开发时用debug模式看更多信息
	}

	log.Println("========================================")
	log.Println("Android Container Service 正在启动...")
	log.Println("========================================")

	// 创建Gin引擎（不使用默认中间件）
	r := gin.New()

	// 添加自定义日志中间件
	r.Use(LoggerMiddleware())

	// 添加Recovery中间件
	r.Use(gin.Recovery())

	// 设置CORS中间件
	r.Use(CORSMiddleware())

	// API路由组
	api := r.Group("/api/container")
	{
		// 创建容器
		api.POST("/create", CreateContainers)

		// 删除容器 - 同时支持POST和DELETE方法以确保兼容性
		api.DELETE("/delete", DeleteContainers)
		api.POST("/delete", DeleteContainers) // 兼容旧版本调用

		// 查询容器状态
		api.GET("/status", GetContainerStatus)

		// 查询任务状态
		api.GET("/task/:id", GetTaskStatus)

		// 健康检查
		api.GET("/health", HealthCheck)
	}

	// 添加catch-all路由来处理404情况
	r.NoRoute(func(c *gin.Context) {
		log.Printf("[WARN] 404 - 未找到路由: %s %s from %s", c.Request.Method, c.Request.URL.Path, c.ClientIP())
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   "API路径不存在",
			"path":    c.Request.URL.Path,
			"method":  c.Request.Method,
			"available_endpoints": []string{
				"POST /api/container/create",
				"DELETE /api/container/delete",
				"POST /api/container/delete (兼容模式)",
				"GET /api/container/status",
				"GET /api/container/task/:id",
				"GET /api/container/health",
			},
		})
	})

	// 打印所有注册的路由
	log.Println("注册的API路由:")
	for _, route := range r.Routes() {
		log.Printf("  %s %s", route.Method, route.Path)
	}

	// 获取端口
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// 明确监听所有网络接口（0.0.0.0）以支持公网访问
	addr := "0.0.0.0:" + port
	log.Printf("Android Container Service 启动在地址: %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("服务启动失败: %v", err)
	}
}

// LoggerMiddleware 自定义日志中间件
func LoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 请求开始时间
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method
		clientIP := c.ClientIP()

		log.Printf("[REQUEST] %s %s from %s, ContentType: %s, UserAgent: %s",
			method, path, clientIP, c.GetHeader("Content-Type"), c.GetHeader("User-Agent"))

		// 处理请求
		c.Next()

		// 请求结束
		latency := time.Since(start)
		statusCode := c.Writer.Status()

		if statusCode >= 400 {
			log.Printf("[RESPONSE] %s %s - Status: %d, Latency: %v [ERROR]",
				method, path, statusCode, latency)
		} else {
			log.Printf("[RESPONSE] %s %s - Status: %d, Latency: %v",
				method, path, statusCode, latency)
		}
	}
}

// CORSMiddleware CORS中间件
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// HealthCheck 健康检查
func HealthCheck(c *gin.Context) {
	c.JSON(200, gin.H{
		"status":  "ok",
		"service": "Android Container Service",
		"message": "Service is running and ready to manage Android containers",
	})
}
