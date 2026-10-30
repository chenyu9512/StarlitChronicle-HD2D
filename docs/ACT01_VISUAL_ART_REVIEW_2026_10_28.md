# 第一幕六章实机美术检查 · 2026-10-28

## 证据来源
- GitHub Actions: [Main2 · Real Art Runtime Acceptance / run 40621916954](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40621916954)
- 源提交：`7866c55c54505be482f31fcba43741b8106c014a`（**早于当前 V3 管线修改**）。
- 实际产物：`main2-art-runtime-evidence`，包含 `visual/chapter_01_world.png` 到 `chapter_06_world.png`、旧屋/收容所/酒馆及关键地标画面。
- 截图来源为 Godot 真实 framebuffer，而非生成的概念美术。**本文件不声明最新 HEAD 视觉已通过**。

## 实际画面观察与明确任务

| ID | 画面 | 真实截图中存在的问题 | 最小改进方向 | 状态 |
|---|---|---|---|---|
| ART-VIS-01 | 第一章旧屋 | 大块家具/墙面贴图比例与室内视角不协调，顶部道具存在大面积强烈拼贴感 | 对旧屋源素材重新裁切并按像素与透视约束配置，逐物件确认用途与遮挡 | `needs_visual_fix` |
| ART-VIS-02 | 第二章收容所 | 大面积暗石地板、空旷区域突出；医疗空间的功能家具和玩家可识别的救助线索视觉不足 | 独立医院/收容所图集与治疗区功能摆放，不用酒馆物品或市场摊位冒充医疗设备 | `needs_visual_fix` |
| ART-VIS-03 | 第四章黑帆酒馆 | 木地板与家具风格较统一，但家具集中、空间显空，缺乏酒馆活动的连续功能分区 | 对吧台、用餐区、公告/调查区进行真实空间组合与动线核查 | `needs_visual_fix` |
| ART-VIS-04 | 第一幕外景 | 多个场景均以铺满的大块石砖及硬切边界作为主要视觉结构，地域轮廓与地形边缘层次不足 | 优先改道路/沙地/草地交界和区域独有地标，不复制同一整块地面布局 | `needs_visual_fix` |
| ART-VIS-05 | 89 槽完整换肤 | 之前的主题表遗漏 V18 已可见的八种世界贴图；现已补回 89 槽并增加 14/14 摆放贴图检查 | 在新 SHA 运行主题冒烟 + 实机截图复审，确认真实画面主题切换 | `code_fixed_awaiting_godot` |

## 通过准则
- 视觉整改以 **当前 Main2 新 HEAD** 的独立截图复审，不能使用该旧 SHA 截图冒充新版本签收。
- 每个已摆放的实机对象必须验证：身份、尺度、空间方向、遮挡、贴图接缝，以及玩家到达路径。
- 仅文件存在、Godot 可加载、CI 成功不等于商业视觉签收。
- 不采用任意材质随机组合或风格不符的第三方贴图替代。代码与资产变更应逐项修改到正式场景，并保留可复查证据。


## 2026-10-30 / 第一幕视觉截图字体真实性补强（提交后需最新 CI 与画面复审）

- 已确认上一轮 Boss 分回合回归修复 `32d395b0f173b27faa9513de543427d552b55a2c` 的 [Godot 质量门禁与 Runtime 发布全部成功](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41027364370)。可进入第一幕美术取证，但尚不代表商业视觉验收。
- **根因**：原 `capture_act01_visual_evidence.gd` 在截图时创建 `SystemFont` 并覆盖 ThemeDB fallback/default，导致 CI 系统上的 Noto 字体能掩盖打包程序真正使用的 `FontSetup` 字体资源。
- **修复**：截图脚本不再指定 SystemFont；从真实 `/root/FontSetup` 加载 `FontFile`，强制核对渲染 FontFile 与仓库内 `NotoSansCJKsc-Regular.otf` 的原始数据 SHA-256、字体大小、19个中日英字形及游戏实际3个 UI Control 的字体绑定。记录 `visual/cjk-font-evidence-v1.json`，任何系统字体替代、字形遗漏、哈希不同或 UI 未绑定立即失败。
- **证据审计**：`verify_act01_visual_evidence_v3.py` 除26张真实 Godot 截图之外还核对字体来源证明、真实字体源文件哈希/长度、字形/Control、且明确 `ios_ipa_payload_verified=false` 与 `ios_device_verified=false`。提供独立负例测试，禁止伪造 iPhone 真机通过。
- **CI 接入**：视觉验收 workflow 在截图/审计/FontSetup 或 OTF 改动时自动运行；只安装 Xvfb、GL 依赖，**不再安装系统 Noto CJK 字体** 来掩盖包内字体缺失。统一 CI art 静态测试审计证据契约。
- **范围**：本次没有新增角色/环境 PNG，也没有改任何摆放场景，因此不生成重复资产；先取得最新真实六章截图与来源证明，然后继续旧屋/收容所/酒馆的结构与美术修整。真实 iPhone IPA 包内字体仍要通过独立 IPA payload 校验和物理真机验收，Godot 截图不是后者的替代品。

## 2026-10-30 · 最新 Godot 真实截图复审 / 尚未商业签收

**证据**：提交 `a077735001ebcf35794d70a8fc4e6c6569be558d` 的 [Main2 Real Art Runtime Acceptance / run 41044081702](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41044081702)，截图附件 `main2-art-runtime-evidence`（artifact ID `12971512044`）。真实 Godot framebuffer 26/26；`visual/cjk-font-evidence-v1.json` 校验通过：`FontSetup` 导入 FontFile SHA256 `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`，19个中日英字符、3个真实游戏 UI 控件、源 OTF 一致。未使用系统字体替代，不代表 iPhone IPA 实机字体已验收。

**实际渲染画面观察**（针对 `visual/*_world.png` 和带 HUD 原图，人工视觉问题追踪，不是质量自动通过）：

| ID | 本轮真实截图文件 | 当前可见问题 | 下一批具体修复口径 | 结论 |
|---|---|---|---|---|
| ART-VIS-01 | `chapter_01_house.png` / `_world.png` | 居住空间主要是大片同色地面与少量沿上边散布的小家具，空间尺度和生活用途不突出；深蓝边界块在下半画面占比明显 | 重组现有已授权家具：桌/储物/睡卧围合成可辨生活区；边界遮挡与像素缩放应在正式 V4 室内运行器核验，不用假贴图填空 | `needs_visual_fix` |
| ART-VIS-02 | `chapter_02_shelter.png` / `_world.png` | 收容所空旷的重复底纹占大面积；几张床、医护和病历/调查点散落，缺少分组明确的诊疗、临时病床、登记与药品功能区 | 优先重排真实医院相关已有素材；床位围成医疗区，证据与名册附近设置诊疗/登记阅读路径，并复验碰撞及房间门口通行；禁止把酒桶酒馆道具冒充医疗设备 | `needs_visual_fix_priority_1` |
| ART-VIS-03 | `chapter_04_tavern.png` / `_world.png` | 桌椅、灯光及人物存在，但孤立散布，吧台/用餐/公告调查区的识别性仍不足；空地仍显过宽 | 将已有桌椅/储物/灯具按三功能区成组布置，保留主要剧情 NPC 可接近性及入口行动通道 | `needs_visual_fix_priority_2` |
| ART-VIS-04 | `chapter_01_world.png` — `chapter_06_world.png` | 外景具备独立草地、沙地、石砖和海蚀洞灰色基调，但部分路面呈明显直角大块区隔；第2/4章复用白砂港地图的区域差异并不显眼 | 按已注册世界地标及海岸材料做过渡与区域独有视觉分组；对同地图章节允许复用，但应有清楚的剧情调查重点，不能通过伪造截图解释为不同地图 | `needs_visual_fix` |
| ART-VIS-05 | 本批全部26张与 `cjk-font-evidence-v1.json` | 真实截图已成功、核心字形可见；但 HUD 的字体存在与 iOS 设备一致性之外的布局/空间审美问题，尚未完成视觉评审 | 保留截图 hash、字体源证明和最新版截图链接；将真正游戏内字体/CJK 验证与 iPhone PCK、设备端字形分开签收 | `font_source_proved_art_unapproved` |

**验收边界**：静态资源/字体证据通过不表示角色与道具的比例、空间可读性、风格、独立地图差异得到商业批准。本项只是将最新真实截图中的问题具体化；没有新增任何图形资产或修改场景摆放，未冒充修复。下一项优先完成收容所治疗/登记分区的**正式场景**调整并在新 SHA 截图中核验。


## 2026-10-30 · 第二章收容所医疗功能区第一批实装（待新 SHA 视觉复审）

- 整改前证据 `a077735001ebcf35794d70a8fc4e6c6569be558d` [真实 Godot 26 帧](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41044081702)：诊疗登记位置可见，但病床等专属医疗设施分散，重复地面占据过大画面。
- **正式场景改动**：`data/levels/v4/interiors/map_coast_02__shelter.json` 增加三个有唯一场景 ID 的医疗病床（西侧护理、西侧恢复、东侧恢复）与右侧诊疗药盘，使已导入医疗实体由11增至15；四个新实例使用 V10 Manifest 中已授权登记的 `shelter_cot`/`shelter_treatment_tray` 真实 PNG，非假图。新增复用现有灯光生成器的恢复区灯光（3→4）。
- **真实碰撞**：三张新增病床脚下物理接触点设置碰撞，保持中心入口/主线通行带、NPC与已有4项调查和5处主线位置不变。场景的 care_zone 标签在 `world_interior_art.gd` 正式 Sprite2D 上实例化，不是独立美术列表。
- **验证**：新增 `validate_act01_shelter_care_zones.py` 静态校验素材源、布局和真实 V4 连通性；扩展 Godot 实景 harbor smoke 验证实际 PNG、像素位置、房间光源、病床碰撞、NPC/剧情到达。新 SHA 还必须重跑 26 张真实 Godot 截图并进行改前/改后人工视觉比对，现暂不可标记商业美术通过。
