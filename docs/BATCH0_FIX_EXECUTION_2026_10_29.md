# 《星灯纪行》Batch 0 逐项修复执行台账（2026-10-29）

> GitHub在线Main2实际修复。保留main，不新建分支、不提交PR、不强推。状态只能区分**代码已提交、同SHA CI成功、失败、未测试**，旧提交验证不能覆盖最新HEAD。

## 本轮实际完成的源码修复

| 序号 | 对象 | 修改内容 | 提交 | 证据与状态 |
|---|---|---|---|---|
| 01 | `scripts/rpg_core.gd` | 队伍切换返回文案由ASCII句号修正为完整中文句号，与既有成功契约一致；不松动人物时间线门禁 | `6de9be79383a` | 代码已提交；最新同SHA RPG测试未核实 |
| 02 | `tools/d_control/smoke_ch021_direction_gate.gd` | 第15章现为 active 合法试炼，拒绝使用过期“必须pending”断言；同时验证ch014无登记时不能生成控制器 | `ae72701a960a` | [隔离版章节门禁CI成功](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881108050)，只证明该次提交 |
| 03 | `tools/audit_art_pipeline_v3.py` | 第三方素材删除后，允许两份已退役的历史来源统计清单缺席并标记警告；继续强制核查109正式语义槽、黑帆酒馆、V18、源文件是否存在 | `b77d0c983326` | 后续[Art CI日志](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881589245)证明109/109运行源可见；仍查出地板路径真实错误 |
| 04 | `scripts/c_art_overrides.gd` | 旧素材清理后，动态从当前`active.json`把生成的真实图像注册到美术UI/DLC槽位；不把候选标注为视觉签收 | `4aa0cc4c64c0` | 代码已提交；后续主题兼容专项确认生成素材注册有效 |
| 05 | `tools/smoke_c_art_packs.gd` | 主题切换测试改为检查现行生成器、禁用旧包、可安装/启用/卸载用户DLC、界面有实际素材 | `9b5904e19601` | 后续[美术主题兼容CI成功](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881589228) |
| 06 | `tools/smoke_c_uploaded_later_pack.gd` | 不再强制恢复已清理的6组第三方素材；改为校验旧包拒绝启用、正式生成素材可加载且可见 | `76a2899849ee` | 与上一项同SHA美术主题兼容CI成功 |
| 07 | `data/levels/v4/interiors/map_coast_02__tavern.json` | 正式黑帆酒馆地板源从已删的旧SVG改为V10 256×256生成图集，和唯一V2语义槽一致 | `e2a471d874cc` | 当前HEAD静态读取确认V4/V2/生成清单路径完全相同，图集尺寸256×256；同SHA Godot/人工画面未完成 |

## 当前证据边界

- 验证成功（仅对应明确的Actions）：第21章隔离门禁；最新修复后的美术主题包专项。
- 通过静态核对：黑帆酒馆正式V4图集与主题索引及生成资源清单路径完全一致，且生成清单尺寸256×256。
- **仍未通过全游戏发行验收**：最新HEAD统一Main2 Godot全量门禁、第一幕完整六章玩家通关、40地图通行/画面、153室内、66Boss、120任务、20职业以及Runtime正式发布均须另行验收。
- 最近历史失败仍包含实际海岸场景的旧纹理依赖、Boss/主角身份图片、部分回归测试和图片人工审美缺口；不能仅把旧测试替换成空测试。今后以**失败日志→生产代码→指定SHA CI→玩家画面**顺序修。

## 下一批 P0 处理顺序

1. 拿到`e2a471d8`后的完整统一Main2 CI日志，按真正失败用例逐个修复（当前可能处于排队/执行，不继承更早的绿色报告）。
2. 核对第一幕主角/Boss以及五地图可见渲染节点与生成资源索引，用正式身份美术补齐实际缺图，不重建旧第三方目录。
3. 真实修复黑帆酒馆完整空间布局、家具尺寸与进退、收容所、浅滩、灯塔碰撞和截图。
4. 验证新旧档与战斗结算，优先保护任务时间锁、重复奖励及人物代际权限。
5. 复验后才允许Runtime发布；任何只读无素材GameCore镜像成功不等于游戏发行成功。

执行规则：修改文件前读最新blob SHA，同文件串行写，不造伪截图、不绕过游戏正常流程。


## Batch 0 连续修复批次｜2026-10-29｜第二轮

### 故障证据

- Main2统一门禁 [run 40881785276](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881785276) 在`e2a471d8`提交仅 **39/55**；Godot 4.7.2冷导入本身成功，16项静态/冒烟失败不能视为商业合格。
- 具体阻塞：40个V3地图尺寸审计误比对不存在的atlas字段、`art_source_contract`已删除、发行包作弊入口缺少editor门禁、旧源blob审核与已删除的图片/第三方迁移JSON冲突、第一幕1/3章证据热点被旧冒烟脚本跳过、V18场景脚本仍指向删掉的旧素材、V14场景加载器拒绝生成器新路径、NPC尝试解析已移除的V12清单、旧船只仍引用已删资源。

### 本轮线上源码实改（全部在Main2，仅指代码提交成功）

| 目标 | 文件 / SHA摘要 | 说明与验收边界 |
|---|---|---|
| 40地图审核 | `validate_global_runtime_contract.py` / `97ec34ce` | 校验实际V3尺寸且只有atlas显式给出grid_size才做跨表比对，不篡改地图数据 |
| 发行包作弊拦截 | `cheat_panel.gd` / `53f274ce`，`first_act.gd` / `2611a339` | 发行版本禁用调试菜单/命令；禁用已保存的无敌、无遇敌、5倍经验及速度作弊 |
| 第一幕正式资源静态检查 | `validate_first_act.py` / `3787623c` | 从旧第三方图片导入检查改为真实V9 `active.json` 中451图和401张法线的SHA256、路径、剧情、Boss身份校验；实际画面仍未签收 |
| NPC缺失旧资源清单 | `c_art_regional_npc.gd` / `29bd8804` | 文件不存在时不再触发JSON解析错误，直接回退NPC具名生成4方向精灵 |
| 玩家证据调查回归 | `smoke_first_act_flow.gd` / `7f66a3ca`，`smoke_act01_six_chapters_normal.gd` / `36df4244` | 通过真实证据热点UI按钮完成第一、三章调查，不直接写完成旗标/假胜利 |
| V18海岸正式布景 | `c_act01_hd2d_dressing.gd` / `b2c1e724` | 从manifest匹配真正的V10 `prop__hd2d__*`纹理ID，不再因旧路径限制整张地图遗漏布景 |
| V18资源完整性 | `validate_c_act01_hd2d_v18.py` / `8c5ce080` | 17个实际场景布置位、14种精确道具身份、11张256px材质，均验证原生V10 SHA256；审美依旧未测试 |
| 旧第三方审核更新 | `audit_act01_third_party_art.py` / `e25be5cd` | 只审计仍在使用的109语义槽、原图不存在、现行生成图片与6章/2关键室内；商业视觉验收参数仍不能假通过 |
| 港口船只实际纹理 | `c_act01_matched_props_v16.gd` / `81a46e6e`，`validate_c_act01_matched_props_v16.py` / `f5b3f48a` | 正式入口使用唯一`prop.harbor.dock_boat`身份、图像源/尺寸/哈希验证，不再要求已删原船/错误木桥 |
| 第一幕海岸语义纹理 | `c_act01_semantic_art_v17.gd` / `a5c98e51`，`validate_c_act01_semantic_v17.py` / `71c2d682` | 旧palm_tree正确映射真实V10红树林语义槽；洞窟水晶与海岸水晶共用同一个具名素材 |
| V14场景真实资源入口 | `c_act01_global_art_v14.gd` / `e80d03c8`，`validate_c_act01_global_art_v14.py` / `c83487e4`+`f63b5b0f`+`70162831` | 允许V14原有场景ID使用生成器V10资源；验证45图（10道具/6场景/9怪/5Boss候选/10地形/2背景/3UI）及SHA，明确区别章节Boss ID与生成图像ID。 |

### 已确认与未确认

- 已确认历史提交的 **Godot冷导入成功**、`smoke_save_integrity.gd`成功、`smoke_rpg_core.gd`成功、地图迷雾/小地图/可达性门禁成功；这些均为原`e2a471d8`SHA的结果，不能自动转移到最新SHA。
- [Main2 美术专项](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40885262725) 在旧`f63b5b0f`源验证到V14生成背景命名转换错误；已在`70162831`改正，**该修复需要同SHA复验**。
- **未测试/未通过**：最新统一门禁全部55项、真实玩家第一幕六章无作弊通关、全部美术实际截图的身份/美观人工签收、Boss数值及Runtime发布。任何单次成功的GameCore无美术镜像≠完整游戏成功。
- 现存场景对已删旧资源的引用必须继续逐项修复；不可以删断言、标记通过或者临时制造假图片掩盖美术缺口。
