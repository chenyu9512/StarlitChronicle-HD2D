# 《星灯纪行》C线 Batch 0：资源基线及接口修复交付

审计日期：2026-10-26。范围：GitHub `main` 的静态文件树、`av_registry.json`、原生C线接口；不等同Godot导入、真机性能、听感或商业美术验收。

## 实证资产清单

- `assets/art/external/cc0_named_v1/`：**807 个PNG文件已经存入GitHub**，源索引 `data/assets/external_cc0_named_index.json` 标记为 CC0-1.0、未自动替换原生贴图。另一目录 `assets/art/external/cc0_20261026/` 有7个可选样品。旧文档“807张只在本地”的表述不再准确。
- B02：`assets/art/b02/characters/` 按角色/居民身份组织，静态立绘、头像和对话图存在。B03：`assets/art/b03/boss_final_render/` 为5名Boss提供战斗静图与其他变体；均不可当作已制作的4/8方向动画。
- `data/assets/av_registry.json`：8地区、12主角、35名登记居民、63怪物、66Boss、20职业以外的81武器、54护甲、63技能等制作计划。登记不代表已绑定成正式动画。41个音频事件内26项未制作、15项仅程序化音效回退；没有已导入的正式配乐。
- 静态树检查：对登记表内139处 `res://assets/` 字面文件路径逐一核对，未发现缺失。注意这不覆盖动态拼接的资源路径、`.tscn` 导入、Godot SpriteFrames 加载和逐帧图像内容质量。
- 外部素材虽然由来源索引登记为CC0，正式发行仍需保留逐资源来源、原许可证据、哈希/作者信息与最终授权复核；不能将“索引声明CC0”自动视为每件素材通过法律审核。

## 本批实际修复

1. `scripts/av_event_router.gd`：兼容历史事件 `world.region_enter` 的 `bgm.region.by_id`，正确从 `region_id` 而不是 `skill_id` 展开。保持A线技能 `fx.skill.by_id` 使用 `skill_id`，避免更改共享事件及存档契约。
2. `scripts/c_town_soundscape.gd`：快速切换城镇/室内声音时，停止被中断渐变留下的旧声源；停止场景时只保留当前声源用于淡出，并立刻停止一次性Foley；重新进入场景不继承上一场停止中的声源。
3. `tools/smoke_c_av_event_router.gd`：增加地区/技能/剧情心情/天气ID、缺失音乐静音、非法动态ID及重复切换与结束场景不残留声源的专项烟雾验证。该脚本尚未在Godot执行。

## C → D 接入契约与现有阻塞

| 生产事件 | C线音频ID | C线视觉ID | 所需上下文字段 | 对接阶段 |
|---|---|---|---|---|
| `world.region_enter` | `bgm.region.<region_id>` | `fx.world.<region_id>` | `region_id` | D联调 |
| `combat.cast` | `sfx.combat.cast` | `fx.skill.<skill_id>` | `skill_id` | A/D联调 |
| `story.mood` | `cue.story.<mood>` | `fx.story.<mood>` | `mood` | B/D联调 |
| `world.ambient_changed` | `ambience.<weather>` | `fx.weather.<weather>` | `weather` | B/D联调 |

- 路由器只发出ID信号，**不代表**已播放完整音乐或绘出相应特效。音频缺失时注册器必须返回 `null`、不能假称成功。
- D线负责真实世界事件派发、地图切换和统一回归；C线只维护加载、渲染、声音表现，不更改剧情、存档、物理碰撞。
- 晨露村、白砂港、前三章真正的高清场景绘制、角色逐身份动作、63怪物与66场Boss演出、正式BGM都需要后续原创制作与玩家截图/录像验收。
- **专项验证待执行：** `godot --headless --path . --script res://tools/smoke_c_av_event_router.gd`；既有 `tools/smoke_c_town_presentation.gd`、`tools/smoke_c_character_motion.gd`、`tools/smoke_c_art_overrides.gd` 也需在C线批次中运行。完整Godot + 真机回归留给D线冻结集成。

## 前三章统一画风决议（制作基线，不是已完成美术）

- 正式目标：原创高清绘制Q版2D，温暖面部表演与足量视觉分层；原B02/B03保持身份ID，不允许把其他作者的复古像素角色直接置换为主角。
- 晨露村：海盐白墙、琥珀灯具、青绿浅海与薄雾；角色与民居的比例、光照方向和地面遮挡统一。白砂港：更高的码头建筑密度、潮湿木石材质与可辨识的海港剪影。
- 第一批正式资源优先顺序：主角/两名核心同伴的统一头像和行走图集 → 村庄室外/住宅内的统一纹理 → 前三章普通敌人与Boss身份化图 → 标题与对话/战斗UI → 配乐及环境音。任何一项都需独立截图对比与许可审查后才由候选转为正式。
- `CC0 named v1` 限于道具、UI图标等先行候选审核；原分辨率/像素结构不适配的素材标记备用，不通过简单拉伸冒充高清成品。无实际用途者不保留多重副本。
