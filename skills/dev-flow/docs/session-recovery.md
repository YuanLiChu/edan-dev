# 会话恢复机制

本文档详细说明工作流会话恢复机制。

---

## 恢复检测

在 Phase 0 步骤0执行，检测未完成工作流。

---

## 恢复执行

根据用户选择：

### 选项1：恢复工作流

```python
# 从 state["current_phase"] 继续
current_phase = state["current_phase"]

# 根据不同状态执行
if state["status"] == "pending_confirm" and current_phase == 2:
    # Phase 2 用户确认阶段
    phase_2_output = Read(state["phase_status"][2]["output_files"][0])
    AskUserQuestion(...)

elif state["status"] == "fix_loop" and current_phase == 5:
    # Phase 6 修复循环阶段
    iteration = state["fix_loop"]["current_iteration"]
    继续修复循环

elif state["status"] == "in_progress":
    # 其他阶段，重新执行当前 Phase
    执行 Phase {current_phase}
```

---

### 选项2：重新开始

```python
# 备份旧 state 文件
backup_file = f"{latest_workflow}/.state.backup.json"
Write(backup_file, state)

# 初始化新工作流
执行 Phase 0 步骤1-9（完整初始化流程）
```

---

### 选项3：查看详情

```python
# 输出工作流执行记录
print("工作流执行记录：")
for phase in state["phase_status"]:
    print(f"  Phase {phase['phase_number']}: {phase['phase_name']} - {phase['status']}")
    print(f"    开始时间：{phase['start_time']}")
    print(f"    结束时间：{phase['end_time']}")
    print(f"    耗时：{phase['duration_seconds']}秒")
    print(f"    输出文件：{phase['output_files']}")

# 再次询问用户
AskUserQuestion(...)
```

---

## 恢复流程图

```
skill 启动
├─ 检测未完成工作流
├─ 询问用户选择
│   ├─ 恢复工作流 → 从 current_phase 继续
│   ├─ 重新开始 → 备份旧工作流 + 初始化新工作流
│   └─ 查看详情 → 输出执行记录 + 再次询问
└─ 没有未完成工作流 → 初始化新工作流
```

---

## 恢复注意事项

1. **状态一致性**：
   - 确保 state 文件格式正确（数组格式）
   - 验证 phase_status 包含 output_files

2. **文件完整性**：
   - 检查所有 output_files 是否存在
   - 使用验证脚本检查

3. **用户确认**：
   - Phase 2 设计方案必须重新确认
   - 不能跳过用户确认环节

---

## 验证恢复状态

```bash
# 验证 state 文件格式
bash scripts/validate-state-format.sh {workflow_id}

# 验证 Phase 输出完整性
bash scripts/validate-phase-output.sh {workflow_id} {phase_number}
```