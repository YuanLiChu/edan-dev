#!/bin/bash
set -e

# 参数解析
WORKFLOW_ID=$1
PROJECT_DIR=${2:-.}  # 默认当前目录

# 使用说明
if [ -z "$WORKFLOW_ID" ]; then
    echo "使用方法: bash validate-state-format.sh <workflow_id> [project_dir]"
    echo ""
    echo "参数:"
    echo "  workflow_id  - 工作流ID（格式: YYYY-MM-DD-HH-MM-SS）"
    echo "  project_dir  - 项目根目录路径（可选，默认当前目录）"
    echo ""
    echo "示例:"
    echo "  bash scripts/validate-state-format.sh 2026-04-16-10-34-02"
    echo "  bash scripts/validate-state-format.sh 2026-04-16-10-34-02 /path/to/project"
    exit 1
fi

# 切换到项目目录（如果指定）
if [ "$PROJECT_DIR" != "." ]; then
    cd "$PROJECT_DIR" || {
        echo "❌ ERROR: 无法切换到项目目录: $PROJECT_DIR"
        exit 1
    }
fi

WORKFLOW_DIR=".dev-flow/${WORKFLOW_ID}"

echo "=== 验证 state 文件格式完整性 ==="
echo "项目目录: $(pwd)"
echo "工作流ID: ${WORKFLOW_ID}"
echo ""

# 检查 0：项目目录是否包含 .dev-flow 目录
if [ ! -d ".dev-flow" ]; then
    echo "❌ ERROR: 当前目录不是有效的项目根目录"
    echo "   缺少 .dev-flow 目录"
    echo ""
    echo "   请确保在包含 .dev-flow 的项目根目录下执行此脚本"
    echo "   或通过第二个参数指定项目目录路径"
    echo ""
    echo "   正确调用方式:"
    echo "   cd /path/to/your/project"
    echo "   bash /path/to/edan-dev/skills/dev-flow/scripts/validate-state-format.sh ${WORKFLOW_ID}"
    echo ""
    echo "   或者:"
    echo "   bash scripts/validate-state-format.sh ${WORKFLOW_ID} /path/to/your/project"
    exit 1
fi

# 检查 1：state 文件是否存在
STATE_FILE="${WORKFLOW_DIR}/.state.json"
if [ ! -f "$STATE_FILE" ]; then
    echo "❌ ERROR: state 文件不存在"
    echo "   路径: ${STATE_FILE}"
    exit 1
fi
echo "✓ state 文件存在: ${STATE_FILE}"

# 检查 2：必需顶层字段
REQUIRED_TOP_FIELDS=("workflow_id" "status" "current_phase" "phase_status" "agent_calls" "created_at" "updated_at")
for field in "${REQUIRED_TOP_FIELDS[@]}"; do
    FIELD_VALUE=$(jq -r ".${field}" "$STATE_FILE" 2>/dev/null)
    if [ -z "$FIELD_VALUE" ] || [ "$FIELD_VALUE" == "null" ]; then
        echo "❌ ERROR: state 文件缺少必需顶层字段: ${field}"
        exit 1
    fi
done
echo "✓ 顶层必需字段完整"

# 检查 3：phase_status 必须为数组
PHASE_STATUS_TYPE=$(jq -r ".phase_status | type" "$STATE_FILE")
if [ "$PHASE_STATUS_TYPE" != "array" ]; then
    echo "❌ ERROR: phase_status 格式错误"
    echo "   当前类型: ${PHASE_STATUS_TYPE}"
    echo "   期望类型: array"
    echo ""
    echo "   正确格式示例："
    echo "   phase_status: ["
    echo "     { phase_number: 0, phase_name: '初始化', ... },"
    echo "     { phase_number: 1, phase_name: '需求分析', ... }"
    echo "   ]"
    echo ""
    echo "   错误格式示例（避免）："
    echo "   phase_status: {"
    echo "     phase_0: { ... },"
    echo "     phase_1: { ... }"
    echo "   }"
    exit 1
fi
echo "✓ phase_status 为数组格式"

# 检查 4：每个 phase_status 记录的必需字段
REQUIRED_PHASE_FIELDS=("phase_number" "phase_name" "status" "output_files")
PHASE_COUNT=$(jq ".phase_status | length" "$STATE_FILE")
if [ "$PHASE_COUNT" == "0" ]; then
    echo "⚠️  WARNING: phase_status 数组为空"
else
    for i in $(seq 0 $((PHASE_COUNT - 1))); do
        for field in "${REQUIRED_PHASE_FIELDS[@]}"; do
            FIELD_VALUE=$(jq -r ".phase_status[${i}].${field}" "$STATE_FILE" 2>/dev/null)
            if [ -z "$FIELD_VALUE" ] || [ "$FIELD_VALUE" == "null" ]; then
                PHASE_NUM=$(jq -r ".phase_status[${i}].phase_number" "$STATE_FILE")
                echo "❌ ERROR: Phase ${PHASE_NUM} 缺少必需字段: ${field}"
                exit 1
            fi
        done
    done
    echo "✓ 所有 Phase 记录包含必需字段"
fi

# 检查 5：agent_calls 必需字段
REQUIRED_AGENT_FIELDS=("architect" "coder" "tester" "runner" "fixer")
for field in "${REQUIRED_AGENT_FIELDS[@]}"; do
    FIELD_VALUE=$(jq -r ".agent_calls.${field}" "$STATE_FILE" 2>/dev/null)
    if [ -z "$FIELD_VALUE" ] || [ "$FIELD_VALUE" == "null" ]; then
        echo "❌ ERROR: agent_calls 缺少必需字段: ${field}"
        exit 1
    fi
done
echo "✓ agent_calls 字段完整"

# 检查 6：workflow_id 一致性
WORKFLOW_ID_IN_FILE=$(jq -r ".workflow_id" "$STATE_FILE")
if [ "$WORKFLOW_ID_IN_FILE" != "$WORKFLOW_ID" ]; then
    echo "❌ ERROR: workflow_id 不匹配"
    echo "   文件中的值: ${WORKFLOW_ID_IN_FILE}"
    echo "   期望值: ${WORKFLOW_ID}"
    exit 1
fi
echo "✓ workflow_id 一致"

# 检查 7：status 必须为有效值
STATUS=$(jq -r ".status" "$STATE_FILE")
VALID_STATUSES=("initialized" "requirement_analyzed" "design_confirmed" "in_progress" "testing_in_progress" "testing_passed" "fix_loop" "completed")
STATUS_VALID=false
for valid_status in "${VALID_STATUSES[@]}"; do
    if [ "$STATUS" == "$valid_status" ]; then
        STATUS_VALID=true
        break
    fi
done

if [ "$STATUS_VALID" == "false" ]; then
    echo "❌ ERROR: status 值无效: ${STATUS}"
    echo "   有效值: ${VALID_STATUSES[*]}"
    exit 1
fi
echo "✓ status 值有效: ${STATUS}"

# 检查 8：current_phase 必须为数字（0-7）
CURRENT_PHASE=$(jq -r ".current_phase" "$STATE_FILE")
if ! [[ "$CURRENT_PHASE" =~ ^[0-7]$ ]]; then
    echo "❌ ERROR: current_phase 值无效: ${CURRENT_PHASE}"
    echo "   期望值: 0-7 的数字"
    exit 1
fi
echo "✓ current_phase 值有效: ${CURRENT_PHASE}"

echo ""
echo "=== ✓ state 文件格式验证通过 ==="
echo ""
echo "验证结果摘要："
echo "  ✓ 文件存在"
echo "  ✓ 顶层字段完整（7个）"
echo "  ✓ phase_status 为数组格式"
echo "  ✓ Phase 记录字段完整（${PHASE_COUNT} 个）"
echo "  ✓ agent_calls 字段完整（5个）"
echo "  ✓ workflow_id 一致"
echo "  ✓ status 值有效"
echo "  ✓ current_phase 值有效"