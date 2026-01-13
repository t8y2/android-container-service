package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// CreateContainerRequest 创建容器请求
type CreateContainerRequest struct {
	BasePort      int    `json:"base_port" binding:"required,min=1024,max=65535"`
	NumContainers int    `json:"num_containers" binding:"required,min=1,max=100"`
	APIServer     string `json:"api_server"`
}

// DeleteContainerRequest 删除容器请求
type DeleteContainerRequest struct {
	Mode  string   `json:"mode" binding:"required,oneof=uuid port"`
	UUIDs []string `json:"uuids"`
	Ports []int    `json:"ports"`
}

// ContainerStatusResponse 容器状态响应
type ContainerStatusResponse struct {
	TotalContainers   int             `json:"total_containers"`
	RunningContainers int             `json:"running_containers"`
	Containers        []ContainerInfo `json:"containers"`
}

// ContainerInfo 容器信息
type ContainerInfo struct {
	Name      string `json:"name"`
	Status    string `json:"status"`
	Ports     string `json:"ports"`
	CreatedAt string `json:"created_at"`
}

// TaskManager 任务管理器
type TaskManager struct {
	tasks map[string]*TaskInfo
	mu    sync.RWMutex
}

// TaskInfo 任务信息
type TaskInfo struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"`
	Status    string    `json:"status"` // running, completed, failed
	Output    []string  `json:"output"`
	Error     string    `json:"error,omitempty"`
	StartTime time.Time `json:"start_time"`
	EndTime   time.Time `json:"end_time,omitempty"`
	mu        sync.Mutex
}

var taskManager = &TaskManager{
	tasks: make(map[string]*TaskInfo),
}

// CreateContainers 创建容器
func CreateContainers(c *gin.Context) {
	var req CreateContainerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("[ERROR] CreateContainers - 参数绑定失败: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   fmt.Sprintf("参数错误: %v", err),
		})
		return
	}

	log.Printf("[INFO] CreateContainers - 收到创建容器请求: BasePort=%d, NumContainers=%d, APIServer=%s",
		req.BasePort, req.NumContainers, req.APIServer)

	// 设置默认API服务器
	if req.APIServer == "" {
		req.APIServer = "10.50.38.3:25718"
		log.Printf("[INFO] CreateContainers - 使用默认API服务器: %s", req.APIServer)
	}

	// 生成任务ID
	taskID := fmt.Sprintf("create_%d", time.Now().Unix())
	log.Printf("[INFO] CreateContainers - 生成任务ID: %s", taskID)

	// 创建任务
	task := &TaskInfo{
		ID:        taskID,
		Type:      "create",
		Status:    "running",
		Output:    make([]string, 0),
		StartTime: time.Now(),
	}
	taskManager.mu.Lock()
	taskManager.tasks[taskID] = task
	taskManager.mu.Unlock()
	log.Printf("[INFO] CreateContainers - 任务已创建并加入任务管理器")

	// 异步执行脚本
	go func() {
		log.Printf("[INFO] Task[%s] - 开始执行异步任务", taskID)
		scriptPath := "./scripts/batch-create.sh"
		log.Printf("[INFO] Task[%s] - 脚本路径: %s", taskID, scriptPath)

		// 构建命令参数
		args := []string{
			fmt.Sprintf("%d", req.BasePort),
			fmt.Sprintf("%d", req.NumContainers),
			req.APIServer,
		}
		log.Printf("[INFO] Task[%s] - 命令参数: %v", taskID, args)

		// 执行脚本
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
		defer cancel()

		cmd := exec.CommandContext(ctx, "/bin/bash", append([]string{scriptPath}, args...)...)
		log.Printf("[INFO] Task[%s] - 执行命令: /bin/bash %s %v", taskID, scriptPath, args)

		// 创建管道获取输出
		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()

		if err := cmd.Start(); err != nil {
			log.Printf("[ERROR] Task[%s] - 启动脚本失败: %v", taskID, err)
			task.mu.Lock()
			task.Status = "failed"
			task.Error = fmt.Sprintf("启动脚本失败: %v", err)
			task.EndTime = time.Now()
			task.mu.Unlock()
			return
		}
		log.Printf("[INFO] Task[%s] - 脚本已启动，PID: %d", taskID, cmd.Process.Pid)

		// 读取输出
		go func() {
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				line := scanner.Text()
				log.Printf("[STDOUT] Task[%s]: %s", taskID, line)
				task.mu.Lock()
				task.Output = append(task.Output, line)
				task.mu.Unlock()
			}
		}()

		go func() {
			scanner := bufio.NewScanner(stderr)
			for scanner.Scan() {
				line := scanner.Text()
				log.Printf("[STDERR] Task[%s]: %s", taskID, line)
				task.mu.Lock()
				task.Output = append(task.Output, "[ERROR] "+line)
				task.mu.Unlock()
			}
		}()

		// 等待完成
		err := cmd.Wait()
		task.mu.Lock()
		if err != nil {
			log.Printf("[ERROR] Task[%s] - 脚本执行失败: %v", taskID, err)
			task.Status = "failed"
			task.Error = fmt.Sprintf("脚本执行失败: %v", err)
		} else {
			log.Printf("[INFO] Task[%s] - 脚本执行成功", taskID)
			task.Status = "completed"
		}
		task.EndTime = time.Now()
		duration := task.EndTime.Sub(task.StartTime)
		log.Printf("[INFO] Task[%s] - 任务完成，状态: %s, 耗时: %v", taskID, task.Status, duration)
		task.mu.Unlock()
	}()

	log.Printf("[INFO] CreateContainers - 返回响应，任务ID: %s", taskID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "容器创建任务已启动",
		"task_id": taskID,
		"data": gin.H{
			"base_port":      req.BasePort,
			"num_containers": req.NumContainers,
			"api_server":     req.APIServer,
		},
	})
}

// DeleteContainers 删除容器
func DeleteContainers(c *gin.Context) {
	// 记录请求的详细信息
	log.Printf("[INFO] DeleteContainers - 收到请求: Method=%s, Path=%s, ContentType=%s",
		c.Request.Method, c.Request.URL.Path, c.GetHeader("Content-Type"))

	var req DeleteContainerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("[ERROR] DeleteContainers - 参数绑定失败: %v", err)
		log.Printf("[ERROR] DeleteContainers - 请求体解析失败，原始请求: %s", c.Request.Body)
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   fmt.Sprintf("参数错误: %v", err),
			"details": "请确保发送正确的JSON格式，包含mode和uuids字段",
			"expected_format": map[string]interface{}{
				"mode":  "uuid",
				"uuids": []string{"uuid1", "uuid2"},
			},
		})
		return
	}

	log.Printf("[INFO] DeleteContainers - 收到删除容器请求: Mode=%s, UUIDs=%v, Ports=%v", req.Mode, req.UUIDs, req.Ports)

	// 验证参数
	if req.Mode == "uuid" {
		if len(req.UUIDs) == 0 {
			log.Printf("[ERROR] DeleteContainers - uuid模式缺少uuids数组")
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"error":   "uuid模式需要提供uuids数组",
			})
			return
		}
		log.Printf("[INFO] DeleteContainers - uuid模式: %d个UUID", len(req.UUIDs))
	} else if req.Mode == "port" {
		if len(req.Ports) == 0 {
			log.Printf("[ERROR] DeleteContainers - port模式缺少ports数组")
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"error":   "port模式需要提供ports数组",
			})
			return
		}
		log.Printf("[INFO] DeleteContainers - port模式: %d个端口", len(req.Ports))
	}

	// 生成任务ID
	taskID := fmt.Sprintf("delete_%d", time.Now().Unix())

	// 创建任务
	task := &TaskInfo{
		ID:        taskID,
		Type:      "delete",
		Status:    "running",
		Output:    make([]string, 0),
		StartTime: time.Now(),
	}
	taskManager.mu.Lock()
	taskManager.tasks[taskID] = task
	taskManager.mu.Unlock()

	// 异步执行脚本
	go func() {
		log.Printf("[INFO] Task[%s] - 开始执行删除任务", taskID)
		scriptPath := "./scripts/batch-delete.sh"

		var args []string
		if req.Mode == "uuid" {
			// UUID模式：直接传递UUID参数
			args = req.UUIDs
			log.Printf("[INFO] Task[%s] - UUID模式，参数: %v", taskID, args)
		} else if req.Mode == "port" {
			// Port模式：传递 --port 参数
			for _, port := range req.Ports {
				args = append(args, "--port", fmt.Sprintf("%d", port))
			}
			log.Printf("[INFO] Task[%s] - Port模式，参数: %v", taskID, args)
		}

		// 执行脚本
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()

		cmd := exec.CommandContext(ctx, "/bin/bash", append([]string{scriptPath}, args...)...)
		log.Printf("[INFO] Task[%s] - 执行命令: /bin/bash %s %v", taskID, scriptPath, args)

		// 创建管道获取输出
		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()

		if err := cmd.Start(); err != nil {
			log.Printf("[ERROR] Task[%s] - 启动脚本失败: %v", taskID, err)
			task.mu.Lock()
			task.Status = "failed"
			task.Error = fmt.Sprintf("启动脚本失败: %v", err)
			task.EndTime = time.Now()
			task.mu.Unlock()
			return
		}
		log.Printf("[INFO] Task[%s] - 脚本已启动，PID: %d", taskID, cmd.Process.Pid)

		// 读取输出
		go func() {
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				line := scanner.Text()
				log.Printf("[STDOUT] Task[%s]: %s", taskID, line)
				task.mu.Lock()
				task.Output = append(task.Output, line)
				task.mu.Unlock()
			}
		}()

		go func() {
			scanner := bufio.NewScanner(stderr)
			for scanner.Scan() {
				line := scanner.Text()
				log.Printf("[STDERR] Task[%s]: %s", taskID, line)
				task.mu.Lock()
				task.Output = append(task.Output, "[ERROR] "+line)
				task.mu.Unlock()
			}
		}()

		// 等待完成
		err := cmd.Wait()
		task.mu.Lock()
		if err != nil {
			log.Printf("[ERROR] Task[%s] - 脚本执行失败: %v", taskID, err)
			task.Status = "failed"
			task.Error = fmt.Sprintf("脚本执行失败: %v", err)
		} else {
			log.Printf("[INFO] Task[%s] - 脚本执行成功", taskID)
			task.Status = "completed"
		}
		task.EndTime = time.Now()
		duration := task.EndTime.Sub(task.StartTime)
		log.Printf("[INFO] Task[%s] - 任务完成，状态: %s, 耗时: %v", taskID, task.Status, duration)
		task.mu.Unlock()
	}()

	log.Printf("[INFO] DeleteContainers - 返回响应，任务ID: %s", taskID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "容器删除任务已启动",
		"task_id": taskID,
		"data": gin.H{
			"mode":  req.Mode,
			"uuids": req.UUIDs,
		},
	})
}

// GetContainerStatus 获取容器状态
func GetContainerStatus(c *gin.Context) {
	log.Printf("[INFO] GetContainerStatus - 收到获取容器状态请求")
	// 执行docker ps命令
	cmd := exec.Command("sudo", "docker", "ps", "-a", "--filter", "name=android_world_",
		"--format", "{{.Names}}|||{{.Status}}|||{{.Ports}}|||{{.CreatedAt}}")

	var out bytes.Buffer
	cmd.Stdout = &out

	if err := cmd.Run(); err != nil {
		log.Printf("[ERROR] GetContainerStatus - 执行docker ps失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   fmt.Sprintf("获取容器状态失败: %v", err),
		})
		return
	}

	// 解析输出
	containers := make([]ContainerInfo, 0)
	runningCount := 0

	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}

		parts := strings.Split(line, "|||")
		if len(parts) < 4 {
			continue
		}

		container := ContainerInfo{
			Name:      parts[0],
			Status:    parts[1],
			Ports:     parts[2],
			CreatedAt: parts[3],
		}

		if strings.Contains(container.Status, "Up") {
			runningCount++
		}

		containers = append(containers, container)
	}

	log.Printf("[INFO] GetContainerStatus - 查询到%d个容器，其中%d个运行中", len(containers), runningCount)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": ContainerStatusResponse{
			TotalContainers:   len(containers),
			RunningContainers: runningCount,
			Containers:        containers,
		},
	})
}

// GetTaskStatus 获取任务状态
func GetTaskStatus(c *gin.Context) {
	taskID := c.Param("id")
	log.Printf("[INFO] GetTaskStatus - 查询任务状态: %s", taskID)

	taskManager.mu.RLock()
	task, exists := taskManager.tasks[taskID]
	taskManager.mu.RUnlock()

	if !exists {
		log.Printf("[WARN] GetTaskStatus - 任务不存在: %s", taskID)
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   "任务不存在",
		})
		return
	}

	task.mu.Lock()
	defer task.mu.Unlock()

	log.Printf("[INFO] GetTaskStatus - 任务[%s]状态: %s, 输出行数: %d", taskID, task.Status, len(task.Output))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    task,
	})
}
