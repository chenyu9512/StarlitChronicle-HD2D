# C线 C2.3a · 第2章雾潮寄生体真实主战斗立绘动作驱动

提交基线 `40993416f9bf5a47fa7db0a595ba431fef11db11`。本批修正此前可能造成“Boss素材做完但场景不使用”的问题：第一幕单体Boss使用 `first_act_battle.gd` 的 `portrait`，而不是 `battle_enemies.gd` 中仅多敌场景可见的 `enemy_stage`。本批对正式 `portrait` 安装章节2专用 C23 动画控制节点。

## 实装
- **身份与尺寸保持**：不覆盖 B03 `ch002_fog_tide_parasite_battle_768.png` 或1254px原画；图像继续经 `ArtAssets.battle_image` 与 `CArtOverrides.texture` 解析。
- **本体真实图像形变**：新增 Godot CanvasItem shader，对正式B03纹理进行局部波动、攻击前伸、受击回缩、阶段涟漪和消散透明度改变；这是过程形变，不是高清原画独立重绘帧。
- **新绘多帧雾潮动效**：idle4、charge6、attack6、hit4、defeat6，合计5组/26张256px单帧透底SVG图块，绕原版立绘产生独立雾丝、聚潮、触须突击、碎裂和退潮运动。
- **战斗事件驱动**：首次真正挂入单体Boss立绘路径；敌方出手、受击、半血二阶段、战斗结算可直接触发。节点不修改HP、回合、职业、任务、存档或奖励事务；新增状态优先级避免战败后重新攻击。
- **可降级**：若有任何一组图集/Shader缺失、分辨率错误，或者用户已有专属材质，则原B03画像不被覆盖，不安装本体形变。不影响其它四位Boss以及多敌战斗原路径。尊重 reduced_motion。

## 未完工边界
- 本批是 **B03静态高清Boss纹理本体的真实局部变形 + 新绘雾潮动效**，**不是逐姿态重新绘制了B03完整高清本体**。未取得原画完整可视对照，不能承诺新雾丝与身体轮廓完美贴合。
- 战斗结束事件立即交给D线结算；`defeat` 动作是否能完整展现取决于A/D线战斗退出时机，本批没有更改安全结算路径。
- 新增 `tools/smoke_c23_b03_body_motion.gd`，当前只做SVG结构与代码连接静态检查，**Godot 4.7.2未实机运行**。

## 集中验收指令
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c23_b03_body_motion.gd
godot --headless --path . --script res://tools/smoke_c_b03_phase_overlays.gd
godot --headless --path . --script res://tools/smoke_a_line_live_bosses.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```
后续：1. Godot实测校正shader偏移、透底边界、材质优先级；2. 针对B03原画确认身份后才进行高清本体关节帧绘制；3. 将确认的rig抽象并推广至章节3—6，不允许五位Boss共用同一身份模板。
