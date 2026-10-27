# C线 Batch C2.2c — B03五场Boss分章专属第二阶段视觉叠层

基线`dd6f53472a03b7dbed4a716cafa11cdf0f72b933`，只扩展 C专属绘画资源和已存在A16 `battle_boss_awakening.gd` 的**材质选择**，不修改Boss HP、转阶段触发、胜利、奖励或存档机制。

新增5幅192px×6帧独立SVG图集，合计30个分章专属动画视觉帧：第2章雾潮寄生体专属雾丝/孢子，第3章潮痕守卫符文与海阵，第4章灰帷水手交错帆刃，第5章缚潮古兽星链，第6章潮歌守门人谐波/潮星环。正式A16的`awaken()`照旧由A线第二阶段事件调用，仅选择匹配章节的C原画，如果文件丢失或尺寸不符则回退原A16通用六帧动画。

**严格区别：** B03五张正式高清Boss PNG未被替换，Boss **本体仍是静态绘画**。新增的是每位Boss专属六帧第二阶段“动态叠层”，不等于已画出Boss自身的蓄力、攻击、受击、阶段变化造型、战败肢体动画。禁止标记Boss本体动画完成。

测试：新增`tools/smoke_c_b03_phase_overlays.gd`检查5种专属纹理导入尺寸、同章帧差、分章区别、六帧播放与停止。SVG基础结构作者静态检查成功；**Godot实机尚未运行**。

集中回归：
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_b03_phase_overlays.gd
godot --headless --path . --script res://tools/smoke_a_line_live_bosses.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```
