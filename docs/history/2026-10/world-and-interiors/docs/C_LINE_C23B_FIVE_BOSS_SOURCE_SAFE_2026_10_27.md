# C线 C2.3b — 第3—6章B03本体安全变形与动作叠层

基线 main `cb550c8236f1fbcce09eca2a05d405c3b0f4fcbc`。目标：让此前B03静态高清图在正式单体Boss路径中有独立战斗反应，并继续保留A16五场Boss的阶段特效及D线奖励/存档边界。

- **第3章潮痕守卫**：原PNG原样保留，防御石板/潮阵/冲刺符枪动态叠层，轻量甲胄变形。
- **第4章灰帷水手**：原PNG保留，帆布、系绳及帆刃斩击动态叠层，方向性上身冲刺。
- **第5章缚潮古兽**：原PNG保留，星锁震动、断链释放动画，结算时不会使原画整体消失（剧情非致死）。
- **第6章潮歌守门人**：原PNG保留，潮汐谐波、拱形冲击与星音浮光动态叠层。

每章5种状态（待机4/蓄力6/攻击6/受击4/终止6）合计26帧，4章合计**20套原生SVG图集/104帧**。这都是新绘制**外部动态图形**而非重绘B03 768/1254高清本体。

工程：原章节2 `c_b03_fog_tide_body_motion.gd` 作为共用动作状态、优先级与二阶段延迟队列；子类 `c_b03_other_boss_motion.gd` 指定各章专用素材目录、Shader风格和色调；`first_act_battle.gd` 真正为第2—6章 Boss 在原单体 `portrait` 创建对应Rig（多敌保持原A显示路径）。另外补全正式意图预警触发的`play_charge()`。战斗结算、Boss生命与阶段判定均无修改。

**质量/测试边界**：本批可核实文件结构、帧数及静态引用；Godot4.7.2资源导入、各章视觉身份和完整战斗未在当前连接器里执行。旧的B03原画不可通过连接器取得可视预览，因此四章外部动效的绝对贴合须待截图人工验收，不作商业级定稿宣称。

## 建议集中验收
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c23_b03_body_motion.gd
godot --headless --path . --script res://tools/smoke_c23_b03_other_bosses.gd
godot --headless --path . --script res://tools/smoke_c23_b03_5boss_bundle.gd
godot --headless --path . --script res://tools/smoke_c_b03_phase_overlays.gd
godot --headless --path . --script res://tools/smoke_a_line_live_bosses.gd
```
