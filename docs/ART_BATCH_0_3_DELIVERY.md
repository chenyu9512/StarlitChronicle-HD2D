# 星灯纪行｜Batch 0–3 实际交付
所有资源为原创、结构化的矢量像素风原稿。正式可用PNG由 `tools/export_hd2d_svg.py` 生成；源稿与PNG按同名配对。
|批次|内容|原稿图片数|
|---|---|---:|
|0|色板、尺寸示意|2|
|1|黎昂、岚音、澄舟、朔弦各8项|32|
|2|4张地图图块图集 + 20项环境道具 + 4幅场景背景|28|
|3|白砂海岸9只魔物，每只战斗透明立绘/图鉴图/待机4帧表|27|
|合计|可编辑源图以及相同数量PNG导出目标|89|
**注意：** 行走表和待机表各自计作1张图片文件，而不是按帧数拆分；后续动画/碰撞/地图场景实现仍需另行开发。
## 与已有数据库关联
- 角色4人使用 `char_wayfarer`、`char_tidecaller`、`char_chengzhou`、`char_seeker`。
- 地形资源属于 `region_coast`，正典中晨露村、白砂港及潮歌灯塔仍需要可行走 TileMapLayer、碰撞和传送逻辑。
- 魔物使用 `mon_coast_01` 到 `mon_coast_09`。
- 本资源包路径为 `assets/art`；**旧版两张地图及原始PNG不作覆盖**。
## 操作
```bash
python -m pip install cairosvg pillow
python tools/validate_hd2d_art.py
python tools/export_hd2d_svg.py
python tools/validate_hd2d_art.py --check-png
```
需在 Godot 4 中做资源导入测试、实际地图展示、触屏与帧率测试。若美术精修，需要在不修改稳定 ID、规格、manifest 的前提下替换源图。
