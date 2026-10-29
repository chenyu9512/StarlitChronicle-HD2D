# 《星灯纪行》｜外部美术、音乐、音效与日语配音接入说明

> 审计日期：2026-10-25。适用仓库 `chenyu9512/StarlitChronicle-HD2D`，正式主体 `main`，Godot 4.7.2，iPhone 横屏优先。
>
> 本文是**资源审计与引入指导**，不是“全部素材已完成/已购买/已接入”的交付声明。本次仅检查 GitHub 文件、部分加载脚本及既有报告；没有运行 Godot、播放媒体、人工验图或完成 iPhone 真机测试。仓库仍有并行提交，所有数量为本次观察时的目录快照。

## 一、资源现状：先复用，后采购

本次 Git 树目录快照约 1,975 项（文件与目录），`assets/` 下 1,589 个文件，其中约 1,432 个 PNG、99 个 SVG，另含 JSON、CSV、说明与预览。**仓库内未发现 WAV/OGG/MP3/FLAC 等音频文件，不能据此断言音频播放系统已完成。**

| 现有资源 | 仓库位置与核对结果 | 交付判定 |
|---|---|---|
| Batch 0–3 海岸资源 | `assets/art/art_manifest.json`：89 项 SVG 源资源登记；PNG 配套导出。人物、海岸图块、道具、9种海岸魔物。 | 初稿/局部精修；不是全部正式可玩场景 |
| B01 批次 | `assets/art/b01/README.md`：报告记录 1,091 张程序化原型 PNG，覆盖 8 地区地图示意、158 名南向角色原型、63 种普通怪原型、66 个 Boss 剪影、图标等。 | 大部分是占位/视觉底稿；南向单帧不等于完整行走动画 |
| B02 批次 | `assets/art/b02/README_CN.md`：12 名主要人物 + 35 名 NPC，共 47 人，每人4张透明视觉母稿，合计188张；另含风格/生物概念。 | 适合图鉴/对话/外观确认；不是32×48四方向行走精灵 |
| B03 批次 | `assets/art/b03/boss_battle_concepts/` 与 `boss_sigils/`：第2–6章5场 Boss 的1024×1024概念造型和512×512标识。 | 视觉设定锚点；没有完整攻击、受击、阶段动画 |
| 旧版兼容资源 | `assets/characters`、`assets/enemies`、`assets/maps`、`assets/props` 等 | 仍保留，不因采购而批量删除 |
| 音频 | 目录扫描未找到常用音频文件，亦无独立 `assets/audio/` 目录 | 音乐、音效、语音的采集/授权/导入/触发均未验收 |

**重要区别：** 文件数量、资源 JSON 记录数、预览图和实际运行时接入数不是同一个指标。B01 的地图底稿不是42张手工精制 `.tscn` 地图；B02 的角色头像不能自动当作行走动画；B03 的 Boss 造型不是 Boss 全套动作。

### 已核对的实际加载入口

- `scripts/first_act_world.gd` 读取 `res://assets/art/tilesets/coast_ground.png`、`coast_water.png`，使用 `assets/art/characters/{角色}/walk_4dir_3frames.png`，以及 `assets/art/props/coast/*.png`；该脚本建立可操作 `TileMapLayer` 和简单视觉灯光。
- `scripts/first_act_ui.gd` 读取四名既有人物的 `dialogue.png`，并引用 `backdrops/coast/tide_lighthouse.png`。
- `scripts/art_gallery.gd` 是开发用的画廊，读取 `assets/art/art_manifest.json`，**出现在画廊不等于主线已绑定**。
- `data/content/manifest.json` 是世界、人物、武器、怪物等**玩法数据索引**；`assets/art/art_manifest.json` 是一部分**美术制作索引**。两个清单的职责不同；B01/B02/B03 的批次清单也不可无条件合并。
- `docs/PHASE_00_10_BASELINE_AUDIT_2026-10-25.md` 显示工程的运行验收与美术产品验收尚未完成；不要把本文解释成它们已通过。

## 二、选型结论

**优先级 1：保留现有项目的原创人物身份、世界视觉与稳定 ID。** 主角、岚音、澄舟、朔弦、五场 Boss、七母灯、区域概念和主要剧情 CGI 不应被同质化外购包直接覆盖。

**优先级 2：免费、明确可商用、适合补足缺口的现成素材。** 首选 UI 操作、脚步、碰撞、命中等重复性效果音；其次选背景氛围、配音原型，再决定是否购买地图扩展。

**优先级 3：按地区定向采购。** 只在缺少正式可走地图、房屋室内件、场景机关、动画怪物或 UI 组件时引入。先完成第一幕六章，再扩大到 8 地区和72章。

| 用途 | 候选来源 / 官方下载 | 推荐态度与必要条件 |
|---|---|---|
| 基础场景、城镇、森林、地牢 | [Time Fantasy – Fantasy RPG Tileset](https://finalbossblues.itch.io/fantasy-rpg-tileset-pack) | **候选**；原素材16×16，当前项目海岸图块32×32，必须做格子尺度/配色/碰撞的对照适配；从作者直接销售渠道核实许可 |
| 同一画风 NPC/角色扩展 | [finalbossblues 商店](https://finalbossblues.itch.io/) | **可试用对照，不建议先整包购买**；避免替换已确定的原创主角/B02人物身份 |
| 32×32 地牢扩展 | [DithArt – Fantasy Dungeon](https://dithart.itch.io/fantasy-dungeon-tileset) | **候选**；技术比例较接近，仍需验证许可、尺寸、纹理与项目风格兼容 |
| 免费 RPG 脚步/动作 SFX | [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | **首批推荐**；官方 CC0，先做解包、格式核验及听感筛选 |
| 免费受击/打击 SFX | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | **首批推荐**；官方 CC0 |
| 免费界面 SFX | [Kenney UI Audio](https://kenney.nl/assets/ui-audio) | **首批推荐**；官方 CC0 |
| 日式幻想 BGM | [PeriTune](https://peritune.com/freematerial_list/) | **条件候选**；**不同发布时期/曲目许可可能不同**，尤其有偿游戏分发及音频提取保护要求，不要批量下载后直接打包发行 |
| 日式 RPG BGM | [魔王魂](https://maou.audio/) | **条件候选**；逐曲登记规则、署名与二次分发限制 |
| 游戏日语真人战斗声 | [VOICELIB 官方 BOOTH](https://voicelib.booth.pm/) | **优先试听**；查看每个产品附带 readme、商业许可、年龄分级、署名要求；试音包不一定有正式版许可 |
| 本地批量日语对白 | [AivisSpeech](https://aivis-project.com/AivisSpeech) | **试验候选**；软件可商用不代表每个模型都可商用；声线须单独记录模型 ID、版本与许可，排除 NC 限制 |
| 免费日语系统语音 | [VOICEVOX Nemo](https://voicevox.hiroshiba.jp/nemo/) | **试验候选**；官网许可要求注明 `VOICEVOX Nemo`；不应擅自模仿真人声优或游戏已有角色声音 |
| Mana Seed | [原始项目页](https://seliel-the-shaper.itch.io/rpg-starter-pack) | **排除**；作者要求开发时不使用 AI；本项目为 AI 辅助开发，不符合该前提 |

> 以上为**可调查清单，非已采购/已授权/已下载的资产**。价格与条款随时变化，以实际下载当日的产品和随包 LICENSE/readme 为准。Time Fantasy 在 itch.io 作者直售版可商业用于 Godot，RPG Maker 商店/Steam DLC **可能存在仅限 RPG Maker 的独立许可**，不要混用。完整的商用发布许可逐项留档后再导入正式版。

## 三、明确需要补齐的资源

| 子系统 | 当前已有 | 必须补齐才可算成品 |
|---|---|---|
| 第一幕地图 | 海岸 32×32 地形、道具、背景、地图布局数据与 TileMapLayer 路由 | ch001–ch006 六章专属可走场景、阻挡/机关/转场、各地区室内与地牢、手动编辑的图层和碰撞 |
| 主角/同伴/NPC | 四名现有角色的对话图；B01/B02 原型和高细节母稿 | 人物四方向逐帧、交互动作、战斗姿态、表情一致性、NPC 可辨身份及移动 |
| 敌人与Boss | 海岸9怪、B01中63怪及66 Boss原型、B03五Boss设定 | 受击/攻击/倒地/技能动画、独立剪影和真正的分阶段变化、逐对象绑定 |
| 装备与家园 | 武器/防具/家具数据，以及B01武器/护甲图标草稿 | 游戏内装备图、锻造/VFX、房屋地形/家具图、真实家园地图与动作 |
| UI/过场 | 现有可用菜单与美术UI原型、剧情构图 | 通用九宫格、字体与触屏布局规范、动画、过场CG、分辨率/高对比度验收 |
| 声音 | 尚未发现本地音频文件 | BGM播放控制、场景切换与淡入淡出、循环点、脚步/碰撞/UI/SFX、语音字幕同步、混音与存档音量设置 |

## 四、统一接入规范（新增文件建议；本次不修改运行代码）

建议在 `assets/` 下增加：

```text
assets/
  audio/
    bgm/{town,field,dungeon,battle,boss,story}/
    sfx/{ui,footsteps,combat,ambient,house}/
    voices/{party,npc,boss,narrator}/
  art/external/{tilesets,ui,icons,animations}/
  licenses/                 # 文本许可、来源说明、署名记录；不要存令牌或私人购买凭证
data/assets/
  external_asset_registry.json   # 建议新增：逻辑ID与来源、许可证和接入状态的映射
```

**不把购买的 ZIP、原始打包资源、敏感票据、私有下载链接直接放进仓库。** 对允许团队/仓库分发的文件，先决定存放方式与仓库权限；不能靠“GitHub 是私有仓库”代替许可证审核。

建议的单条资源记录（示例，路径目前并不存在）：

```json
{
  "id": "sfx.ui.confirm",
  "kind": "sfx",
  "source_name": "Kenney UI Audio",
  "source_url": "https://kenney.nl/assets/ui-audio",
  "license": "CC0",
  "license_verified_on": "2026-10-25",
  "runtime_path": "res://assets/audio/sfx/ui/confirm.ogg",
  "integration_status": "planned",
  "usage": ["menu.confirm", "dialog.confirm"],
  "credits": ""
}
```

接入状态统一用 `planned`（计划）、`acquired`（下载/购买完成）、`license_reviewed`（商用条款核验）、`imported`（引擎导入）、`runtime_bound`（事件接线）、`qa_passed`（真机/发行验收），**不能跳过许可核验直接写 `qa_passed`**。

### 导入 Godot 的技术原则

1. **地图**：先做单张测试地图；核对16×16与32×32图块在相同世界单位下的逻辑对应关系。不能仅因同为像素风，就把 tile atlas 覆盖现有 `coast_ground.png`。
2. **动画**：优先采用现有 `walk_4dir_3frames.png` 行列协定（每帧32×48；DOWN/LEFT/UP/RIGHT，每方向3帧）；外来动画缺帧要做重映射，不复制伪帧充数。
3. **图片**：透明 PNG、sRGB、Nearest/整数比例显示；先检查画布、alpha边缘、人物站立基准点、Y Sort 与碰撞边界。
4. **音效**：短促 SFX 可用 WAV/OGG，长 BGM 更倾向 OGG；重点检测 iOS 实际解码、同时播放、循环接缝、延迟、压缩体积。
5. **声音**：音乐、音效、语音拆为不同 Audio Bus；存档保存总音量/音乐/音效/人声；场景切换平滑淡入淡出，战斗语音不能盖过关键对白。
6. **对话语音**：一个 `line_id` 映射到一个音频文件；语音缺失必须无声回退且照常显示字幕；播放下一句要停止或淡出上一句。日语台词经文本审核后再生成，避免每次修改剧情都重新录制全量音频。
7. **大小与性能**：iPhone 横屏真机核对纹理内存、首场景载入、音频缓存、峰值混音与 FPS。CI 文件检查只是基础，不能替代真实设备听看。

## 五、推荐制作批次及验收

### P0：清单/许可/结构（先做）

- 对 `art_manifest.json`、B01/B02/B03 三份生产索引去重并交叉引用，但保留各自原始 ID。
- 记录主剧情运行时真正引用的资源路径，与“仅在画廊/概念库存在”的资源严格区分。
- 导入三套 Kenney CC0 音效候选的少量样本；为声音建立合法来源/署名目录。
- CI 中校验：文件存在、允许的文件格式、资源ID无冲突、所有外部资源具备来源与许可状态。

**验收**：一张可复查的资源注册表；不动历史角色ID、存档、旧资源路径。

### P1：第一幕六章视觉与声音样板

- 从晨露村 → 白砂港 → 潮歌灯塔选一条完整路线；实际建立可走地图，不用静态背景代替碰撞地图。
- 现有四名角色至少补齐所需移动/对话/战斗动作；五场 Boss 先保留 B03 设计特点再制作动画。
- 选定一首授权明晰的野外BGM、一首村镇BGM、一首普通战斗BGM、一首BossBGM；再选20–40个基础 SFX 和几种人物战斗短声。
- 为 UI 提供音量开关、音频缺失静默回退、语音字幕同步，不让声音问题阻塞主线。

**验收**：全新存档连续游玩 ch001–ch006，有场景音乐、脚步/UI/战斗音效及可调音量，游戏全程没有无授权资源。

### P2：地区化扩展

- 按 8 地区统一色板和材质，逐地区补场景、道具、怪物音效与地牢层次。
- 以 ID 绑定怪物/角色/装备图，而不是用图序号猜测身份。
- 用同一批正式素材制作关卡，不要为同样功能重复购买多个不同画风资产包。

**验收**：资源能够追踪到章节、地图、怪物、事件，且资源体积、iPhone 性能、署名与许可可审计。

### P3：后期叙事表现与发行

- 三结局关键过场、独立BGM、核心 NPC 语音、Boss阶段演出逐个完善。
- 人声长期建议采用“普通 NPC 文字＋关键台词语音＋全员战斗反应声”，不要一次性预生成72章所有台词。
- 游戏打包前执行第三方授权复查，尤其 PeriTune 新曲目的有偿分发条件、Aivis 个别模型的 NC 条款、VOICELIB 的具体包约定、VOICEVOX Nemo 署名。

**验收**：安装包、信用页、授权记录、可追溯资源ID、真机听感、完整主线与存档兼容全部通过。

## 六、采购前的禁止事项与决策

- **不使用**《勇者斗恶龙》系列的角色、怪物造型、商标、地图、歌曲、音效或声优样本直接复制/模仿作为本作商业资源。参考经典游戏的系统设计，不等于取得其素材使用权。
- **不购买**只支持 RPG Maker 的 DLC 后用于 Godot；同名素材应以实际购买渠道授权为准。
- **不采用**禁止 AI 参与的 Mana Seed；不采用标注 NC、禁止商用或授权不明的素材/声音。
- **不进行**未经许可的真人声优声线克隆。
- **不以**“已放进仓库”“能在画廊展示”“自动化扫描PASS”替代美术、音频和游戏可玩性验收。

## 七、下一次正式开发的交付清单

1. `data/assets/external_asset_registry.json` 的实际 schema、校验脚本与示例数据。
2. 首批免费声音文件的授权审计与导入（仅对授权明确、实际下载成功的文件做实装）。
3. `AudioManager` / Audio Bus、UI按钮/脚步/攻击/胜利/场景切换事件钩子与音量菜单。
4. 第一幕 ch001–ch006 的 `asset_id` → `runtime_path` 对照清单及缺口表。
5. 6章游戏场景美术与音效验收报告；合格后再展开后续地区。

**本文件完成的是核对与说明，不代表上述开发任务已经执行。**
