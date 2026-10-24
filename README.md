# ⭐ 星灯纪行 / Starlit Chronicle

**当前完整游戏主体：[`main`](https://github.com/chenyu9512/StarlitChronicle-HD2D/tree/main)**  
Godot 4.7.2 · HD-2D 风格原创 RPG · iPhone 横屏优先 · 第一幕 v0.3 开发版

## ✅ 分支已精简：现在只有 3 条

| 分支 | 中文作用 | 应该用来做什么 |
|---|---|---|
| **`main`** | ⭐ **唯一完整游戏主体** | 下载、运行、修复Bug、整合正式代码与新资源 |
| `content/full-story-v1` | **剧情开发** | 编写/修改12幕72章的剧本、对白、任务文本 |
| `feature/content-foundation-v0-2` | **美术与数据开发** | 制作角色、怪物、地图素材、装备道具及内容数据库 |

**另外5条旧集成与备份分支已经删除。** 它们都没有 `main` 尚未包含的独立提交，因此无需继续保留分支。旧版本的回退锚点改为 Git 标签：

- `archive-v0.1.1-before-core`：v0.1.1 早期 Godot 原型。
- `archive-v0.2-before-first-act`：第一幕开发前的 v0.2 主体。

**以后不要再把旧功能分支当最新版。** 长期只维护这3条分支；临时功能分支在验证合并后清理。详细规范见 [《仓库与分支说明》（中文）](仓库与分支说明.md)。

## 游戏运行方式

```powershell
git clone -b main https://github.com/chenyu9512/StarlitChronicle-HD2D.git
```

Windows 上安装 Godot 4.7.2，选择导入仓库根目录 `project.godot`，等待资源导入，然后按 **F5**。

- 正式主体入口：`scenes/first_act.tscn`
- 历史原型场景仍保留于代码内：`scenes/main.tscn`
- 第一幕存档：`user://first_act_v3.json`；旧存档不会被覆盖
- 移动：WASD / 方向键 / 触屏方向控制；调查：E / 屏幕按钮
- 隐藏金手指：右上角星星4秒内连点5次，或按 F10，密码 `9169`

## 当前已接入的游戏内容

序章九场、第1—6章可移动关卡目标、六条三阶段地图支线、五场章节 Boss、剧情选项、角色成长与伙伴加入、商店、战斗、存档和横屏触屏界面。美术资源包含海岸地区 SVG、PNG、角色和怪物图片、图块与场景资料。

**注意：** 当前是第一幕已通过 Godot 自动化检查的游戏开发版，并非完成的72章商业游戏。专属正式关卡美术、完整音乐音效/动画、深度装备职业系统和 iPhone 真机发布验收仍需开发。

## 重要目录

| 位置 | 内容 |
|---|---|
| `scenes/first_act.tscn` | 当前游戏入口 |
| `scripts/first_act.gd` | 第一幕主流程 |
| `scripts/first_act_world.gd` | 地图与互动 |
| `scripts/first_act_battle.gd` | 战斗系统 |
| `scripts/first_act_ui.gd` | 界面与触屏 |
| `scripts/first_act_state.gd` | 状态与存档 |
| `story/` | 剧情内容 |
| `data/content/` | 资源数据库 |
| `assets/art/` | 原创 SVG / PNG 素材 |
| `docs/FIRST_ACT_DELIVERY.md` | 第一幕交付说明 |
| `仓库与分支说明.md` | 分支职责与回退规则 |

游戏主体与 GameLingoAI 项目互相独立。
