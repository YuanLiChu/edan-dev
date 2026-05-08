#!/bin/bash
# 工作流初始化脚本示例
# 用途：生成 workflow_id 并创建工作流目录结构

PROJECT_DIR=${1:-.}  # 默认当前目录

# 使用说明
echo "=== 工作流初始化 ==="
echo "项目目录: ${PROJECT_DIR}"
echo ""

# 切换到项目目录
if [ "$PROJECT_DIR" != "." ]; then
    cd "$PROJECT_DIR" || {
        echo "❌ ERROR: 无法切换到项目目录: $PROJECT_DIR"
        exit 1
    }
fi

# 检查是否为有效的项目目录
if [ ! -d ".dev-flow" ]; then
    echo "⚠️  INFO: .dev-flow 目录不存在，正在创建..."
fi

# 生成 workflow_id（时间戳格式：YYYY-MM-DD-HH-MM-SS）
workflow_id=$(date +"%Y-%m-%d-%H-%M-%S")
echo "生成的工作流 ID: $workflow_id"

# 创建工作流目录结构
# 结构：
# .dev-flow/
# ├── DevFlow.md (项目信息，跨工作流共享)
# └── {workflow_id}/
#     ├── .state.json (工作流状态)
#     └── outputs/
#         ├── phase-0-initialization.json
#         ├── phase-1-requirement-analysis.json
#         └── ...

mkdir -p .dev-flow/$workflow_id/outputs

# 验证目录创建
echo "已创建目录结构："
ls -la .dev-flow/$workflow_id/

# 示例：创建 .state.json 文件（需要主 Agent 使用 Write 工具）
# Write: .dev-flow/$workflow_id/.state.json
# Content: {
#   "workflow_id": "$workflow_id",
#   "status": "initialized",
#   "current_phase": 0,
#   "max_retries": 5,
#   "project_info": {...},
#   "rules_info": {...},
#   "phase_status": [],
#   "agent_calls": {
#     "architect": 0,
#     "coder": 0,
#     "tester": 0,
#     "runner": 0,
#     "fixer": 0
#   },
#   "created_at": "...",
#   "updated_at": "..."
# }

echo ""
echo "下一步：主 Agent 使用 Write 工具创建 .state.json 文件"