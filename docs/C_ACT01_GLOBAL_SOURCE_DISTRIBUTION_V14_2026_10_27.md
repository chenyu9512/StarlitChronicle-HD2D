# 《星灯纪行》第一幕 · 2026-10-27 全局素材分配与运行接线 V14

执行分支：`Main2美术优化版`；本次**不修改 main**。所有新分配严格基于当前 GitHub 实际文件树，未上传的包不在分配完成数中。

## 实际成果

- 完整登记 `3534` 个已上传素材/元数据源文件，涵盖 `12` 个实有素材组；每个文件都记录 Git blob、体积、用途、章节优先级或后续储备状态，详见 `data/assets/c_act01_global_distribution_v14.json`。
- `45` 张精选第三方 PNG 通过**同一个 Git blob**创建可导入的运行路径，存于 `assets/art/runtime/act01_global_v14/`；原始目录 `assets/art/source_packs` 保持不动，不多次复制大图到不同地图。
- `scripts/first_act_world.gd`：第一幕现有 `10` 类正式世界道具优先取已核实来源，例如路牌 signpost、住宅 fisher-cottage、港口灯、鱼市、木桶、石井；精确压缩显示宽度和锚点，仍沿用原来世界交互坐标。
- `scripts/world_coastal_scene.gd`：`6` 类五地图现有手工摆设取得第三方实图；第六章灯塔使用 **Golden-Horizon lighthouse.png**，不是原先误映射的小纸灯笼。只更改视觉，不新增路、出入口、阻挡或可交互假门。
- `scripts/art_assets.gd`：第一幕 `9` 种普通怪物专用真 PNG 肖像可在实际战斗中按 `monster_id` 读取，不再只看通用占位。沿用原有动作/伤害/掉落系统；五个剧情 Boss 的对应静态候选**不直接覆盖 B03/已有阶段动画**。
- GH02 `5地图×2` 组真实地面/水面图片导入为**图集预览候选**，此批不把任意尺寸或非 32px UV 的大片源 PNG 塞进现有 8×8 TileSet；保护水体、阻挡、道路材质一致性和现有已验收的贴图层。
- 五张地图承载六章：第 1 章晨露村，第 2/4 章白砂港但故事房间不同，第 3 章断桅洞，第 5 章浅滩，第 6 章灯塔。两个章节复用港口地图不意味着复用相同剧情室内。

## 分配与真正成品的区别

V14 已实施实资源读取接线并提供 `tools/smoke_c_act01_global_art_v14.gd`，但本回合不具备 Godot 引擎执行结果。必须执行 4.7.2 headless 贴图导入和首次运行、截图逐图人工检查。

第 2 章独立收容所、第 4 章独立酒馆与第 5 章浅滩子场景仍需要完整的场景资产/触发/美术落地；大图贴图带有锚点与宽度约束但也需目视确定房屋比例、门洞与遮挡。静态 Boss 候选需对照角色剧情身份审美后才能替换；DragonBones ZIP 保留，未宣称 Godot 骨骼动画已运行。

校验：
`python tools/validate_c_act01_global_art_v14.py`
`godot --headless --path . --script res://tools/smoke_c_act01_global_art_v14.gd`
