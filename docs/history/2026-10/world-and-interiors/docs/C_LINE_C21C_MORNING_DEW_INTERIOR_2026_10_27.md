# C线 Batch C2.1c — 晨露村六间真实室内美术识别层

**基线：** `6e20133885558e240ecb4ebbbb169f9ed30102c9`（本批仅以租约安全方式更新 main）

## 本批实装

- 新增 `assets/art/interiors/morning_dew_signature/` 原创SVG **12张**（每间1张96×64 地面织毯/金属/盐蚀/祈祷纹饰 + 1张64×64 壁挂识别装饰）。旅馆罗盘、住宅潮纹织毯、商店货物纹章、公会航海路线图、铁匠铺炉格与祠堂潮星印章，各自独立绘制，而非统一面板换色。
- `data/assets/c_morning_dew_signature.json` 记录6个场景各2个落点、素材路径、绘制层级和验收状态。
- `scripts/world_interior_art.gd` 在 V4 正式室内生成后读取 C 清单，仅在晨露村六种房间叠加对应 SVG；地面贴画必须位于真实可通行地表、中心及相邻四格无阻挡，且不修改 `tiles`、`blocked`、交互/存档及任务 ID。壁挂位于原墙面显示层，独立于交互点。
- 一并修正 C 室内音景识别：当 V4 返回`layout_id`而没有独立`map_id/building_id`时，从 `map_coast_01#shop` 等稳定 ID 解析对应室内类型，避免无条件播放旅馆音景。
- `tools/smoke_c_dew_signatures.gd`：需要在 Godot 4.7.2 实跑的六间房12项贴画、纹理导入、落点与碰撞不变验证。

## 静态审查

- 6间 V4 原始房间的 `floor_regions / solid_regions / door_regions / art_collision_cells` 已用于核对全部6处地面贴画中心与相邻四格均可通行，未占据spawn/service/exit/storage。
- SVG 尺寸、XML标签和12份唯一文件名已在写入前进行静态校验。
- **未执行 Godot 或实机截图。** 不能把代码存在宣称为已验收的高清商业美术。若纹理导入不成功、房间叠层不美观或影响玩家识别，须通过实机证据修复。

## 后续集中测试
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_dew_signatures.gd
godot --headless --path . --script res://tools/smoke_coastal_interiors.gd
godot --headless --path . --script res://tools/smoke_c_town_presentation.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```
玩家验收路线：晨露村依次进入旅馆、住宅、商店、公会、铁匠铺、祠堂；观察室内远近遮挡/光源、六处识别图是否为实际绘制、对话交互、室内返回和存档重载。

## 后续
C2.1d优先怪物真实动作和B03 Boss战斗状态分帧。B02仍是静态立绘，不能假称为独立动作。
