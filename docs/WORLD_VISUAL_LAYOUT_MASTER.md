# 《星灯纪行》全游戏视觉与布局总控（Main2）

> 状态：**正式 UI 代码已接入；本文件为 42 地图差异化制作约束，不代表所有地图的美术已绘制/实机验收。**
> 正典来源：`data/content/maps.json` 与 `data/levels/world_atlas_v2.json`。Godot 4.7.2 / 高清2D / 横屏手机优先。
> 上传的 HD-2D 脚本仅用于参考 SVG 证物和法线烘焙思路；不得用统一 32×32 占位角色或四格纹理替换正式素材。

## 1. 全游戏空间与美术层级

**视觉深度**：地貌材质（Ground）→ 环境建筑（Midground）→ 人物/NPC（Y-sort）→ 不遮挡交互点的布景（Foreground）→ 天候/时序光影 → HUD/对话/地图。地图物件可达性由现有碰撞与出生点数据掌控，布景不得擅自引入物理阻挡。

**全局界面**：标题引导 → 主游玩 HUD（任务左/小地图右/队伍状态右中）→ 场景对白（下部浮层）→ 冒险手册（分组横向导航）→ 局部/地区/世界地图 → 回合战斗（上部敌方视觉焦点/下部双排指令）→ 正典物证特写。12幕颜色只作为小范围材质点缀，正文始终保证可读性；不把颜色当作唯一提示方式。

**场景唯一性**：42地图包含正式世界、群灯城和旧试玩兼容节点。每张图必须在地标、可走路线、建筑组合、室内出口、NPC聚集、地图缩放和镜头取景上有差异；不得仅换色复制。正式地图具有专属场景时，优先保留 V3 场景与现有真实美术。

## 2. 8大地区材质语言

| 地区 | 视觉主调 | 地图规划重点 |
|---|---|---|
| 白砂海岸 | 海玻璃青 × 风化木 | 步行线路优先于纯装饰与大面积空地 |
| 三誓高地 | 磨砂金 × 高山石 | 步行线路优先于纯装饰与大面积空地 |
| 赤炉工业带 | 温铜 × 铁灰 | 步行线路优先于纯装饰与大面积空地 |
| 群岛航路 | 深海蓝 × 珊瑚米 | 步行线路优先于纯装饰与大面积空地 |
| 映世 | 镜紫 × 低饱和绿 | 步行线路优先于纯装饰与大面积空地 |
| 旧洲 | 灰土 × 旧银 | 步行线路优先于纯装饰与大面积空地 |
| 天轨圣域 | 星银蓝 × 象牙白 | 步行线路优先于纯装饰与大面积空地 |
| 群灯之城 | 旧纸白 × 工业青 | 步行线路优先于纯装饰与大面积空地 |

## 3. 42 个真实地图节点差异化构图

下表“构图重点”属于后续美术/布局验收约束，**不宣称已在地图中完成实装**。原仓库区位、地图ID、正式/兼容类型保持不变。

| 地图ID | 地点 | 类型 / 地貌 | 独立构图重点 |
|---|---|---|---|
| `map_coast_01` | 晨露村（正式版规划） | town / coastal | 旧屋—村心星灯—海岸小路；曲线巷道与矮墙 |
| `map_coast_02` | 白砂港 | field / coastal | 港口吊机—仓库步道—海岸线；纵向码头节奏 |
| `map_coast_03` | 盐风古道 | route / coastal | 风蚀古道—潮痕断面—远眺港口；斜向引导 |
| `map_coast_04` | 潮声洞窟 | dungeon / coastal | 潮水洞室—齿轮遗迹—安全回路；前后层洞口 |
| `map_coast_05` | 潮歌灯塔 | landmark / coastal | 灯塔基座—旋梯—高处灯室；纵深轴线 |
| `map_oaths_01` | 三誓门城 | town / highland | 三重城门—层级街道—城心；台地式层次 |
| `map_oaths_02` | 断誓山径 | field / highland | 断誓石—山腰折线—避风平台；上下高差 |
| `map_oaths_03` | 银鹫要塞 | route / highland | 要塞城墙—瞭望塔—狭窄哨道；防线纵深 |
| `map_oaths_04` | 誓石神殿 | dungeon / highland | 誓石祭坛—分叉证词道—回环密室；多门楔形 |
| `map_oaths_05` | 旧王谒见厅 | landmark / highland | 旧王座—空置观礼席—证物台；仪式对称 |
| `map_forge_01` | 熔炉港 | town / volcanic | 熔炉烟囱—工人码头—冷却渠；工业天际线 |
| `map_forge_02` | 烟塔工坊 | field / volcanic | 工作台—管线桥—工匠街角；设备近景 |
| `map_forge_03` | 赤砂矿坑 | route / volcanic | 采掘平台—矿轨—防护支架；高低错层 |
| `map_forge_04` | 灰烬铁路 | dungeon / volcanic | 道岔—废弃车厢—安全维护通道；铁路透视 |
| `map_forge_05` | 炉心禁区 | landmark / volcanic | 主炉—四阀供电—医疗疏散路；危险与安全区分 |
| `map_isles_01` | 珊歌港 | town / archipelago | 港湾圆环—灯船—珊瑚街巷；弧线通路 |
| `map_isles_02` | 五色环礁 | field / archipelago | 五色礁盘—潮池—连接浅滩；彩层地貌 |
| `map_isles_03` | 风暴航道 | route / archipelago | 风暴航路—避险岛—导航灯；S形阅读节奏 |
| `map_isles_04` | 深潮神庙 | dungeon / archipelago | 深潮柱廊—回流池—古碑；潮汐对称 |
| `map_isles_05` | 沉没王座 | landmark / archipelago | 沉没台座—珊瑚阶梯—断裂王座；水下光束 |
| `map_mirror_01` | 镜湖都 | town / mistforest | 镜湖倒影—日轮街—塔楼；上下镜像 |
| `map_mirror_02` | 夜镜森林 | field / mistforest | 夜镜树冠—隐蔽林间道—静水；压低明度 |
| `map_mirror_03` | 忘梦庭院 | route / mistforest | 梦庭入口—双向回廊—退出之门；对称破缺 |
| `map_mirror_04` | 银玻璃塔 | dungeon / mistforest | 玻璃桥—塔心装置—镜面竖井；冷暖反差 |
| `map_mirror_05` | 映世回廊 | landmark / mistforest | 反射门—真实退出道—旧记忆石板；视觉透层 |
| `map_oldland_01` | 遗民营地 | town / badlands | 遗民帐篷—公共井—物资台；人道主义尺度 |
| `map_oldland_02` | 荒星平原 | field / badlands | 荒原孤灯—旧轨迹—地平线；大留白 |
| `map_oldland_03` | 时裂峡谷 | route / badlands | 裂谷栈道—时间缝隙—回程锚点；曲折险径 |
| `map_oldland_04` | 星墓秘殿 | dungeon / badlands | 星墓门廊—纪念碑—证词分岔；肃穆低饱和 |
| `map_oldland_05` | 旧日灯枢 | landmark / badlands | 旧灯枢—崩裂齿轮—接续节点；工业遗迹 |
| `map_sanctum_01` | 天轨前庭 | town / celestial | 天轨前庭—星梯—穹顶；垂直聚焦 |
| `map_sanctum_02` | 七灯环庭 | field / celestial | 七灯环庭—七个席位—共同轴心；环形秩序 |
| `map_sanctum_03` | 反转星穹 | route / celestial | 反转星穹—安全踏道—透明天桥；悬空透视 |
| `map_sanctum_04` | 岁影尽头 | dungeon / celestial | 岁影边界—双时钟—归途；层叠记忆 |
| `map_sanctum_05` | 永昼祭坛 | landmark / celestial | 永昼坛心—居民环席—选择出口；晨曦余辉 |
| `map_legacy_village` | 晨露村（旧版试玩） | prototype / coastal | 仅旧试玩相容，禁止覆盖正式晨露村布局 |
| `map_legacy_ruins` | 星落遗迹（旧版试玩） | prototype / coastal | 仅旧试玩相容，保留历史存档入口但不参与正式关卡风格验收 |
| `map_city_01` | 群灯旧会馆 | town / metropolis | 旧会馆前厅—公开账本—公共委托栏；秩序复建 |
| `map_city_02` | 自由议事厅 | town / metropolis | 议事台—志愿席—公开通道；民意视线 |
| `map_city_03` | 群灯居民街 | town / metropolis | 居民街—庭院儿童—修缮立面；生活温度 |
| `map_city_04` | 星灯中枢 | dungeon / metropolis | 星灯节点—备份路由—故障隔离区；分布供能 |
| `map_city_05` | 西区修复工地 | route / metropolis | 西区房屋—临住协议公告—安全工地环带；低矮住宅 |

## 4. 本批接入范围与防退化条件

- **已改代码**：`scripts/c_visual_design.gd`、`scripts/first_act_ui.gd`、`scripts/rpg_menu.gd`、`scripts/first_act_battle.gd`、`scripts/map_hud.gd`、`scripts/d_title_screen.gd` 与 `scripts/first_act.gd`。统一窄边金属 UI、横屏响应式布局、地区/幕色与正式证物调查展示；不改变任务、Boss或奖励判定。
- **已新增 SVG**：`assets/art/ui/evidence/` 下 ch001、ch003、ch007、ch008 四份与 `StarlightJournal.gd` 对应的物证特写；呈现与剧情分离，证据只允许通过原有 V3 事务提交。
- **可选工具，尚未执行**：`tools/bake_hd2d_normal_maps.gd`；仅在已经审核的 PNG 漫反射图上生成配套 `_n.png`，不能把 Sobel 亮度法线冒充真实手绘法线，也不能覆盖已调好的法线文件。
- **没有做**：没有替换正式角色/tileset，没有重设 42 图物理道路、门、NPC、出生点；没有创建 F5 演示主场景，没有执行 Godot/冒烟/玩家路径/画面验收。

## 5. 分批落地与最小验收顺序

1. **第一优先**：晨露村 → 白砂港 → 黑帆酒馆 → 鲸骨浅滩 → 灯塔；用正式玩家路径逐图复核遮挡、门口、室内回程与镜头。特别修复酒馆门窗/座席/通道比例，禁止家具遮挡出口。
2. **第二优先**：八地区各取一张代表图，定义对应独有建筑组、道路节奏、夜间灯光与可达行走宽度，整合 42 图。
3. **第三优先**：12幕界面、Boss组合、队伍头像与光照对齐；每个 Boss 仍采用其身份对应美术，不能用同一海岸背景或无关怪物替代。
4. **正式验收**：Godot解析/资源导入、地图可达性、室内往返、战斗结算、证物真实回执、save/load、窄屏/标准横屏截图。每项分别标记“成功/未测试”，不得用视觉设计文件代替游戏成品验收。

