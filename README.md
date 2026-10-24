# 星灯纪行 / Starlit Chronicle

> **⭐ 当前唯一游戏主体：[`main` 分支](https://github.com/chenyu9512/StarlitChronicle-HD2D/tree/main)。**
> **工程阶段：v0.3 第一幕（童年序章＋第1—6章）可玩集成版。** 不是全72章商业发行成品。

**GitHub 仓库**：`chenyu9512/StarlitChronicle-HD2D`（私人仓库）  
**开发引擎**：Godot 4.7.2 / GDScript  
**主要平台**：iPhone 横屏；Windows 上先运行和调试  
**默认场景**：`scenes/first_act.tscn`  
**旧版场景**：`scenes/main.tscn`（保留供历史对照）

## 一分钟看懂：为什么会有8个分支？

之前为了分离编剧、美术、金手指、第一幕整合与版本备份，先后建立了独立分支。**功能已合入 `main` 的集成分支没有及时清理**，因此列表看起来比实际需要的复杂。

**现在规定：只有3条持续使用的分支。其余5条全部按历史只读留档管理，不作为新功能的开发起点。**

| 分支 | 中文名称 | 管理状态 | 你什么时候用 |
| --- | --- | --- | --- |
| **`main`** | ⭐ **完整主体/唯一运行入口** | **正式整合、持续维护** | **下载、运行、测试、查看当前游戏** |
| `content/full-story-v1` | 剧情与对白资料 | **持续开发** | 编写72章剧本、文本、任务对白；审核后择项同步到main |
| `feature/content-foundation-v0-2` | 美术及内容数据库 | **持续开发** | 制作SVG/PNG、场景美术、怪物/装备等资源；审核后择项同步到main |
| `feature/first-act-production-v0-3` | 第一幕功能集成留档 | 历史只读（已合入） | 追溯第一幕开发提交，不是最新版 |
| `feature/first-act-resource-sync-v0-3` | 第一幕素材同步留档 | 历史只读（与此前main提交一致） | 追溯精修美术与文本同步，不是最新版 |
| `feature/game-core-cheats-v0.2` | v0.2 金手指集成留档 | 历史只读（已合入） | 回看金手指实现历史 |
| `backup/main-before-first-act-20261024` | v0.2 游戏主体备份 | 历史只读（安全回退） | 发生重大回归时查旧版 |
| `backup/main-v0.1.1-before-core` | v0.1.1 早期工程备份 | 历史只读（安全回退） | 对比最早能运行的 Godot 原型 |

完整逐条说明和开发规范：**[《仓库与分支说明》（中文）](仓库与分支说明.md)**。

### 当前内容同步状态

- **美术分支的 Batch 0—3 和海岸精修 V2** 已按资源文件同步到 `main`；素材分支自身保留旧版玩法脚本，**绝不能把整个分支的 `scripts/` 覆盖主仓库**。
- **剧情分支** 的第一幕重写、第二至第四幕已审核文本包和世界资料已经同步；审查时发现其 **第7、9、10、11、12章** 后续还有不同于 `main` 的文本修订，**尚待单独审稿，不视为已合并**。
- 集成代码以 `main` 为唯一来源。**不允许无差别合并两条内容工作分支**。

## 运行方式（Windows / Godot）

```powershell
git clone -b main https://github.com/chenyu9512/StarlitChronicle-HD2D.git
```

已克隆过的工程更新：

```powershell
git switch main
git pull origin main
```

在 Godot 4.7.2 中 **Import** 本仓库根目录的 `project.godot`，等待图片资源导入完成后按 **F5**。默认进入 `scenes/first_act.tscn`。

- **移动**：WASD、方向键或触屏方向控制。
- **调查**：E / 屏幕“调查”按钮。
- **菜单与存档**：游戏内菜单；第一幕存档为 `user://first_act_v3.json`，不会覆盖旧版 V1 存档。
- **隐藏金手指**：右上角星星4秒内连续点击5次（PC 可按 F10），密码 `9169`。

## 第一幕已经接入的玩法

九场序章、第一幕六章的**实地移动／任务目标／对白与选项／战斗和章节结算**；六条可在地图上领取与交付的支线；第2—6章五场 Boss；新角色行走表、海岸图块、道具及怪物资源；横屏触控 HUD、升级成长及离线存档。项目依然保留12幕72章的长期剧情资料和未完全实现的设计型数据库。

**当前并未完成全部72章可探索地图、商业级角色/Boss动画、完整职业/装备系统、BGM/音效，以及 iPhone 真机长期性能与正式签名验证。** 请勿把数据量或 Godot 自动检查通过解释为 App Store 成品认证。

## 主要代码与文档

| 文件/目录 | 作用 |
| --- | --- |
| `project.godot` | Godot 项目入口 |
| `scenes/first_act.tscn` | **当前主体主场景** |
| `scripts/first_act.gd` | 第一幕主流程 |
| `scripts/first_act_world.gd` | 地图与实体交互 |
| `scripts/first_act_battle.gd` | 回合制战斗 |
| `scripts/first_act_ui.gd` | 界面与触控 |
| `scripts/first_act_state.gd` | 进度和存档 |
| `data/first_act_side_quests.json` | 第一幕支线 |
| `story/` | 剧情源数据 |
| `data/content/` | 结构化设计数据库 |
| `assets/art/` | SVG/PNG 美术资源 |
| `docs/FIRST_ACT_DELIVERY.md` | 第一幕技术验收和说明 |
| `仓库与分支说明.md` | **分支含义和维护规则** |

**开发纪律：** 不再为每个小版本永久保留一个开发分支。需要复杂集成时使用临时分支，经过自动检查和验证合入 `main` 后结束使用；备份保持只读。参见 [Actions 自动检查](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions)。
