# 《星灯纪行》B线：第一幕商业级黄金样板交付与未解决P0（2026-10-27）

**起始main：** `67c8b8e9a9d1897fa20e8b7d0d4a67e07ea6d2c1`  
**本报告生成时main：** `bd2344d8c91780cdd263d7aa69f0a86634106fb0`（并行main会继续前进）

## 产品立场及事实范围

第一幕是**序章＋第1–6章**，且必须真实从玩家入口玩通，而不是依赖CI脚本的marker传送、无敌模式或预置完成旗标。继续保持原始**单人离线/指令回合制JRPG**、32px逻辑地图、现有40地图与72章稳定ID，无探索迷雾和全局世界地图。B线不改D存档事务或A战斗代码，不覆盖C正式美术。

**本次确已提交源码及内容**；但GitHub源码与JSON核对不构成Godot实机/商业级验收。

## 本批直接落地的B线成果

### 1. 晨露村与白砂港不再只有一城有居民

`data/content/npcs.json`：40个原NPC身份及稳定ID完整保留。原本海岸地区5人全分在 `map_coast_01`，白砂港 `map_coast_02` 没有常驻居民。

- 晨露村保留潮汐婆婆、盐风渔夫、巡灯学徒（3人）。
- 白砂港迁入 `npc_coast_04` 渔市行商和 `npc_coast_05` 海岸记录员（2人）。
- 更新了两人的`map_id`、`home_district`、`work_district`和5段日常行动，严格引用港口真实街区 `渔市水岸`、`港务广场`、`旅店与货栈`、`水手街`。
- 重写了港口真实职业语境的首次见面、白天重复、夜间、章节结束与社区完成对白：商船货票、收容所失忆水手、潮汐班表与保存两份名册。只有内容变化；没有任务奖励变更或新货币。
- 旧档保留全部NPC“已交谈”状态，NPC居住地点随新正式资源配置更新。跨地图过渡及NPC实时走路仍由D接线。

### 2. 第一幕真实行走与互动点质量门禁

新增 `tools/smoke_b_act01_physical_reachability.gd`：针对6章，创建**真实TileMapLayer**的当前章节世界，使用实际`blocked`格与出生点作四邻接洪水填充，不允许直接传送完成检查。必须从出生点沿连贯路径接近：
- 每章5个主线实体：`key_npc`、`clue`、`witness`、`crisis`、`resolve`；
- 每章3个固有支线对象：`side_start`、`side_item`、`side_return`；
- 所有实际邻接地图出口：`exit:map_id`。
同时要求地图路径查询不会修改存档或非法越过章节解锁。
这是**引擎测试入口**，不是人工玩过第一幕的证明。

新增 `tools/smoke_b_act01_coastal_residents.gd`：验证40 NPC身份、3+2沿海居民、港口24h有效活动区、居民不会在错误城镇重复生成或站到墙中。

手动 `.github/workflows/b-world-batch-validation.yml` 已纳入这两组专项回归与第一幕来源审计。

### 3. 第一幕“剧本地点≠正式地图”不再被误报为已完成

新增：
- `data/levels/act01_scene_locations_v1.json`：第1–6章正典故事地点与所需实体场景种类、应在的地图ID、真实步行动线、是否应有专属室内。
- `tools/validate_b_act01_commercial.py`：读取现有6章主线/支线/Boss、40+2地图、40 NPC与活动街区，输出逐章节来源证据及**未达标的商业验收阻塞**。`--strict`会在场景错配/缺室内时返回非零，防止报告用“内容存在”代替“玩家可玩”。

| 章节 | 正典剧情发生地 | 正式当前加载 | 商业阻塞 |
| --- | --- | --- | --- |
| 1 | 晨露村·澄舟旧屋 | `map_coast_01` 晨露村 | 已有house室内，需真实完整流程验收 |
| 2 | 白砂港·收容所 | `map_coast_02` 白砂港 | 缺收容所独立可探索室内 |
| 3 | 断桅海蚀洞 | `map_coast_03` 盐风古道 | 剧情洞窟应接入 `map_coast_04`，其目前是章节4锚点 |
| 4 | 白砂港·黑帆酒馆 | `map_coast_04` 潮声洞窟 | 主线锚点错误，缺白砂港酒馆真实室内 |
| 5 | 鲸骨浅滩 | `map_coast_05` 潮歌灯塔 | 应在海岸路线建设有身份的浅滩关卡分区 |
| 6 | 潮歌灯塔 | `map_coast_01` 晨露村 | 应实际抵达 `map_coast_05` 灯塔地图 |

**重要：** 此合同目前是B/D集成的审核依据，**不是已经修改WorldRegistry正式章锚点**。贸然改 `data/content/quests.json` 将打断 `first_chapter`、发现/解锁、旧档和A/D的战斗接线；应由D在验证兼容回程与旧存档后实施统一迁移。没有制造“第41张地图”或虚假的已接入室内。

## 手动验收及需要的真实测试

```bash
python3 tools/validate_b_act01_commercial.py --output /tmp/b-act01-sources.json
# --strict 会因为目前真实存在的场景/章锚点缺口而失败，属于预期阻塞
python3 tools/validate_b_act01_commercial.py --strict

godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_b_act01_coastal_residents.gd
godot --headless --path . --script res://tools/smoke_b_act01_physical_reachability.gd
godot --headless --path . --script res://tools/smoke_first_three_playable.gd
godot --headless --path . --script res://tools/smoke_first_act_flow.gd
```

**本环境实际状态：** GitHub数据与源码再读回已核对、变更已提交；**Godot 4.7.2编译和游戏运行尚未执行，所有新增脚本标记未测试**。先执行上述B线专测，按真实日志修复阻塞，再做第1–6章无需开发者传送/无敌的人工连续通关与截图。当前不承诺商业验收已完成。

## 下一批商业优先工作（B/C/D责任明确）

1. **D+B P0：** 制定6章现有正典场景和实际地图ID的一次性稳定迁移。D负责`WorldRegistry`旧档/章节门槛/真实出口变更；B提供故事锚点和可走动的关卡布局。
2. **B+C P0：** 为第2章收容所、第4章黑帆酒馆、第5章鲸骨浅滩建设有身份、可探索、可交互的正式场景（不是名字相似的普通屋子或静态概念图）；B先交付场景入口、阻挡、调查物与剧情触发配置，C接入正式美术。
3. **D P0：** 完成B线此前移交的社区/野外活动金币、物品、HP和位置的原子V3事务；禁止保存失败时发奖、物品丢失或重复领取。
4. **A+D P0：** 六章的5个Boss实际战斗回执、失败重试、保存恢复与章节解锁不得被假事件代替。
5. **全线P1：** 只在上述可玩主流程完成后优化剧情场景角色站位、NPC自然走路、日夜生活、音画细节、连贯镜头及游戏内引导。

本批并未改写A/C/D线独占文件，未创建分支/PR，按主线逐文件SHA写入。
