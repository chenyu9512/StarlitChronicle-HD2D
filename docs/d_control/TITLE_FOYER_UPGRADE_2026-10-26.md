# 《星灯纪行》D线：首页从按钮堆叠升级为星灯旅途大厅

开发日期：2026-10-26。现有首页源：`scripts/first_act_ui.gd`；新独立页面：`scripts/d_title_screen.gd`。本次仅在共享UI插入一个D线入口、完整保留C线美术替换工具与原有 `started(bool)` 信号；不碰A/B/C的战斗、剧情及美术素材。

## 原版问题
开机直接叠灯塔背景与三枚功能按钮，没有进入节奏、故事动机或更广的首页功能。新游戏直接覆盖自动存档且无二次确认。

## 改造内容
- **第一屏：星灯降临**：保留可替换灯塔背景，增加动态星群、分层深色遮罩、主标题、副标题、世界观引子和唯一“触碰星光”入口。首次进入先出现氛围画面，非立即弹出功能清单。移动设备可触屏；桌面可以Enter/Space/任意按键进入。
- **第二屏：旅途大厅**：新篇、继续、美术工坊为真实按钮，额外有世界序章、旅程档案、操作指南、视听设置四个信息页。延时淡入，降低动态效果时不做入场动画。
- **存档安全**：继续沿用 `first_act.gd::_start(continue_game)` 失败留档逻辑；首页仅只读预览V3自动档或备份的章节与金币；真正继续仍由V3存档校验。拥有旧档时创建新游戏必须显示二次确认，而不是误触立即覆盖。
- **C线保留**：原 `c_art_manager_ui.gd` 和 `c_art_overrides.gd` 保持原样，首页灯塔贴图依然可更换且立即刷新；标题使用原C线 `c_town_soundscape.gd` 的海岸氛围音路由。
- **本地偏好**：标题页可开关星光动效、开场氛围音，保存于 `user://starlit_title_preferences.cfg`，不写入剧情/角色存档。仅影响标题演出，不虚称为全游戏设置。

## 兼容与操作
1. `first_act_ui.gd::_build_title()` 创建DTitleScreen并保留 `title_overlay/title_illustration/title_continue/title_status/art_manager` 既有属性；对外仍然 emit `started(bool)`。
2. `show_title(has_save,status)` 调用DTitleScreen.configure；继续失败再次回到标题时直接打开大厅，错误提示可见。
3. 原有开始游戏、HUD、战斗、菜单、章节剧情和C美术管理器代码不重写；存档文件不迁移。
4. C音乐通过 `Soundscape.configure` 开启，按进入游戏时 `stop_scene` 淡出；如果设备无法建立音源，Godot日志仍需现场检查。
5. 标题通过键盘与触摸交互，测试脚本不加载真实玩家游戏进度，不删除任何存档。

## 回归测试
待运行：
`godot --headless --path . --script res://tools/d_control/smoke_title_foyer.gd`

主要断言：首次开机菜单隐藏；点击后开启大厅；无存档禁用继续；继续/新游戏信号兼容；存档存在时新游戏先弹确认；操作指南与档案真实可用；C线美术工坊对象保留。

> 本次通过GitHub代码静态核对及文件存在检查，没有本地Godot 4.7.2。新标题尚未经引擎加载、实际分辨率布局、iPhone触摸、音频和美术替换运行验证；一律标注 **待统一Godot验收**。旧版Actions成功记录不代表此提交通过。
