# 星灯纪行 · 0.1.0 技术架构

## 模块关系

```
project.godot
    │ autoload
    ▼
State (game_state.gd) ─── user://starlit_save_v1.json
    │              ┌──────────────────┐
    ▼              │ game.gd (流程协调) │
Game ◄─────────────┴──────────────────┘
    ├── World (world.gd) ── map.json + map.png
    │    ├── Ground / YSortedWorld
    │    ├── Hero / Companion (actor.gd)
    │    ├── Props / Glow
    │    └── Camera2D
    ├── GameUI (game_ui.gd) ── D-pad, HUD, Dialogue, Menu
    └── Battle (battle.gd) ── 随机敌人 / Boss / 行动决策
```

## 基本流程

- 探索：`game.gd` 允许移动 → `world.gd` 获取键盘或触屏方向 → 检查瓦片和物件碰撞 → 玩家和同伴移动，摄像机追随。
- 交互：触屏按键/E → 搜索 64 px 内最近可交互物件 → 世界发射 `interaction_requested(kind, payload)` → Game 执行 NPC 任务、商店购买、回复、宝箱或场景切换。
- 遭遇：遗迹累计移动距离达到阈值 → `encounter_requested` → 游戏锁定移动，添加 Battle CanvasLayer。
- 战斗：两名队友依次选择行动 → 敌方回合 → 结算胜负及 HP/MP → Game 应用经验、金币、任务进度及复活。
- 存档：`game_state.gd` 将版本号、地图位置、任务状态、已开宝箱、金币药草和队友能力写入 `user://` JSON；首次启动优先读档，找不到则新开。

## 模块边界约束

- World 不直接修改游戏金币、Boss 奖励、任务阶段；只通过事件通知 Game。
- Game 不直接画地图、按钮或战斗插画。
- Battle 只修改战斗资源（HP/MP/道具），用 `finished` 向 Game 汇报战斗结果；实际奖励在 Game/State 中结算。
- State 唯一负责持久化，尽量保持存档格式可以迁移。
- 美术工具仅用于离线资源生成，游戏运行时不需要 Python/Pillow。

## 0.2 优先级

1. 在 Windows Godot 4.7.2 完成 Play / 调整界面和键盘；在 Codemagic 完成一次无签名 iOS 编译并收集实际日志。
2. 添加 Apple `safe_area` 适配、模拟摇杆和触摸目标调大；实现多机型屏幕缩放测试。
3. 将地图物件转换为资源驱动/场景化 TileMapLayer 管线，调整 2D 光照/前后景深度；提升为真正的 HD-2D 美术。
4. 补战斗反馈：动画、音效、目标选择、buff/debuff，战斗胜负反馈延迟。
5. 增加完整背包、装备、职业/技能、多个存档槽、中文/日文、本机性能日志。
6. 启动商业发布分支，再接入签名、隐私说明、数据备份、TestFlight 和 App Store 流程。

## 测试状态

`python tools/validate_project.py` 在生成环境已通过：地图交互可达、图片尺寸、JSON、YAML、脚本资源路径检查。此工具**不能替代 Godot 解释器、Xcode 构建或 iPhone 实机性能测试**。
