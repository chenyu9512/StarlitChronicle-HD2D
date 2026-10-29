# C线 Batch C2.1d — 盐史莱姆真实动作样板

基线主分支 SHA：`3f58fd304497685cd1d82a9654cfde6febc8f6c2`。

本批只选择海岸9怪物的 **1种**（salt_slime）。新增4套原创128px单帧动作图集：待机4帧、攻击6帧、受击4帧、战败6帧（合计20个有不同身体轮廓、眼睛、结晶与动作位置的独立帧，不是单张图片整体旋转或简单缩放）。图集为可编辑 SVG，原始B01 PNG和含内嵌PNG的兼容SVG一律保留。风格与既有PNG仍需正式游戏画面比对。

`scripts/c_coast_monster_motion.gd` 负责单体动作图集齐全性与尺寸校验，4套若缺任意一套则 **整体安全回退** 原 idle PNG 和原战斗显示路径，不会出现不同体态混用。`scripts/battle_enemies.gd` 仅改变战斗表现层：优先选择 salt_slime 新图集并按原有攻/受击/战败表现倒计时选择不同真正绘制姿态；不修改战斗数值、回合、敌人ID、掉落、剧情或事务。

`tools/smoke_c_coast_monster_motion.gd` 已提交但 **Godot 4.7.2 未执行**；应测试SVG导入、20帧首尾不同、4状态切换、未完成怪物回退以及普通战斗结束。其它8怪物与B03 Boss本批未制作，不得标记完成。

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_coast_monster_motion.gd
godot --headless --path . --script res://tools/smoke_a_line_live_bosses.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```

**测试记录：** SVG帧数/标签结构静态验证成功；Godot运行未测试；真实截图/性能/视觉风格验收未测试。技术样板不等于商业级定稿。
