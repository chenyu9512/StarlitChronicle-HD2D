# 当前自动化测试入口｜2026-10-28

> 下表从 `Main2美术优化版` 实际 `.github/workflows/` 读取。**工作流文件存在不代表该工作流在最新提交已通过**。旧的12项清理报告只作为历史快照；实际配置现有17项。

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
