# Starlit Chronicle — HD-2D Studio V9（Main2）

唯一开发分支：`Main2美术优化版`。不修改 `main`，不建新分支，不强推。

## 目标与验收边界

V9 不只是功能菜单：把 V8 的视觉身份优化扩展到完整的 9 类正式资产 ID，并新增独立的 NPC、区域道具、世界地图场景远景、V4 室内材质、地区 UI 算法。程序化模式能全量产出 **451 项**核心 Godot 运行图像、16 个地表/水面补充图集、47 个角色/NPC 法线图，合计 **514 张 PNG**。按 Main2 当前已核实目录：42 地图、153 室内、12 角色、35 NPC、63 怪物、66 Boss、8 地区。未来注册表变化会动态读取，不按固定 451 个硬编码。

程序化素材是**可实际加载、可回滚的候选**，不是商业级精修原画。高清模型模式通过 Main2 `tools/global_art_ai_provider_v3.py` 生成全部正式身份 ID 的绘制任务，调用实际有权限的图像模型进行高精度生成（需要正确 `OPENAI_API_KEY`、模型支持、成本与网络）；图像要有真实审核记录才可进入精修档一键替换。不伪造质量签收。

原有引擎 `scripts/global_generated_art_v3.gd` 完全兼容：保持 `assets/art/runtime/global_factory_v3/{group}/{id}.png` 路径及 `active.json`、`data/assets/c_art_runtime_registry_v1.json` 语义索引；不删除外部美术旧档，不修改场景坐标、碰撞、剧情、任务、存档或奖励逻辑。

## 安装及运行

把三个 `tools/hd2d_studio_v*.py` 与测试放入 Main2 工程的 `tools/` 目录。需 Python 3.10+，安装 `Pillow numpy`。

```bash
python -m pip install Pillow numpy
# 读取当前 Main2 注册表全部类别与计数
python tools/hd2d_studio_v9.py --project .
# 构建全量候选包，不动运行图
python tools/hd2d_studio_v9.py --project . --generate
# 图像、完整性、真实 ID、法线图全部复核
python tools/hd2d_studio_v9.py --project . --verify
# 一键生成/校验/切换 Godot 正式运行资源路径（程序化候选，视觉仍未测试）
python tools/hd2d_studio_v9.py --project . --one-click
# 撤销：把上次回显的目录与索引备份路径复制到下面
python tools/hd2d_studio_v9.py --project . --rollback "<backup_dir>" --registry-backup "<registry_backup>"
```

替换过程先构建到独立 staging 文件夹，验证全部哈希和尺寸后重命名替换；异常时恢复旧包及旧注册表。备份在 `.gitignore` 排除的 `build/starlit_v9_backups`，不会把旧素材再次提交到在线库；恢复时可指定该完整备份路径。`--one-click` 默认复用经过内容指纹校验的未变更候选包，避免重复跑图。

## 高清精修生产模式

```bash
# 仅导出 451 项精修任务，API 调用=0
python tools/hd2d_studio_v9.py --project . --model-jobs
# 真正调用图像 API；需要安装 openai、填入 OPENAI_API_KEY、有足额费用与可用模型
python tools/hd2d_studio_v9.py --project . --render-model --model <当前账户支持的图像模型> --model-quality xhigh
# 按正式 ID 放置审核合格的高精度 PNG，附同名 .quality.json，签收字段：
# {"image_sha256":"...", "visual_approved":true, "identity_approved":true}
# 必须全部 451 张检查通过，缺一张或身份不符即拒绝全量精修发布
python tools/hd2d_studio_v9.py --project . --one-click --tier refined --model-source build/starlit_hd2d_studio_v9/refined_models
```

模型生成只是候选，不自动写入 `visual_approved: true`。无法以程序算法保证人物同一身份 12 帧的艺术一致性、Boss 分镜或整场景原画精美度；必须经过图像与真实 Godot 审核。正式模型可选择使用 V9 程序化轮廓作为 reference_root；模型供应商需要支持相应图像编辑与画布规格。

## Main2 一键 GitHub Actions

`.github/workflows/main2-hd2d-studio-v9.yml`：push V9 工具变更时只做离线完整性测试，不改线上素材。手动 `workflow_dispatch` 才真正运行 `--one-click`，后续对照官方 288 物品/技能图标、66 Boss 动作图、8 套海浪动画的现有独立运行系统、同步注册表、通过 Godot 4.7.2 headless 导入后再无强推地提交 `Main2`。任何检查失败不提交，CI 日志保留。此工作流默认替换的是**可玩候选美术**，正式精修仍由单独审核模式完成。

## 质量与真实性状态

- 机器回归：角色方向及帧数、怪物动作帧、PNG 解码、尺寸、透明度、单格边缘、SHA256、完整 ID 集、重复 ID、回滚、篡改拦截、审核门禁。
- 辨识度：沿用 V8 以真实 RGBA 透明轮廓和色彩比较多种形态候选，挑选最不相似的怪物及 Boss，而不是依靠名称不同加分。仍可能出现相似角色，需人工视觉修图。
- 本地全量测试数据使用与 Main2 相同的数量、结构，**测试地图与房间名称是合成的，并非实际 Main2 的游戏画面截图**。Github CI 在真正 Main2 项目上再按当前 JSON 自动枚举。
- 正式的 288 图标、66 Boss 复合动作图和 8 海浪动画由 Main2 原有各自生产脚本维护，本工具不宣称自己已经重新绘制或替换了这些额外系统的全部美术。