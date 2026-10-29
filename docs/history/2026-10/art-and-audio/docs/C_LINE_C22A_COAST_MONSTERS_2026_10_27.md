# C线 Batch C2.2a · 海岸四种怪物动作扩展

基线：`901ec887835016d57835e3df182e94fd2bd7634f`。直接添加到真实战斗 `battle_enemies.gd` 已使用的 `c_coast_monster_motion.gd` 配置，通过原本的独立动作图集状态机驱动，**不修改A线任何战斗结算或回合逻辑**。

新增四种：雾蟹（双螯/六足）、寄壳者（螺旋壳、眼柄与蟹螯）、砂蜥（尾巴、四足与咬击）、盐狼（四足毛皮/耳朵与咬击）。每种待机4 + 攻击6 + 受击4 + 战败6 = 20真实几何变化帧，总计80帧。128x128透明SVG图集，旧B01素材不覆盖；其它种按原B01回退。已有盐史莱姆20帧，当前合计五种100帧。

**现有测试迁移：** 旧烟雾测试中“fog_crab尚不存在”的断言更换为不存在的怪物ID；新增五种真实纹理尺寸/帧差与战斗状态绑定烟雾脚本。

**真实测试状态：** 本次仅静态校验SVG完整标签、方向差异与资源清单，**没有启动Godot**。未完成另外四种怪物和B03 Boss图集。当前战斗舞台的视觉缩放/配色与原B01静态图匹配，需要实机截图验收。

集中测试：
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_coast_monster_motion.gd
godot --headless --path . --script res://tools/smoke_c_coast_monster_matrix.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```
