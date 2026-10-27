# 《星灯纪行》B线第一幕 · 六章实际步行路线与主线引导（2026-10-27）

## 交付事实

基线main：`46ce320f16a93a44f2234e50b6b1674ac08df71f`  
本报告保存前main：`b7a98c4ae8eee61525cf74cc04cd57bbdcd7ac63`。并行主线提交后须重新核对SHA。全部修改是main-only的逐文件CAS提交，没有建立PR、额外分支或强推。

本批拒绝新增全局地图、探索迷雾、瞬移或任何MMO功能。**第一幕仍然是未通过商业验收的单人离线剧情JRPG。**

### 本批确实实现的代码

1. `data/levels/act01_scene_locations_v1.json`：在第1至6章的原有正典地点契约上新增`route_map_ids`。每段只使用实际`world_atlas_v2.json`中已存在的双向相邻出口。保留旧存档默认章节地图锚点和原始稳定任务ID。
2. `scripts/world_act01_journey.gd`：B线只读路线指示服务。构建时逐一验证章节、真实地图存在和地理邻接；`preview(chapter,current_map,state)`不调用`WorldRegistry.bind`、`travel`、`save`，不修改`visited/discovered`，验证传入章节与当前存档章节一致，并返回真正的下一出口、目标房屋、目标地点，以及未解锁原因。
3. `scripts/world_service_menu.gd`：第一幕城镇的现有服务面板增加一条简短主线去向提示；显示当前区域下一条实际道路或剧情锁定状态，不新增地图UI模式/远程传送功能。
4. `tools/smoke_world_story_interactions.gd`：原旧测试仍调用删除的`_open_world_map_from_book()`并断言世界航路模式，会在无迷雾本地地图方案下错误失败。现改为`_open_local_map_from_book()`、`full_view.mode=="local"`，验证查看地图不更改玩家存档。
5. `tools/validate_b_act01_journey.py`、`tools/smoke_b_act01_journey.gd`：新增静态六章路线邻接/章节锁定检查和Godot离线环境中的玩家存档只读验证。
6. `.github/workflows/b-world-batch-validation.yml`：两项新测试纳入现有手动触发批次，不按每次main提交消耗Actions分钟。

### 真实路线与尚未解决的章节错位

| 章 | 正式旧章起点 | B定义的实体路线 | 目标 |
| - | - | - | - |
| 1 | `map_coast_01` | 01 | 晨露村旧屋 |
| 2 | `map_coast_02` | 01→02 | 白砂港收容所 |
| 3 | `map_coast_03` | 02→03→04 | 海蚀洞 |
| 4 | `map_coast_04` | 04→03→02 | 黑帆酒馆 |
| 5 | `map_coast_05` | 05→04→03 | 鲸骨浅滩 |
| 6 | `map_coast_01` | 01→02→03→04→05 | 潮歌灯塔 |

第2章等路线包含旧章起点以外的完整步行建议；`preview`按玩家实际所在地图选择下一腿或到达提示。该规划**尚未被D线用于更改游戏章节自动入场**。

**正式P0：** `world_registry.gd`的首次解锁规则基于`data/content/quests.json`最早章节：`map_coast_04`目前第4章才解锁。第3章要求海蚀洞，`preview`明确返回`chapter_gate`阻断；不能把“已有路线数据”视为玩家第三章已经能进去。

此外第四、五、六章的旧自动入场地点不符合剧情场景，且第二、四章新增室内的D线交互绑定及C线美术、第五章非致命决议、第六章灯塔Boss和结算均仍需按实际流程验收。

### 真实测试状态

通过已连接GitHub重新读取本批9个相关文件并按实际图集与主线任务源进行独立数据交叉核对：六章路线全部真实相邻、最后一站匹配剧情目的地、旧章起点包含在路线内；唯一按现有解锁规则阻断的章节路段是第3章通往`map_coast_04`（最早第4章解锁）。同时核对新UI接口、已退役世界地图测试不再调用旧方法、CI引用存在，无冲突标记。这部分**源码/数据核对成功**。

Godot编译、手动CI、Windows实机、六章连续通关：**未测试**。没有记录任何未经执行的PASS。

### D线下一步接口消费（不要在B线重复拥有者逻辑）

- 正式D线章节入场应以`WorldAct01Journey.preview`提供的目标/下一相邻出口为只读依据，但解锁/移动必须通过`WorldRegistry.can_travel/travel`或经兼容测试的等价事务完成，绝不由B模块直接写`world.current_map`。
- 第3章海蚀洞开放应通过完整章节门槛迁移方案处理，不能简单把第4章锚点直接改成第3章而没有旧档、任务与Boss条件回归。
- 章节4/5/6应优先验证各自的剧情地点进入及真实路线回程；确保玩家保存时在房内、地图出口附近及Boss结束后的回载均可靠。
- 只有Godot批量引擎测试通过、实际六章玩家无需作弊走通、场景美术/声音完成，才能标记第一幕商业级验收成功。
