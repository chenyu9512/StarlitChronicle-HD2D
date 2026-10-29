# 《星灯纪行》美术管线 V3 · 已落地代码与验收口径

唯一开发分支：`Main2美术优化版`。禁止将本方案解释为已完成六章美术人工签收；禁止改动 `main`。

## 1. 唯一语义来源（已接入）
- `data/assets/art_theme_v2.json` 仍是**运行时主题语义 ID、类别与纹理路径**的权威文件；不建立第二份手工同步的主题表。
- `tools/audit_art_pipeline_v3.py --strict` 从主题、分配、第三方来源、六章地图和三间室内配置**派生**审计表 `build/art-theme-v3/audit.json`。构建目录内的 JSON 是生成物，不参与游戏资源加载。
- 原始/外部素材的分配状态只能代表策划意图，不能自动提升到“场景已呈现”。
- 黑帆酒馆 `data/levels/v4/interiors/map_coast_02__tavern.json` 每个家具的语义 ID 必须能在主题表查到；木地板图集与主题路径一致。
- `data/assets/c_act01_hd2d_v18.json` 是 V18 地图实际摆放证据；审计明确报告未在主题表注册的摆放贴图，防止“一键换肤全覆盖”的错误宣传。

## 2. 运行时规则（已修改）
- `scripts/c_art_theme_v2.gd` 激活主题前逐一加载 **89/89** 已声明槽位；不再仅用其中 14 个 required 槽位通过完整主题预检。
- 个人单张覆盖仍优先，主题不会改写存档、碰撞和真实地图结构；`user://` DLC 仍要求全 89 个正确画布。
- 存在身份不等价的别名，例如 palm_tree→mangrove、cave_crystal→sea_crystal，V3 将它们列入人工审核队列，而非自动批准同一视觉身份。替换前禁止把近似素材冒称正确素材。

## 3. 实机画面证据（代码已接入，实跑需同 SHA）
- 手动运行 `Main2 · Real Art Runtime Acceptance`（`.github/workflows/c-main2-art-runtime-acceptance.yml`）。
- Godot 实画截图：六章场景含 HUD/纯世界各 1 张（12），四处关键地标各 2 张（8），旧屋、收容所、黑帆酒馆各 2 张（6），总共 **26 张**。
- `tools/verify_act01_visual_evidence_v3.py` 检查 26 张 PNG 的存在、尺寸、文件头、哈希及关联提交 SHA，并生成 `visual-evidence-v3.json`。
- 上述仅确认截图来自已执行的 Godot 捕获链路及文件完整性；**不意味着玩家完整通关或商业画质通过**。人工评审必须对每张图逐项签收。

## 4. CI、Runtime 与容量（已接入）
- `tools/d_control/run_main2_ci.py` 已将 V2 语义预检、图集顺序验证、V3 资源审计及 V2 Godot 实机换肤冒烟并入去重的 art 测试组。
- `tools/verify_runtime_snapshot.py` 额外确保玩家可切换的 V2 主题所有纹理都在精简 Runtime 中，防止精简后场景缺图；源码包、候选素材、截图和报告依然排除在可玩发布外。
- 美术实机验收截图与统一 QA 日志改为 7 天保留，避免 GitHub Actions 长期积累。
- 只有同一 SHA 的测试成功与 26 张图逐张人工确认，才可以把第一幕美术标为商业画面验收通过。

## 5. 不应混淆的四种状态
1. `source_present`：文件真实存在且具备有效图像结构。
2. `allocated`：来源已指定设计角色、地区、地图，但不保证玩家能看到。
3. `explicit_scene_binding`：具体地图/室内数据引用已声明资源，不代表呈现细节一定正确。
4. `human_visual_accepted`：真实 Godot 截图按位置、方向、尺度、遮挡、风格逐张签收。

最终正式发布还需玩家完整游玩与存档恢复测试。此文档与 V3 工具均不提升未签收资源的真实状态。
