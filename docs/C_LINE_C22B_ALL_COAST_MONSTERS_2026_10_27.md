# C线 Batch C2.2b · 海岸全部9类敌人动作视觉稿

基线 `085ae24817e7f1f07fe84a86b6ef9132719c1e5e`，继续直接提交main，不创建分支/PR，使用旧图集整套回退机制。

新绘制四种：白海鸟（双翼扑击、俯冲喙）、星鳐（鳐翼、潮星纹、尾刺）、潮汐幽灵（透明灵体、游丝与潮刺）、潮痕守卫类普通怪（盔甲、海蚀盾、三叉戟）。每种有待机4、攻击6、受击4、战败6张独立造型变化，128px贴图元件，总计新增16套SVG图集/80个动作帧。配合先前盐史莱姆、雾蟹、寄壳者、砂蜥和盐狼，当前已为9个海岸普通怪新增**36份动作图集/180个动作帧**。

接入既有 `c_coast_monster_motion.gd` 配置，实现自动以4套图集整体导入、按攻击与受击计时状态播放（无更改伤害、掉落、敌人ID和存档接口）。在 `tools/smoke_c_coast_monster_matrix.gd` 扩展9种怪物的图像尺寸、首尾帧差异、攻击/受击/战败绑定检查。更新 `data/assets/c_coast_monster_motion.json` 资产台账。

**质量区分：** 这是首次覆盖完整海岸九敌人的原创SVG**可运行候选**，不是逐一人工打磨验收后的最终商业原画，且绘制身份未与原B01逐像素对齐；不覆盖原PNG，保留整套回退。静态结构检查成功，未运行Godot 4.7.2和完整战斗，不得将“9种接入”叙述成“9种实机验收合格”。

集中验收：
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_coast_monster_motion.gd
godot --headless --path . --script res://tools/smoke_c_coast_monster_matrix.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```

下一步 B03：5场剧情Boss（章节2—6）的B03本体仍是单帧正式立绘，既有boss_awakening_6f是通用觉醒特效。须独立审核动作方案、阶段转换事件与真实画质，不得将通用滤镜效果计为Boss本体20帧。
