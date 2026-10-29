# C 线 · Librarium 四素材组分配与运行适配（2026-10-27）

真实数据来源：GitHub main 的 assets/art/source_packs 原始目录。共核对 179 个文件：**174 个美术/动画素材 + 5 个说明或条款文件**。
一对一登记见 `data/assets/librarium_assignments_v1.json`；153 个身份（地图怪物 42 / DragonBones 72 / MV 39），141 个现有游戏目标（地区敌人 63 / 剧情 Boss 66 / 幕 Boss 12），所有 174 个实体资源都具备 target_id。自动分配不等于视觉验收，低相似度或 ZIP 仅作候选。

## 运行部分
- 三帧怪物图 42 PNG：保留原始文件，在 `assets/art/external/librarium_runtime/map` 添加 42 个可导入别名并提供 `LibrariumArt.map_preview(content_id)`。并**未**修改野外刷怪、地图道路和碰撞；后续由 B 线按剧情场景、占位格和朝向审核后放置。
- MV 战斗图 39 个身份：13 个 ZIP 必须解包，26 个有 PNG 的身份建立 26 张运行主图；另 21 PNG 外观变体只登记原档。配置 21 个候选中视觉语义较明确的游戏槽位，经 Godot 校验图片为 9×6 帧布局后，7 章及之后由 `BattleEnemies` 展示待机、受击、攻击和死亡帧。其余先候选，不强行错配。
- DragonBones 72 ZIP：分配到精英/Boss 素材槽位，但无 Godot 原生骨骼动画转换，**没有完成实际播放**。任何 ZIP 都没有被指作可以直接运行的贴图。
- Static Battlers：**仓库中尚无实体文件**，实际存放位置尚未确认；不能声称静态怪物素材已被分配。

## 兼容与验收
`assets/art/source_packs/.gdignore` 会阻止原档作为游戏导入资源；可运行图保留独立相同 Git SHA 的路径。优先保留第一幕 B03 Boss 与现有海岸怪物动作，未修改敌人机制/掉落/存档和剧情。对于缺失或非 9×6 的图片，保持原有资源回退。

当前**已完成全量登记与有限运行接入，不是四组商业级完整美术验收**。仍需在 Godot 4.7.2 中执行导入、首幕与后续战斗视觉截图、地图站位测试；等 85 个 ZIP 转换和 Static 文件补齐后再升级状态。
