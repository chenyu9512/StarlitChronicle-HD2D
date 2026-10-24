# ⭐【主仓库 · 当前最完整的游戏主体】《星灯纪行》

> **认准这里：** `chenyu9512/StarlitChronicle-HD2D` → **`main` 分支**。这是目前所有代码与剧情资源整合后的**游戏主体开发版 v0.2**，以后以这里作为主开发入口。
>
> **状态提醒：** “当前最完整的主体”不等于“游戏已全部制作完成”。目前有可运行的村庄/遗迹原型、剧情界面及基础战斗；72章文本和资源数据库已接入，但大部分地图、美术、正式关卡仍待开发。

## 📌 中文分支速查（不要选错）

| 分支 | 中文备注 | 使用建议 |
| --- | --- | --- |
| **`main`** | **⭐ 当前最完整的游戏主体（含金手指 + 72章剧情数据 + 图鉴数据库）** | **正常开发、下载、运行请选这里** |
| `feature/game-core-cheats-v0.2` | 游戏主体 v0.2 集成时的开发分支 | 已同步至 main，不是另一个独立游戏 |
| `content/full-story-v1` | 完整剧情文本分支（12幕72章） | 编剧与文本编辑使用，不能把它当完整游戏 |
| `feature/content-foundation-v0-2` | 人物、怪物、武器、装备、任务等资源数据分支 | 数据制作使用，不能把它当完整游戏 |
| `backup/main-v0.1.1-before-core` | v0.1.1 旧版可玩原型备份 | 仅用于回退、对比和排错 |

**仓库地址：** https://github.com/chenyu9512/StarlitChronicle-HD2D  
**直接查看主体：** https://github.com/chenyu9512/StarlitChronicle-HD2D/tree/main  
**详细说明：** [仓库与分支说明.md](仓库与分支说明.md)

---

# 星灯纪行 · Starlit Chronicle — v0.2.0 游戏主体骨架

**Godot 4 原创横屏 RPG / iPhone 优先 / 本地离线。**

当前版本融合两条内容分支：`content/full-story-v1`（12幕72章、289个叙事场景）及 `feature/content-foundation-v0-2`（分类游戏数据）。主菜单可进入逐句演出的可交互剧情流程，包含选项、事件战斗与进度保存，并支持原有村庄与遗迹试玩地图。

**隐藏金手指：** 右上角小星星在4秒内连续点击5次（桌面 F10 同样可打开），输入密码 `9169` 解锁。提供回复、金币、药草、等级、属性、无敌、禁遇敌、经验倍率、加速、传送和章节调试等功能。部分作弊产生的角色/物品变化会写入存档；暂时性的作弊开关重启会恢复默认。

**开发状态与边界：** 已经完成游戏玩法骨架和叙事数据接线，**不等于72章都拥有独立 HD-2D 实景地图或专属美术和过场**；游戏演出、完整关卡、商店/装备与职业系统仍需逐步开发。具体集成说明见 `docs/INTEGRATION_V0_2.md`。以现有 `main` 的v0.1.1作为可回退备份。

---

# 星灯纪行 / Starlit Chronicle

原创、离线、iPhone 横屏优先的 HD-2D 风格 JRPG 原型。基于 Godot 4.7.2 / GDScript，无云端 API、无账号登录、无收费 SDK。**这是第一版可试玩工程，不是已经完成的商业版，也不是编译好的 IPA。**

## 0.1.0 游戏内容

- 两张完整地图：晨露村与星落遗迹，每张 44×28 格；可平滑移动，角色遮挡遵循纵向深度。
- 触屏虚拟方向键、调查、菜单，电脑也可使用键盘。
- 两名队友（黎昂、澪），4 种敌人，随机遭遇与一场剧情 Boss 战。
- 回合制战斗：攻击、技能、格挡、药草、升级、经验与金币。
- NPC 任务链：守灯人 → 星落遗迹 → 遗迹守卫 → 带回星核 → 完成序章。
- 商人、回复泉水、宝箱、石碑、场景传送、离线 JSON 存档 / 读取。
- 原创程序生成的像素素材、近景遮挡、灯光渐变与景深错觉；这里的「HD-2D」是 **2D 多层/光效视觉方向**，没有实际 3D 模型或高阶实时全局光照。

**版权说明：** 不使用《勇者斗恶龙》的角色、怪物、Logo、剧情、美术或音乐；仅借鉴经典 JRPG 的通用玩法。项目内程序生成的素材可作为原创原型继续修改。

## 目录结构

```text
StarlitChronicle_0.1.0/
├── project.godot                 Godot 工程入口
├── export_presets.cfg            iOS 导出设置；签名前替换标识
├── codemagic.yaml               Codemagic 无签名编译 + IPA 封装
├── scenes/main.tscn              主场景
├── scripts/
│   ├── game.gd                  游戏流程、地图切换、NPC 任务
│   ├── world.gd                 地图、遮挡、移动、交互、遭遇
│   ├── actor.gd                 角色方向与步行动画
│   ├── battle.gd                战斗逻辑与战斗界面
│   ├── game_ui.gd               HUD、触屏方向键、对话与菜单
│   └── game_state.gd            存档、等级、背包、任务进度
├── data/
│   ├── village.json            村庄地形和交互实体
│   └── ruins.json              遗迹地形和交互实体
├── assets/
│   ├── maps/                   地图背景、战斗背景
│   ├── props/                  建筑、灯、宝箱、NPC 等
│   ├── characters/             角色 3×4 精灵表
│   ├── enemies/                原创怪物立绘
│   └── fx/                     灯光透明纹理
├── tools/generate_art.py        全部素材的可复现生成脚本
└── icon.png                     游戏临时图标
```

## Windows 启动（建议先在这里验证游戏）

1. 从 <https://godotengine.org/download/windows/> 安装 **Godot 4.7.2 标准版**（不需要 .NET 或 C# 版）。
2. 解压项目；Godot 项目管理器选 **Import**，选择 `project.godot`。
3. 等待资源导入完成；点击右上方三角形 ▶ 或按 **F6/F5** 运行主场景/项目。
4. 在初始对话中点「继续」，走到村子中心的守灯人处按 E 或「调查 / 对话」。
5. 接任务后向地图东边移动，调查石门进入遗迹。完成 Boss 战，回村交任务。
6. 菜单中可以喝药草或保存，重新运行游戏会自动读取最近一次存档。

**键盘：** WASD / 方向键移动，E / Z / 空格调查，M / Esc 打开菜单。移动端使用左下角方向键，右下角调查和菜单。

**重新开始：** 删除 Godot `user://starlit_save_v1.json`（在 Godot 编辑器打开用户数据目录），或用编辑器进行新测试。当前原型启动时自动读取存档，暂不提供多档位选择。

## iPhone（Windows + Codemagic + SideStore）

Godot 4.7 的 iOS 原生导出必须运行于 macOS/Xcode。已经随工程附带一个 **Codemagic macOS 无签名工作流**：导出 Xcode 工程 → 编译 `.app` → 封装 unsigned `.ipa`。SideStore 可尝试为其重新签名安装；安装是否成功受你当前 iOS 版本、Apple ID 配额、SideStore 环境与签名兼容性影响，不能在此提前保证。

1. 新建**独立 GitHub 仓库**（不要覆盖其他项目）；把此目录的**所有内容直接放在仓库根目录**，其中 `codemagic.yaml` 必须位于根目录。
2. 在 Codemagic 新增该仓库并选择 `ios-unsigned` 工作流，使用 macOS 构建节点。
3. 构建成功后，在 Artifacts 下载 `StarlitChronicle-unsigned.ipa`；如果失败，把构建日志保存下来方便修复。
4. 用 iPhone 的 SideStore 从本地文件导入 IPA，尝试重新签名安装。新游戏不要求屏幕录制或 App Groups 权限。
5. 免费个人 Apple ID 侧载可能受 7 天有效期和同时安装应用数等限制。根据 SideStore 当前文档准备相关环境。

**生产签名 / App Store：** `export_presets.cfg` 中的 `ABCDE12345`、`com.example.starlitdemo` 仅供无签名测试，不能当作有效开发者身份。在准备正式发布时，替换为你实际的 Apple Team ID 和唯一 Bundle Identifier，在 Codemagic 设置签名证书 / provisioning profile 后切换为正式归档工作流。Apple App Store 发版还有付费开发者账号、隐私与内容合规等要求。

**Codemagic 特别注意：** 不要把游戏文件放在 `Game/` 子目录却把 YAML 留在上级，因为本工作流默认 `project.godot` 位于仓库根目录。免费构建额度与可用 Xcode 镜像以 Codemagic 当下计划为准。

## 美术调整和后续路线

- 重新生成所有素材：安装 Python 3 + Pillow，运行 `python tools/generate_art.py`。它会重写 `assets/` 与两份 `data/*.json` 地图。
- 新地图：参照 `data/village.json` 的 `tiles`（44 个字符/行）和 `props`（x/y/kind/interact/solid）字段；再生成对应地图 PNG。
- 推荐下一阶段：触屏摇杆、场景动画、状态异常、装备与物品、多个剧情章节、昼夜/天气、粒子与 3D 光影、音效配乐、国际化中文/日文、存档迁移、iPhone 安全区域适配、设备性能测试。

## 已知限制与验证状态

- 此环境已生成且静态检查了脚本、JSON、贴图与引用；**没有可用的 Godot 引擎和 macOS/Xcode，尚未完成真正的 Godot 启动测试或 iPhone IPA 编译**。如果 Codemagic/Godot 在首次运行报错，请以完整日志为依据修正。
- 没有配乐、动态天气、真实体积光、Apple 平台原生订阅、游戏手柄适配或 App Store 发布流程。这些属于后续开发范围。
- UI 采用中文；在部分设备上 Godot 默认字体回退行为可能不同，需要实机确认字形、触控大小和安全区。
- 默认原型画面为横屏，以兼容性渲染器减少 iPhone GPU 的运行压力。

## 参考文档

- Godot 4.7 官方 iOS 导出：<https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html>
- Codemagic 无签名与首次签名：<https://docs.codemagic.io/yaml-quick-start/first-signed-build/>
- SideStore 安装与签名：<https://docs.sidestore.io/docs/installation/install>


## v0.1.1 修复记录

- 修复 `scripts/world.gd` 互动距离计算中 `Parser Error: Cannot infer the type of "distance" variable`。
- 为 `player_position`、`target_position` 和 `distance` 添加显式 GDScript 类型，避免通过 Dictionary/Variant 自动推断失败。
- 兼容原有 `user://starlit_save_v1.json` 存档格式；本次未修改地图、战斗、剧情数据或存档协议。
- 校验说明：运行了 Python 资源和地图完整性检查；当前环境未安装 Godot，也没有 macOS/Xcode，尚无法在本环境证明游戏可通过 Godot 运行及 iOS 编译。

## 全游戏资源基础（v0.2 开发分支）

正式世界设定「洛维恩」的第一批内容数据库位于 `data/content/`，共 549 条设计记录（涵盖人物、NPC、怪物、BOSS、地图定义、武器、防具、物品、技能、任务与地域）。提供 `scripts/content_db.gd` 只读 Godot 查询器，并在菜单加入「星灯图鉴（内容预览）」可分类查看。运行 `python tools/validate_content.py` 可检查完整性。

**进度说明：** 设计数据不等于完成美术、场景或战斗逻辑；正式地图尚未制作，72章任务已与独立剧情分支的真实章名、地点和摘要同步，但正式剧情引擎仍未接入主游戏，现有序章和存档原样保留。详细规范见 `docs/CONTENT_FOUNDATION.md`。

**剧情与图鉴协作：** 这批资源已与 [正式剧情 PR #1](https://github.com/chenyu9512/StarlitChronicle-HD2D/pull/1) 对齐；两个 PR 需要分别审查，故事文件合并后方可利用 `story_source` 路径运行剧情。
