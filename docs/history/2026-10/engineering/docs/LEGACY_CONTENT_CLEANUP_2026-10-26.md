# 《星灯纪行》旧内容及回归覆盖清理报告 — 2026-10-26

以非截断的 `main 260bc9b5fdab2939868984745b6338cf627c7150` Git tree 为基线：**1,915**个跟踪文件，`scripts/` 105项、`tools/` 150项，其中**124**个名称包含smoke_/test_/validate_。SHA相同内容组**36**组、涉及**85**个路径、理论**49**份额外字节副本。**相同字节不代表可删除**，不同角色表情、怪物战斗图与图鉴图、兼容回退路径即使暂时内容一致，也可能被动态加载。尚未完成运行时资源覆盖验收，故均不删除。

## 本次确认可删除的历史文件（3）

1. `GITHUB_FIRST_PUSH.md`：v0.1.1时期“创建全新私有库”的初次发布说明。仓库现已建立并公开。
2. `PUBLISH_TO_GITHUB.ps1`：首次`git init`/`git add`/`git push`脚本，不是现行main-only开发与验收流程。
3. `assets/art/_spec/preview_batch_0_3.png`：早期静态预览；不在生产art_manifest，也不作为渲染工具、Godot入口或Actions资源输入。Git历史保留可恢复。

## 明确保留

- 正式入口`scenes/first_act.tscn`。旧`scenes/main.tscn`、`scripts/game.gd`、`scripts/world.gd`、`scripts/battle.gd`非当前默认运行入口，但移除前需先确认V1原型及手动测试迁移，暂留。
- `scripts/game_state.gd`依然由`project.godot`注册为`State`自动加载，不能断开旧存档兼容。
- `tools/smoke_legacy_ending.gd`及全部A/B/C/D回归：`.github/workflows/godot-full-smoke-suite.yml`会自动发现`tools/**/smoke_*.gd`，没有任何测试因“年份早/文件名旧”而被删除。
- 角色差异表情、怪物战斗/图鉴同字节资源，全部保留。

新增只读审计：`python3 tools/audit_legacy_cleanup.py --json`。该脚本列出重复内容及保护旧存档/正式入口约束，永不自动删除。

**验收状态：**静态资源路径与工作流核验；最新代码并未在Godot 4.7.2实机运行。本批不改变剧情、游戏存档、战斗数值、回归测试及CI入口。
