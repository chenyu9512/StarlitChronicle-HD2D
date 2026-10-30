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
