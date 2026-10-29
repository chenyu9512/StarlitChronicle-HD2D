# 《星灯纪行》Main2美术优化版 · P0修复与验收记录（2026-10-27）

## 分支与安全

- 用户最新决定：所有后续新代码、新美术、地图、文档、测试和Bug修复均提交到现有 `Main2美术优化版`，不再直接开发到 `main`。
- GitHub网站默认分支仍可能为 `main`；连接器文件写入每次都必须显式给出 `branch=Main2美术优化版`。这**不等于**已通过仓库设置切换默认分支。
- 不删除 `main`、不新建额外分支、不强推、不覆盖美化分支既有第三方美术迁移；本批未变更发行资源许可判定。

## 本次确实提交的源码修复（WIRED / 未经完整Godot验收）

1. `scripts/world_registry.gd`：读取六章正典位置契约，至少允许第3章通过合法双向地图出口抵达 `map_coast_04`；第2至6章正常顺序推进时保留当前地图，避免自动章节传送；非顺序旧档仍保留旧落点回退。
2. `scripts/first_act.gd`：主线在第一幕非正典地图不再显示当前目标焦点/允许完成事件；真实相邻地图导航提示玩家下一目的地；并将第一幕室内调查写入V3事务。
3. `scripts/first_act_world.gd`：V4已通过几何验证的家具线索拥有真实交互节点；玩家近距离可以选择，室内出口优先级仍高于家具。
4. `scripts/first_act.gd`：商店/旅馆/药草使用改为 `WorldObjectSettlement.transact`，存档失败恢复此前的道具、金币、HP/MP和时间状态；房屋/调查室进出及地图旅行失败则恢复V3运行快照和原世界位置。
5. `tools/smoke_b_act01_journey.gd`、`tools/smoke_architecture.gd`：历史“第3章洞窟必须锁定”和“章节升级必传送旧地图”的断言更新为当前玩家路线契约。
6. `tools/d_control/smoke_main2_act01_route_and_room_transactions.gd`：专测第3章洞窟开放、实际双向旅行、顺序换章保留地图、白砂港8个室内真实玩家调查点、以及不可写V3时无错误调查回执。
7. 已将新回归挂入目标分支的 Godot Core 及 M0.1 World Geometry 工作流；全部smoke执行器会递归发现新脚本。

## CI策略

- 仅改动本分支的 `.github/workflows/`，7项受QA标记触发的工作流 `push.branches` 指向 `Main2美术优化版`，手动触发入口不改。
- 批次 `Main2-act01-route-room-rollback-2026-10-27`：通过目标分支专用QA触发文件请求 Core、Full Smoke、Seven Gates、M0.1 World 批次。连接器不能原子移动分支引用；如采用逐文件提交，测试可能位于不同SHA，不能冒称同一SHA完成全部门禁。
- `main` 上的历史绿灯不能作为此分支美术迁移后的冷导入成功证明。
- **当前状态：代码提交成功，最新冻结SHA的Godot执行/玩家完整六章通关尚未获得结果；不能标为商业成品。**

## 仍未完成的商业级问题（需按实际引擎日志继续判定）

- 第1、2、4章室内调查是否足以驱动正典任务剧情与Boss前置，仍缺完整玩家连续操作演出签收。8项调查只证明可按键、可持久化，不意味着主线场景脚本全部改为专用房间。
- 第5章非致命结局、第6章灯塔重燃与Boss/存档事件一致性仍待真实通关证据。
- 全部40图/68建筑逐门实际体验、20职业与66Boss平衡、120任务链的玩家实走验收仍未完成。
- `Main2美术优化版` 已进行大量第三方美术迁移与旧图片删除；需要独立Godot资源导入、动作帧/头像/图集/场景可视截图及授权审核，不能仅凭路径解析认定商业画面通过。
- 目标设备性能、Windows完整克隆/导出、正式BGM及NPC/怪物动画均不能在没有测试证据时被标记通过。

任何CI失败都在 `Main2美术优化版` 修复，不擅自回写 `main`。


## 追加验收：美化分支 2026-10-27 16时段

- **实机地图图集专项绿灯：** [Main2 Map and Third-party Terrain Acceptance · 40464007111](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40464007111)。包括真实地形、水体、叠层材质及第三方来源适配，限该Run的提交SHA。
- **第17/51章Boss动态素材专项绿灯：** [Playable Regional Art V13 · 40464523373](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40464523373)。关键修复：`scripts/c_art_librarium_boss_idle.gd` 接受正常250ms画面更新，不再因120ms上限而冻结前三帧轮播。
- **主控全量 Core · 40464640443：** Godot 4.7.2冷导入/脚本、全40图、序章→前三章正常战斗、第一幕六章流程、72章主线、120任务节点、12失落书页室内、19生活任务室内、54伙伴/地区房间及最终场景启动均经过CI并通过对应独立步骤。该Run总体结论仍为FAIL，最后一步旧 `qa_hd2d_refinement.py` 要求被Main2正式迁移删除的旧文件 `assets/art/tilesets/coast_ground.png`。
- **工程验收与商业画质分开，不等于降低发行标准：** Core现执行 `tools/qa_main2_migrated_art_integrity.py`，检查89个历史逻辑美术槽位和其中55个coast-v2成员确实解析到物理第三方图片且可解码；`tools/qa_hd2d_refinement.py` 继续保留为严格商业美术参考门槛，不能因路径映射、贴图读取得到“视觉通过”。第一幕第2/4/5章仍欠缺最终语义/场景独立美术与实际玩家截图验收。
- **新Core复测：** [40465522451](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40465522451)，触发SHA `21d321eb5e5d30080f45ba00f55e01ce6a3e3d10`；发起时状态为running，最终结论须以实际Actions页面为准。
- **C线V12审计未过：** 后续继续上传source_packs，旧746源图/104非PNG件的静态总表尚未把新批次纳入逐文件分配，而且至少包含 `__MACOSX`/`.DS_Store` 等非运行时元数据。需在独立C批次依据Git blob与实际文件清单分配/清理，禁止为出绿灯简单忽略有效新图。
- **分支纪律：** 上述所有本次提交均在 `Main2美术优化版`；`main`未因本轮修复被回写。其他C线持续提交可能使分支HEAD领先于上述已测SHA，不能混为同一SHA。


## Main2本轮后续修复与正式引擎证据

- **Core工程门禁：通过**。Run [40465522451](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40465522451)，目标SHA `21d321eb5e5d`。冷导入/编译、序章/六章、72章、任务、存档等主控通过；严格商业美术验收未并入该门禁。
- **美化地图+实际玩家DLC门禁：通过**。Run [40466949291](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40466949291)，目标SHA `921e5a9092d3`。包含旧B路线顾问同步第3章洞窟合法解锁、两张256×256贴图一键导入为21个地形槽位、DLC主题切换、真实晨露村路面叠层/建筑门灯、共享材质和地图渲染。DLC不再通过C迁移兼容层改写上传者的完整图集。
- **美术运行时门禁：通过**。Run [40466917655](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40466917655)，目标SHA `43b9754b38a0`。可构建实际美术/人物/图层，但不替代玩家屏幕美术审核。
- **全量119项Godot冒烟：旧SHA仍失败15项**。Run [40465826331](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40465826331)，SHA `cd824462b311`，104通过、15失败。之后B路线、DLC主题/导入、路面叠层/门灯四个缺口已做源码修复且由较新针对性CI验收；**禁止把旧SHA的15个失败自动全部清零**。
- **还需要制作或真实替换的美术**：第一幕2–6章五个独立Boss仍使用不恰当的单一“骷髅王”等错配转移素材；B03原768立绘、不同Boss的6帧阶段图并未由真正等价的第三方动画替代；九种海岸怪的攻防受击/倒地动作、某些独立房间和建筑立面仍不具商业美术验收证据。针对这类缺口不能仅放宽测试、生成假帧或复用无关人物。
- **下一批明确顺序**：先按Boss本体/敌人动作语义，从后来上传的原始素材包选择可真实导入导出的独立画面和帧，再逐一接入B03和海岸怪；在同SHA重跑失败的专项与四片全量smoke后记录最新剩余量。对原source_packs中尚未分配的附件文件仍应单独建立来源审计，禁止草率报零。

上述修复提交全部在 `Main2美术优化版`，未回写 `main`。
