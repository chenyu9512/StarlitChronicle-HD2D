# 当前自动化测试入口｜2026-10-28

> 下表从 `Main2美术优化版` 实际 `.github/workflows/` 读取。**工作流文件存在不代表该工作流在最新提交已通过**。旧的12项清理报告只作为历史快照；下表是历史专项索引，并非当前目录中的全部工作流。

| 工作流文件 | 主要用途 |
|---|---|
| [`a-live-boss-batch.yml`](../.github/workflows/a-live-boss-batch.yml) | Boss与剧情战斗回归 |
| [`b-world-batch-validation.yml`](../.github/workflows/b-world-batch-validation.yml) | 地图、NPC和世界交互专项 |
| [`batch0-seven-qa-gates.yml`](../.github/workflows/batch0-seven-qa-gates.yml) | 专项质量门禁 |
| [`battle-animation-validation.yml`](../.github/workflows/battle-animation-validation.yml) | 实际视听/截图专项 |
| [`c-art-distribution-v12.yml`](../.github/workflows/c-art-distribution-v12.yml) | 运行时美术或区域素材验收 |
| [`c-main2-art-runtime-acceptance.yml`](../.github/workflows/c-main2-art-runtime-acceptance.yml) | 正式运行文件精简同步 |
| [`c-regional-art-v13.yml`](../.github/workflows/c-regional-art-v13.yml) | 运行时美术或区域素材验收 |
| [`c23-b03-five-boss-acceptance.yml`](../.github/workflows/c23-b03-five-boss-acceptance.yml) | Boss与剧情战斗回归 |
| [`coastal-visual-evidence.yml`](../.github/workflows/coastal-visual-evidence.yml) | 实际视听/截图专项 |
| [`content-validation.yml`](../.github/workflows/content-validation.yml) | 数据与静态内容验证 |
| [`desktop-preview.yml`](../.github/workflows/desktop-preview.yml) | 桌面预览构建 |
| [`godot-core-validation.yml`](../.github/workflows/godot-core-validation.yml) | 核心导入/系统验收 |
| [`godot-full-smoke-suite.yml`](../.github/workflows/godot-full-smoke-suite.yml) | 全量冒烟测试 |
| [`m01-services-qa.yml`](../.github/workflows/m01-services-qa.yml) | 区域服务与存档专项 |
| [`m01-world-geometry-qa.yml`](../.github/workflows/m01-world-geometry-qa.yml) | 地图、NPC和世界交互专项 |
| [`main2-map-regression.yml`](../.github/workflows/main2-map-regression.yml) | 最新地图及美术实机回归 |
| [`main2-to-runtime.yml`](../.github/workflows/main2-to-runtime.yml) | 正式运行文件精简同步 |

## 当前已知证据
- `dc112bd5bd76`：地图与六区域画面验证 [通过](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40524794128)，精简Runtime [通过](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40524794110)。
- 上述结果仅覆盖对应提交SHA与工作流所列断言。**不是**所有工作流或人工画质签收。
- `16687cf1c494` 是整理时当前分支SHA；如存在后续美术提交，必须对新的HEAD重新运行核心、全量测试并做画面检查。
- 不在整理历史记录期间改动QA触发JSON来制造新的昂贵测试；阶段功能冻结后按需测试。

## Main2统一门禁与真实证据（2026-10-29）

- **统一运行入口**：`.github/workflows/main2-ci.yml` → `tools/d_control/run_main2_ci.py`，对一个目标SHA进行一次Godot导入与按领域去重的smoke。近期提交频繁，`cancelled`不是通过，也不能以更旧HEAD的成功代表最新版本。
- **全局静态基础门禁**：`tools/validate_global_runtime_contract.py` 已纳入 `STATIC["base"]`，要求72正典章、120任务、66 Boss、42/40地图、68入口、153室内与54地区房全部互相匹配。
- **B线独立门禁**：`tools/validate_b_world_spatial_integrity.py` + `tools/smoke_b_home_runtime_geometry.gd`，后者检查全部153间V4和168个普通住宅调查点；Godot完整入口仍须实际运行才可标记成功。
- **Runtime正式发布**：`.github/workflows/main2-to-runtime.yml` 在打包前重新验证全局故事和空间合同；没有通过发布前美术、存档与Godot运行门禁，不可强制推送Runtime。
- **当前未解除的阻塞**：2026-10-29的`Main2 · Real Art Runtime Acceptance`曾出现主角图片、部分上传包素材与Boss阶段素材加载失败；其后一部分专门的地表渲染和素材生成工作流通过，**不等于整体验收通过**。
- **权威实时索引**：[全局架构同步与12方向阻塞](GLOBAL_SYNC_STATUS_2026_10_29.md)。每次验证均引用确切commit和run，且区分`成功`/`失败`/`未测试`。
