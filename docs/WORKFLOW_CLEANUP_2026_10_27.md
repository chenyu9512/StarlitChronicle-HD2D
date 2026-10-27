# 工作流清理及持续验收入口（2026-10-27）

**原执行范围**：main 分支下 .github/workflows/，仅整理自动化入口、政策与开发导航；保留正式游戏脚本、测试脚本、候选/正式美术与历史 Git 提交。

**2026-10-27 补充：** 用户将唯一开发目标切换到 `Main2美术优化版`；本文件所记删除历史仍属于原 `main` 时期。新工作流应在目标分支手动派发或由该分支专用QA批次标记触发，不能默认以 `main` 运行结果证明新分支通过。

## 核查前后

- 清理前：22 个 YAML 工作流。
- 本次废弃：10 个历史/重复/自动写库工作流。
- 清理后目标：12 个人工触发为主的有效工作流。
- 修改：Godot Core Validation 移除历史分支删除、关闭 PR 的第二 job；核心验证现在只验证代码，不再执行仓库管理。
- **测试状态**：这次执行了 GitHub 文件清单/工作流源码静态核查和 GitHub 提交；没有运行 Godot、GitHub Actions 或 Windows 实机测试，不能将其标记为 Godot 验证成功。

## 保留的 12 个工作流（当前使用指南）

| 工作流文件 | 执行用途 | 触发 |
| --- | --- | --- |
| content-validation.yml | 静态内容/发行契约快速检查 | 手动 |
| godot-core-validation.yml | 主控、剧情、存档、40图等大批综合验证 | 手动 / docs/qa-batch-trigger.json |
| godot-full-smoke-suite.yml | tools 下所有 smoke_*.gd 分片执行、输出完整日志 | 手动 / docs/qa-full-trigger.json |
| batch0-seven-qa-gates.yml | 七类独立质量门禁与证据 | 手动 / docs/qa-seven-trigger.json |
| b-world-batch-validation.yml | B线世界、NPC、建筑、第一幕路线/碰撞专项 | 手动 |
| m01-world-geometry-qa.yml | 当前D/B地图与房屋P0专项 | 手动 / docs/qa-m01-world-trigger.json |
| m01-services-qa.yml | D线M0.1服务结算、重复与回滚 | 手动 / docs/qa-m01-service-trigger.json |
| a-live-boss-batch.yml | A线66场Boss真实命令回归 | 手动 / docs/qa-a-boss-trigger.json |
| battle-animation-validation.yml | 战斗动画/音频与画面捕获 | 手动 |
| c23-b03-five-boss-acceptance.yml | C线首幕Boss美术与状态专项 | 手动 / docs/qa-c23-five-boss-trigger.json |
| coastal-visual-evidence.yml | 第一幕实际画面与序章截图证据 | 手动 |
| desktop-preview.yml | Windows/Linux开发预览导出 | 手动 |

**后续仅在 `Main2美术优化版` 的专用 docs/qa-*.json 改动时响应 push**；一般代码或文档提交不应触发大批测试。手动触发仍产生Actions用量，请在功能冻结、SHA明确时集中运行。

## 已废弃的 10 个工作流和替代路径

| 已删除文件 | 清理原因 | 需要验证时的替代 |
| --- | --- | --- |
| export-hd2d-art.yml | 旧 SVG→PNG批量渲染会将生成资产直接 push 回分支，可能与C线正式美术选择冲突 | 资源由C线受控导出；保留 tools/export_hd2d_svg.py 等独立脚本供人工审查 |
| render-coast-idles.yml | 老批次动画生成后自动 rebase/push 到main，与新美术分配冲突 | C线正式资源流水线；动画专项用 battle-animation-validation 与C23验收 |
| materialize-world-v3.yml | V3地图补齐后自动 rebase/push main；属于一次性历史生产而非测试 | tools/materialize_world_v3.py --verify 验证现有文件；不得自动改动任一仓库分支 |
| actions-failure-audit.yml | 一次性历史Actions失败巡检，日常不再需要独立入口 | 保留 tools/audit_actions_failures.py，由D线本地按需运行 |
| cinematic-validation.yml | 与 Godot Core 中剧情演出/序章回归重复 | godot-core-validation.yml 或完整smoke |
| map-ui-validation.yml | 与 Core / 全库smoke中的本地地图、房屋、迷雾禁用检查大量重复 | Godot Core / 全库smoke；补充静态 tools/validate_all_map_display.py |
| phase19-world-validation.yml | 与 Core 的 Phase19 剧情/室内执行矩阵重复 | Godot Core / 全库smoke |
| unique-map-layout-validation.yml | V3/40图/NPC/野外多数重叠B线及全库smoke | B World、全库smoke；静态 tools/validate_field_ecology_v7.py |
| render-budget-validation.yml | 与全库smoke、地图综合验证有重复；不必再独立安装Godot | 全库smoke；静态 tools/validate_render_budget_wiring.py |
| m01-world-gameplay-recovery.yml | 3条旧场景回归已纳入 Core 与全库smoke | Godot Core / 全库smoke |

**删除的是工作流入口，不是对应Godot测试、源码、资源或旧运行日志。** 全库执行器 tools/d_control/run_full_smoke_suite.py 会递归发现 tools/**/smoke_*.gd；非smoke命名的Python校验器仍需按上表独立运行。不要声称退役入口中的每条测试都已自动迁移成一个新的独立工作流步骤。

## 执行规程

1. 开发者日常修改只提交`Main2美术优化版`，检查受影响脚本；不要每提交一次就触发重型Actions。
2. 功能验收时冻结并记录HEAD SHA；先运行 content-validation 或本地静态脚本，再按风险运行 M0.1 / A / B / C 等专项。
3. 再运行 Godot Core 和 Full Smoke，记录每个 job 与测试日志；需要画面时使用 coastal-visual-evidence，打包前使用 desktop-preview。
4. 成功/失败/未测试必须标记清楚；历史绿色日志不能自动代表最新SHA。
5. 工作流不拥有更新游戏资产、直接push生产图集、自动删除历史分支和关闭PR的权限；素材更新由开发线按引用与来源审查后单独提交。
6. 不通过 GitHub Actions 自动删除候选素材、历史文档或完整的测试工具。将历史报告保留为证据，当前优先级以 docs/DEVELOPMENT_MASTER_PLAN.md 为准。

## 后续仍需改善

- 当P0稳定后，可考虑把 12 个入口进一步做成共享 composite action 或可复用 workflow，减少重复下载Godot的维护成本；本批未重构测试执行步骤，因此没有冒充已完成。
- 删掉重复CI不会修复已报告的地图路牌、出口、碰撞与剧情锚点P0；这些任务必须由B/C/D在正式源码中落地并通过游戏验收。
