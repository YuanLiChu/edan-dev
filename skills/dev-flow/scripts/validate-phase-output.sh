#!/bin/bash
set -e

WORKFLOW_ID=$1
PHASE_NUMBER=$2
WORKFLOW_DIR=".dev-flow/${WORKFLOW_ID}"

echo "=== 验证 Phase ${PHASE_NUMBER} 输出完整性 ==="

# 检查 1：JSON 输出文件是否存在
PHASE_OUTPUT=$(find "${WORKFLOW_DIR}/outputs" -name "phase-${PHASE_NUMBER}-*.json" 2>/dev/null | head -1)
if [ -z "$PHASE_OUTPUT" ]; then
    echo "❌ ERROR: Phase ${PHASE_NUMBER} 缺少 JSON 输出文件"
    echo "   期望文件: ${WORKFLOW_DIR}/outputs/phase-${PHASE_NUMBER}-*.json"
    echo ""
    echo "   可能原因："
    echo "   1. 主 Agent 遗漏了 Write 操作"
    echo "   2. 输出文件路径错误"
    echo "   3. Phase 未正确执行"
    exit 1
fi
echo "✓ JSON 输出文件: ${PHASE_OUTPUT}"

# 检查 2：state 文件格式是否正确
STATE_FILE="${WORKFLOW_DIR}/.state.json"
if [ ! -f "$STATE_FILE" ]; then
    echo "❌ ERROR: state 文件不存在"
    echo "   路径: ${STATE_FILE}"
    exit 1
fi

# 检查 3：phase_status 是否为数组格式（文档规范）
PHASE_STATUS_TYPE=$(jq -r ".phase_status | type" "$STATE_FILE" 2>/dev/null)
if [ "$PHASE_STATUS_TYPE" != "array" ]; then
    echo "❌ ERROR: phase_status 格式错误"
    echo "   当前类型: ${PHASE_STATUS_TYPE}"
    echo "   期望类型: array（数组）"
    echo ""
    echo "   文档规范（workflow-phases.md 第 859 行）："
    echo "   phase_status: ["
    echo "     { phase_number: 0, phase_name: '...', ... }"
    echo "   ]"
    exit 1
fi

# 检查 4：Phase 记录是否存在
PHASE_RECORD=$(jq ".phase_status[] | select(.phase_number == ${PHASE_NUMBER})" "$STATE_FILE" 2>/dev/null)
if [ -z "$PHASE_RECORD" ]; then
    echo "❌ ERROR: state 文件中找不到 Phase ${PHASE_NUMBER} 的记录"
    echo "   当前 phase_status:"
    jq ".phase_status[]" "$STATE_FILE"
    exit 1
fi

# 检查 5：必需字段是否完整
REQUIRED_FIELDS=("phase_number" "phase_name" "status" "start_time" "end_time" "output_files" "execution_notes")
for field in "${REQUIRED_FIELDS[@]}"; do
    FIELD_VALUE=$(jq -r ".phase_status[] | select(.phase_number == ${PHASE_NUMBER}) | .${field}" "$STATE_FILE" 2>/dev/null)
    if [ -z "$FIELD_VALUE" ] || [ "$FIELD_VALUE" == "null" ]; then
        echo "❌ ERROR: Phase ${PHASE_NUMBER} 缺少必需字段: ${field}"
        echo ""
        echo "   文档规范要求字段："
        for f in "${REQUIRED_FIELDS[@]}"; do
            echo "   - ${f}"
        done
        exit 1
    fi
done
echo "✓ 必需字段完整"

# 检查 6：output_files 字段是否为非空数组
OUTPUT_FILES_TYPE=$(jq -r ".phase_status[] | select(.phase_number == ${PHASE_NUMBER}) | .output_files | type" "$STATE_FILE")
if [ "$OUTPUT_FILES_TYPE" != "array" ]; then
    echo "❌ ERROR: output_files 字段类型错误"
    echo "   当前类型: ${OUTPUT_FILES_TYPE}"
    echo "   期望类型: array（数组）"
    exit 1
fi

OUTPUT_FILES_COUNT=$(jq ".phase_status[] | select(.phase_number == ${PHASE_NUMBER}) | .output_files | length" "$STATE_FILE")
if [ "$OUTPUT_FILES_COUNT" == "0" ]; then
    echo "❌ ERROR: output_files 数组为空"
    echo "   必须至少包含一个输出文件路径"
    exit 1
fi
echo "✓ output_files 数组包含 ${OUTPUT_FILES_COUNT} 个文件"

# 检查 7：output_files 中的文件是否存在
OUTPUT_FILES=$(jq -r ".phase_status[] | select(.phase_number == ${PHASE_NUMBER}) | .output_files[]" "$STATE_FILE")
for file in $OUTPUT_FILES; do
    if [ ! -f "$file" ]; then
        echo "❌ ERROR: output_files 中的文件不存在: ${file}"
        echo "   请检查主 Agent 是否正确执行了 Write 操作"
        exit 1
    fi
done
echo "✓ 所有输出文件均存在"

# 检查 8：JSON 输出文件内容完整性
PHASE_NUMBER_IN_FILE=$(jq -r ".phase_number" "$PHASE_OUTPUT")
if [ "$PHASE_NUMBER_IN_FILE" != "$PHASE_NUMBER" ]; then
    echo "❌ ERROR: JSON 输出文件的 phase_number 不匹配"
    echo "   文件中的值: ${PHASE_NUMBER_IN_FILE}"
    echo "   期望值: ${PHASE_NUMBER}"
    exit 1
fi

OUTPUT_FIELD=$(jq ".output" "$PHASE_OUTPUT")
if [ -z "$OUTPUT_FIELD" ] || [ "$OUTPUT_FIELD" == "null" ]; then
    echo "❌ ERROR: JSON 输出文件缺少 output 字段"
    exit 1
fi
echo "✓ JSON 输出内容完整"

# 检查 9：输出文件路径一致性
FILE_IN_STATE=$(jq -r ".phase_status[] | select(.phase_number == ${PHASE_NUMBER}) | .output_files[0]" "$STATE_FILE")
FILE_ACTUAL="${PHASE_OUTPUT}"
if [ "$FILE_IN_STATE" != "$FILE_ACTUAL" ]; then
    echo "⚠️  WARNING: state 文件中的 output_files 与实际文件路径不一致"
    echo "   state 中记录: ${FILE_IN_STATE}"
    echo "   实际文件路径: ${FILE_ACTUAL}"
fi

echo ""
echo "=== ✓ Phase ${PHASE_NUMBER} 验证通过 ==="
echo ""
echo "验证结果摘要："
echo "  ✓ JSON 输出文件已生成"
echo "  ✓ state 文件格式正确（数组）"
echo "  ✓ 必需字段完整（7个）"
echo "  ✓ output_files 非空数组（${OUTPUT_FILES_COUNT} 个文件）"
echo "  ✓ 所有输出文件存在"
echo "  ✓ JSON 输出内容完整"