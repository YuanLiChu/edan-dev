#!/bin/bash
# Rules 路径检测脚本（修复版 - 支持多种场景）

# 获取项目路径（支持参数传递）
PROJECT_DIR="${1:-$(pwd)}"

echo "TARGET_DIRECTORY=$PROJECT_DIR"
echo "CURRENT_DIRECTORY=$(pwd)"
echo "DETECTION_METHOD=dynamic_path"

# 优先级0：检查系统插件缓存（多种可能路径）
PLUGIN_CACHE_PATHS=(
    "$HOME/.claude/plugins/cache/edan-dev/edan-dev"
)

for PLUGIN_BASE_PATH in "${PLUGIN_CACHE_PATHS[@]}"; do
    if [ -d "$PLUGIN_BASE_PATH" ]; then
        # 动态获取最新版本号
        LATEST_VERSION=$(ls "$PLUGIN_BASE_PATH" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)

        if [ -n "$LATEST_VERSION" ]; then
            PLUGIN_RULES_PATH="$PLUGIN_BASE_PATH/$LATEST_VERSION/plugin-rules"

            if [ -d "$PLUGIN_RULES_PATH/common" ]; then
                echo "RULES_PATH=$PLUGIN_RULES_PATH/"
                echo "RULES_TYPE=PLUGIN_CACHE"
                echo "PLUGIN_VERSION=$LATEST_VERSION"
                echo "PLUGIN_BASE_PATH=$PLUGIN_BASE_PATH"
                exit 0
            fi
        fi
    fi
done

# 优先级1：项目目录 .claude/rules/
if [ -d "$PROJECT_DIR/.claude/rules/common" ]; then
    echo "RULES_PATH=$PROJECT_DIR/.claude/rules/"
    echo "RULES_TYPE=PROJECT_CLAUDE"
    exit 0
fi

# 优先级2：全局目录 ~/.claude/rules/
if [ -d "$HOME/.claude/rules/common" ]; then
    echo "RULES_PATH=$HOME/.claude/rules/"
    echo "RULES_TYPE=GLOBAL"
    exit 0
fi

# 未找到 rules
echo "RULES_PATH=NOT_FOUND"
echo "RULES_TYPE=NOT_FOUND"
echo "SUGGESTION=Consider creating .claude/rules/ directory in project or home directory"
exit 0