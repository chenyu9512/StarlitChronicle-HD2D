# C线 Batch C2.1a · 晨露村场景真实美术首批

基线 main commit: `30e88462e5bad741e7d9c15e1a76e842092b657a`
范围：map_coast_01（晨露村）路面物理材质层与六栋实体外观SVG精修；无 UI 换肤、无战斗/任务/存档修改。

## 实际资源
- `assets/art/exteriors/coast_final_pass/dew_road_material_8x8.svg`：原创程序辅助绘制的 256×256、8列×8行、每格32×32透明石纹/盐蚀/苔痕图集，全部64个变化单元，保留原始可编辑SVG；没有改写既有地表瓦片。
- `map_coast_01_{inn,house,shop,smith,shrine,guild}.svg`：在原建筑立绘上增加对应身份的独立门面细节（旅馆潮灯/柜布、住宅盆栽、商店遮阳篷/货箱、铁匠铺锻炉标记、祠堂潮纹挂幡、公会告示地图），共有的屋瓦盐迹/墙脚纹理只做透明细化；256×192、原始房门和阴影坐标不变。
- `scripts/c_coastal_painter.gd`：晨露村正式`OriginalCoastalDressing`之下新增`OriginalDewRoadStone` TileMapLayer，仅读取正式地图`tiles`行3中未阻挡、非水格的道路，约87%随机留白/叠加，严格维持32像素地图网格。保留白砂港原渲染，不改其他地图。
- `tools/smoke_c_coastal_render.gd`：新增道路层、最低铺设数量、实际使用单元数、路面类型/碰撞/水体只读以及白砂港不泄漏检查。

## 状态区分
- 原创SVG资产：已生成，并通过仓库路径静态对应；仍待观察真实游戏画面。
- 正式运行代码：已接入已有的`world_coastal_scene.gd`调用链；为**静态接入**，并非 Godot 实跑。
- 本轮没有改变 `walk_4dir_3frames.png` 与 `B02`/ `B03`（仅改SVG不足以完成PNG角色动画）；尚需独立精修/逐帧输出。
- 实机质量：**UNVERIFIED**。没有运行 Godot 4.7.2，不声称零编译问题或商业画质通过。
- 许可：新增图集为本次原创程序辅助绘制图像，不含外部下载素材；仍需最终发布审查。

## 必须在 Godot 环境执行
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_coastal_render.gd
godot --headless --path . --script res://tools/smoke_town_entrances.gd
godot --headless --path . --script res://tools/smoke_c_town_presentation.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```
人工截图验收：晨露村入口→石径→旅馆与六建筑近景（昼/夜）→建筑门前交互→室内返回，重点观察地图遮挡、脚底层次、32像素地面接缝。

## 迭代后续
C2.1b：四名主角PNG图集逐帧外观重绘（3×4）；B02人物表情/ NPC生活帧；道路与室内的实景截图复核。C2.1c：海岸怪物和B03老板攻击/受击/死亡动作帧，不将静态立绘缩放当作帧动画。
