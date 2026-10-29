# 《星灯纪行》B线 · 第一幕白砂港双场景商业级补全（2026-10-27）

**主仓库** `chenyu9512/StarlitChronicle-HD2D`  
**本批开始读取的main** `f78629cc47245b09c17081b59e65fd7b084f3dc6`  
**编写本记录时main** `a293bf1515332b08d8bbf5c5953795d78155bcc9`。main-only，无分支、无PR、无强推。

## 完成的实际源码与地图数据

### 白砂港新建两处可进入的真实建筑

修改 `data/levels/world_atlas_v2.json` 的 `map_coast_02`：保留原始6栋正式建筑，追加：
- `shelter`「临潮收容所」：建筑中心(52,22)、实体门口(52,25)、占地8×6；对应第二章《失去名字的归人》。
- `tavern`「黑帆酒馆」：建筑中心(68,19)、实体门口(68,22)、占地10×6；对应第四章《第三位同行者》。

这两栋走**现有的`WorldGeography.layout`→`first_act_world.build`→`building:<id>`门口→`World.enter_building`→`WorldInteriorV4`→`interior_exit`回程**，不是独立模拟地图或假传送。正式建筑总数从66变成68，地图仍是40正式＋2原型。

### 两间独立V4室内

新增：
- `data/levels/v4/interiors/map_coast_02__shelter.json`
- `data/levels/v4/interiors/map_coast_02__tavern.json`

每间有：72×48室内地形、独立floor/solid/door区、有效出生/退出/服务/储存坐标、7件具名陈设及**4条唯一线索**。

收容所：当值药盒、搁浅行囊、临时名册、盐草安神盆；文本围绕病患身份、失忆、收容与慎重保存证据。  
酒馆：夹层货箱、无日期船员告示、靠窗旧餐桌、酒桶下的旧账簿；文本围绕黑帆货单、欠薪及航路调查。

8条线索统一采用`WorldHomeInteractions`现有的先看/重看/完成章节后变化规则，保留稳定ID、绝不直接发道具金币、兼容V3`home_investigations_v1`存储桶。`after_flag`分别为`story.ch002.done`与`story.ch004.done`。

**已知范围：** 新建筑和房间可通过正式引擎代码路径进入，但尚未得到Godot实测回执；新房的剧情调查`WorldHomeInteractions.inspect_at`是B线域逻辑，现有D线正式世界控制器**还未生成通用室内调查输入点**。因此“玩家从游戏内亲手调查四条线索”目前**未验收**。C线专属手绘室内图集/正式灯光也尚未接入，当前使用旧的通用V4地形与具名陈设精灵。

## 实际验证、测试工具及诚实状态

**已经通过GitHub源码读取后实施的静态检查：**
- 两间房各有998个由出生点连通的地面格；出生、退出、服务、存储及8个线索目标均在连通范围。
- 白砂港8栋建筑互不占地重叠；全世界建筑源总数68；40＋2地图ID数量不变。
- 源码和数据提交已核对，但没有引擎画面截图、游戏手柄操作证明。

新增：
- `tools/validate_b_act01_harbor_rooms.py`：实际离线BFS重新计算两间室内地面、碰撞、可达性，检测建筑重叠、门口与屋体、一章各四个具名调查点、章节完成后的文本与私人物权。
- `tools/smoke_b_act01_harbor_story_rooms.gd`：Godot正式世界对象进入两栋建筑、检查V4布局、8线索、重复调查、V3存档/恢复、户内外原门口回程。
- 更新`tools/smoke_town_entrances.gd`、`tools/smoke_b_roof_pathfinding.gd`、`tools/smoke_b_home_runtime_geometry.gd`、`tools/validate_all_map_display.py`、`tools/audit_b_world_source_matrix.py`和手动`.github/workflows/b-world-batch-validation.yml`，验收总量调整为68门、99室内；已有12间C线独立美术室内及52个旧家具调查源仍按原逻辑独立验证。
- `tools/validate_b_act01_commercial.py`严格标记两间房“**V4几何已具备，但C美术与D可按键调查接线尚未通过**”，不允许把数据存在当成商业验收。

**状态：** JSON结构和室内BFS属于静态检查成功；Godot 4.7.2在当前开发执行环境中未安装，无法执行新引擎脚本、运行截图及玩家手动体验，**Godot测试＝未测试，商业级验收＝未测试**。GitHub Actions手动工作流已接入但本批未触发，不声称其通过。

## 必须交给D线的下一批P0

1. **D线：** 在共享`scripts/first_act_world.gd`的正常室内`_build_sites()`生成`home:inspect_<id>`实体或等价面向调查热点，**只采用B侧`WorldHomeInteractions.objects(map_id,building_id)`批准的坐标**；不能为获得输入而将相同家具放成第二份。
2. **D线：** 在`scripts/first_act.gd::_interact`处理新对象ID，使用现有统一`d_world_interaction/interior_interaction.gd`回执／V3事务完成第一次检查，防重复、保存失败整批回滚。D应校验玩家确实在当前屋内且与对象在合理距离；旧档的已检查状态仍有效。
3. **D线：** 第一幕正式章节锚点/旧档入口迁移在统一QA完成后才进行：第2章回收容所，第4章回黑帆酒馆；第3章洞窟、第5章浅滩、第6章灯塔仍存在上一批对照表的章节地点差距，不应靠测试传送绕过。
4. **C线：** 为两处场景补唯一性更强的原创手绘建筑立面与室内图集；美术应沿用既定门口、家具、灯光/遮挡坐标，不能打断主路线。B允许替换静态素材，但禁止重写D输入/存档控制器。

继续保持离线单机JRPG，第一幕先打通真实动线与场景，优先完成商业体验，再考虑推广至剩余正典内容。
