# C线 Batch C2.1b — 四名主角独立逐帧行走素材
基线 `12696a05241cd97341d53fe916552321e2b4eec6`；新增黎昂、岚音、朔弦、承舟四份原创透明 SVG，96×192，每帧32×48，3列×4行、依次向下/左/上/右。每帧独立绘制靴子迈步、衣服/手臂位移，左右侧脸按镜像方向渲染，背面不画正面五官；不同角色保留旧图集的发色、衣装轮廓色与饰件色。

正式加载器 `scripts/first_act_actor.gd` 优先选择同目录的 `walk_4dir_3frames_c21.svg`，前提是对应 PNG 未被用户本机替换并且 SVG 纹理导入尺寸仍为96×192；否则继续使用原 PNG。无需更改 D 世界角色选择、故事ID、碰撞或存档。

增加 `tools/smoke_c_character_motion.gd` 的四人尺寸和逐帧视觉差异检测。 **没有执行 Godot 4.7.2 / 真机截图；是否达到视觉质量目标待验收。** 静态 SVG 实际方向与步态不同，但不是8方向独立原画，也不冒充B02高清重绘。

建议集中验证：
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_character_motion.gd
godot --headless --path . --script res://tools/smoke_c_coastal_render.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```
正式画面需核查四个主角的原始比例、四方向/斜向、脚底锚点、遮挡层、步态衔接与B02身份一致性。