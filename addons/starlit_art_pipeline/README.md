# 星灯纪行｜Godot 美术生产、审核与一键替换 V2

> 唯一开发分支：**Main2美术优化版**。游戏内生效由现有 scripts/c_art_theme_v2.gd 全局纹理解析器负责。本插件不覆盖任何 assets/art/runtime 原图、地图、碰撞、任务、战斗和存档。

## 目标与可用能力

| 功能 | 入口 | 写入位置 | 约束 |
|---|---|---|---|
| 增量扫描与转换预览 | ① 增量转换 | res://build/starlit_art_pipeline/previews | SHA 缓存；只用 V5 CSV，不重复人工审核 |
| 集中审核 | 打开审核画廊 | review.html / review.csv / review.json | 原图、候选图、转换图对比；预览不是发布 |
| 发布前门禁 | ② 检查109项 | release_gate.json / release_gate.csv | 逐槽列出尺寸/身份/确认/缺失等具体原因 |
| 构建并实际替换 | ③ 一键构建 + 安装 + 切换 | res://build/.../complete_dlc 与 user://c_art_theme_v2/ | 必须 109/109；内容哈希命名，可复用已有相同版本 |
| 导入已有完整主题 | 导入其他已完成的109槽位DLC | user://c_art_theme_v2/ | 直接选择任意已构建的V2 art_theme.json；仍必须全部校验通过 |
| 切换多套已安装主题 | 已安装主题下拉框 | user://c_art_theme_v2.cfg | 运行时完整性校验，失败不切换 |
| 撤销与恢复原版 | 撤销 / 恢复原始美术 | user://starlit_art_pipeline_undo.cfg | 不删除素材、DLC、游戏存档 |
| 游戏实机确认 | 运行游戏检查替换效果 | 游戏主场景 | 确认实际地图/角色/UI变化，不把安装当作画质签收 |

## 三步使用

1. 在 Godot 4.7.2 打开 Main2 项目，确认「项目设置 → 插件 → Starlit Art Pipeline」已启用。素材目录默认保持 res://，V5 CSV 默认为 build/pixel_fantasy_conversion_v5/01_109项接入状态.csv。
2. 点击 **①** 生成集中预览；点击 **②** 检查完整109槽位的逐项报告。对未完成签收的槽位，保持原主题，不会将不匹配的图当作替换材料。
3. 只有门禁达到 **109/109** 后，点击 **③**。系统自动生成以资源 SHA256 标识的包、导入到 user://、验证并激活；再点击「运行游戏检查替换效果」。可在主题列表中再次切换，或一键恢复原始主题。

> 这是真正的游戏内纹理切换，不是覆盖原图的文件复制。当前 V5 报告中的不合格记录不会因为新按钮出现而自动变成合格。若游戏核心32px地图图集本身缺失，必须先修复原始资源才能完成完整替换；禁止用任意图片填空假装修复。

## 门禁明细与防误操作

单个槽位至少满足：approved=YES、final_visual_approved=YES、next_state=READY_FOR_DLC、语义身份正确、安全路径、图片存在且解码正确、图片大小不超过24MiB、尺寸与官方运行纹理精确相同。CSV 的 109 个槽位必须与当前 art_theme_v2.json 一一对应；任何多余、缺失或与官方基线版本不同的记录立即拒绝。

地形语义图集、人物动作格、怪物帧表、建筑脚点/碰撞、UI结构不能仅凭裁切预览判定可用。未经签收的素材只在预览环节出现，绝不能冒充真实已发布纹理。发布状态与商业签收是不同的：**预览 → 已导入 → 已激活 → Godot 同 SHA 实测 → 玩家/美术人工验收**。

与前版区别：
- 旧版仅生成 complete_dlc 文件而不安装；新版将构建、安装、激活贯通，并支持再次切换和撤销。
- 旧版只显示“109项不合格”的笼统信息；新版输出逐项 release_gate.csv 和理由分布。
- 每组签收资源形成内容寻址的独立 DLC；相同资源重复构建复用已安装版本，不覆盖另一版本，也不触碰原始素材。
- 运行时仍由 c_art_theme_v2.gd 执行全槽位校验、尺寸检查、启动预检与异常回退。

## 验证与故障诊断

在项目根目录运行：

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tools/check_starlit_art_pipeline.gd
```

验证项目能解析、插件加载、109槽位正确、路径穿越被拒绝、PNG预览可写、未签收的109槽位不能激活、只读审核不切换当前主题。

如“点击应用后画面没变化”，按以下顺序检查：1）所选主题是否已激活；2）关闭并重新运行游戏；3）场景实际绘制是否通过 c_art_theme_v2 解析器；4）游戏原始 atlas 是否存在；5）查看 Godot 运行日志中缺失路径。不要用“DLC已安装”替代实际画面截图。

**已编码不等于已测试。** 最终是否通过请以最新 commit 的 Godot 运行日志与人工实机截图为准。

## V3 全游戏美术资产工厂（已接入编辑器按钮）

Godot 右侧「星灯美术生产线」新增 **④ 批量生成全游戏美术候选资产 V3**。

命令行同样支持：

```powershell
py -m pip install Pillow
py tools/generate_art.py --project . --force
py tools/generate_art.py --project . --scope interiors
py tools/generate_art.py --project . --dry-run
```

- 动态读取 `data/content/maps.json`、`data/assets/av_registry.json` 以及所有 `data/levels/v4/interiors/*.json`。
- 默认生成地区图集、42地图装饰背景、99室内材质图集、区域道具、12角色、35 NPC、63怪物、66 Boss 和地区UI边框。输出随官方数据变化自动增减。
- 输出：`build/starlit_global_art_factory_v3/` 下分类 PNG、`candidate_manifest.json` 和 `candidate_index.json`。
- 支持 `--source-root <目录>` 按 `分类/角色ID.png` 等路径直接接收同规格精修原画；优先使用实际导入的美术而非程序草稿。
- 角色行走图规格为96×192（4方向×3帧），怪物/Boss候选帧表为512×128，地形/室内图集为256×256。
- 所有程序绘制图像均标记 **candidate**，不得作为已经验收的正式角色、Boss或地图美术；正式游戏纹理和碰撞完全不被这个生成阶段覆盖。
- 精修美术通过视觉、尺寸、语义和Godot真实场景签收之后，再走已有109槽位主题构建与安装流程；单纯生成或导入不等于完成正式接入。
- 自动CI：`.github/workflows/main2-global-art-factory-v3.yml`，执行5项单元回归及全地图/室内/角色/Boss候选生成检查。

旧的固定44×28地图和简单人物示例仍可通过 `py tools/generate_art.py --legacy` 单独运行。

## V3 高画质模型绘制接口

支持将正式角色、地区、地图、室内、Boss身份及视觉规范转为全游戏批量图像任务：

```powershell
py tools/global_art_ai_provider_v3.py --project . --jobs-only
```

这会为全部登记项目输出 `build/starlit_global_art_factory_v3/model_sources/render_jobs.jsonl`，不触发收费API。

需要执行实际高画质图像生成时，安装 `openai` Python包并在本地环境配置 `OPENAI_API_KEY`，然后运行：

```powershell
py -m pip install openai Pillow
py tools/global_art_ai_provider_v3.py --project . --render --model gpt-image-2.5-flare --scope bosses
py tools/global_art_factory_v3.py --project . --source-root build/starlit_global_art_factory_v3/model_sources --force
```

模型结果会在保持宽高比的情况下装入固定画布；它们仍是候选，尤其是帧动画、人物身份与图集邻接必须在Godot实际画面逐张核对。不会因为生成成功自动覆盖游戏正式素材。没有密钥时不执行收费API，不能将提示词输出冒充已经生成的精修图片。


## V4 画质强化（2026-10-29）

编辑器「星灯美术生产线」现在区分三种真实不同的操作：

- **④ 离线低保真占位**：Pillow 程序化绘制，只用于开发占位，不能当作高清商业原画。
- **⑤ 全游戏高画质任务**：根据当前地图、室内、角色、怪物、Boss 正典输出完整视觉提示词，不调用付费 API。
- **⑥ 模型高清 PNG**：显式调用图像模型；可选类别、生成张数和 xhigh/max。默认仅 8 张，避免误启动数百张付费渲染；将数量设为 0 可一次处理该类别全部资产。可点击「刷新高画质生成结果」查看结果数量。

推荐的高质量命令（必须预先安装 \`openai\`、\`Pillow\` 和设置 \`OPENAI_API_KEY\`）：

\`\`\`powershell
py tools/global_art_ai_provider_v3.py --project . --jobs-only
py tools/global_art_ai_provider_v3.py --project . --render --scope bosses --limit 8 --quality xhigh
py tools/global_art_ai_provider_v3.py --project . --render --scope characters --quality max
py tools/global_art_factory_v3.py --project . --source-root build/starlit_global_art_factory_v3/model_sources --force
\`\`\`

**画质处理要点：** 采用 \`gpt-image-2.5-sunburst\`、默认 xhigh，地图/图集高分辨率、人物竖向原画、Boss 横向母稿分别生成；按正确画幅覆盖或等比缩放，避免横竖挤压、黑框占位、透明背景被替换成底色。对行走帧表保留 4×3 布局；对 Boss/怪物从 3:1 母稿截取中间 4:1 帧条。

**最低质量门禁：** 图片尺寸、真实透明像素、非空内容、色彩层次、动画各格非空，任何一项失败记入 \`render_report.json.failures\`，不进入候选集。成功文件旁的 \`*.quality.json\` 保存提示词、模型、品质、分辨率对应的指纹；升级生成配置后旧图不会被错误地当作新画质缓存复用。注意：程序无法凭这些指标证明角色身份相同、动作自然或地形完美无缝，仍须画廊和 Godot 游戏实机验收。

精修生成路径：\`build/starlit_global_art_factory_v3/model_sources/<scope>/<asset_id>.png\`。
这一步**不直接写入** \`assets/art/runtime\`，不会删除旧美术，也不会绕开 109 槽位的 DLC 正式接入审核。


### 原画参考精修（推荐用于角色与 Boss）

将已经确定外观的原画按 \`<参考目录>/<分类>/<资产ID>.png\` 放置，例如
\`assets/art/reference_masters/bosses/boss_001.png\`。也可以在 Godot 插件 ⑥ 按钮上方填写此目录：

\`\`\`powershell
py tools/global_art_ai_provider_v3.py --project . --render --scope bosses --limit 8 --quality xhigh --reference-root assets/art/reference_masters
\`\`\`

存在参考 PNG 时走 Image Edit 参考精修，要求保持角色面部、服装、装备、配色和怪物关键纹样；没有参考图的登记条目仍走从零生成。参考图超过尺寸限制或无法解码时，该条目记录失败而不是擅自换成另一身份。PNG SHA256 纳入缓存指纹，参考图一旦变更，生成器会重新绘制。**角色身份一致和动画真实连续性仍须人工检查**。

## V4 离线程序资产生成器（合并版）

原 `tools/global_art_factory_v3.py` 入口路径保持不变，内部升级为 **V4.0**，调用新 `tools/art_style_v6.py`。保留 V3 全游戏注册表与精确尺寸规格，并合入旧 HD-2D 生成器的 Sobel 法线贴图与 8 职业、4 物证 SVG。

- 32×32 地形图集采用边缘一致的草、砂、石、木、水材质变体；不触碰地图碰撞数据。
- 96×192 人物图集保持四方向三帧；512×128 Boss/怪物图集保留四帧，按资产 ID 区分形态。
- 建筑、树木、背景提高材质和光照细节；仍属 **程序绘制候选**，不是模型级商业原画。
- 自动创建 `normal_maps/{group}/{asset_id}_n.png`，透明度与原候选 PNG 一致；地图背景与 UI 不烘焙。
- 选择 UI 时生成 `ui_svg/job_icons/` 8 个职业纹章与 `ui_svg/evidence_svg/` 4 个物证 SVG。
- manifest 记录法线图路径及 SHA；升级后自动重绘旧 V3.1 缓存，不继续使用旧版图形。

```bash
python tools/global_art_factory_v3.py --scope all --limit 8 --force
python tools/global_art_factory_v3.py --scope bosses --limit 8 --force
python tools/global_art_factory_v3.py --scope terrain --no-normal-maps --limit 2
python tools/test_global_art_factory_v3.py
```

默认输出仍在 `build/starlit_global_art_factory_v3/`。全部结果需审核确认后再接入正式运行资产；自动生成本身不等于游戏内已经生效，也不等于商业美术验收通过。高画质模型生成是独立链路，需单独生成和验证。

## V4.1 精细绘图引擎（2026-10-29）

`tools/global_art_factory_v3.py` 的命令行入口**不变**，实际程序绘图算法改为 `tools/art_style_v7.py`（基于 V4.0 的增强版）。按 ID 稳定重复生成，内部以 3 倍几何分辨率绘制并回采到游戏现有精确尺寸；不是简单的插值放大，也不产生外部 AI 图片。

- **角色**：职业差异的装备和服装剪影、阴影、头发、面部方向、徽记、步态与携带物；严格保持 96×192 / 4 行×3 帧；仍需确认和既有角色原画的身份一致性。
- **Boss/怪物**：第2章雾潮寄生体、第3章潮痕守卫各自使用独立的结构化轮廓，其他敌人使用五种分组形态；保留每个 128×128 帧、总宽 512×128。
- **建筑和道具**：屋顶瓦片/窗框/砌筑接缝/门槛、非规则树冠及枝条、井/灯/箱/旗的材质与边缘光；输出 96×128。
- **地形**：草、砂、路、木、岩、水和砖材质追加内部细节，同时强制每块 32×32 图块边缘 2px 同色，避免重复平铺时显露块状接缝。
- **背景**：远中近景、天光、城镇连贯地面、道路透视和海岸线等层次；只供装饰，**不能代替地图真实关卡布局或碰撞**。
- **法线贴图**：沿用已合入的 Sobel 流程；候选渲染 PNG 的 alpha、尺寸和 ID 必须匹配法线贴图。
- **缓存**：`VERSION=4.1.0` 触发旧版程序绘图重新生成，但自动保留上一 manifest 已登记的人工/模型导入候选，不会因绘图器升级覆盖它们。

本地专项验证：
```bash
python tools/test_art_style_v7.py
python tools/test_global_art_factory_v3.py
python tools/global_art_factory_v3.py --scope all --limit 8
python tools/global_art_factory_v3.py --scope bosses --limit 4
```
本版本增强的是离线程序绘图的结构和可辨识度；人工校验身份、战斗帧连贯性、整体视觉水准与 Godot 4.7.2 真实画面仍不可跳过。输出保持 candidate-only，不替换正式运行图。
