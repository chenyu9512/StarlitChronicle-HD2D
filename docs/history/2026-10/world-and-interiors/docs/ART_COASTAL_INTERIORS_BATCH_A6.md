# 星灯纪行：海岸室内美术批量扩展 A6

## 已接入
- 两城共12个物理独立室内：既有晨露村旅人客栈，加上晨露村5间和白砂港6间独立制作的商铺、公会、工房、民居、祈灯祠与旅店。
- 新增11套独立的8×8 32px室内图集，12件职业特色家具可编辑SVG，路径：`assets/art/interiors/coastal_district/`。
- 11张原有V4室内地图按房屋类型绑定 `art_profile`/`art_tileset`/`visuals`/`art_collision_cells`/`light_sources`。原布局、主线事件、NPC存档及交互ID均保留。
- 复用原客栈`world_interior_art.gd`的家具Y排序、墙体遮光、昼夜光影及特定火焰动画；扩展`first_act_world.gd`支持每房间自有图集。
- 自动化验收`tools/smoke_coastal_interiors.gd`实际进入/退出12间房屋，校验不同图集、摆设纹理、可达性、灯光、阴影、旧交互与返回街道位置。

## 质量限制
正式游戏运行时美术已经接线，但以上为原创矢量像素制作稿，尚未经过逐像素艺术精修、iPhone/Windows人工画面检查及最终音频验收；不能称已达到参考图级别的商用美术终稿。其他地区保留旧图集和存档兼容路径。
