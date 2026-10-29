# D线第二轮架构与验收检查（2026-10-26）

## 测试状态

- 静态结构取样SHA：55dd43bcb16d7300421100383ff9de4d00c37d78。
- 随后A线继续写入，观察到SHA：f0d5ea4c6c9fffe9a11467fd6f80e87a287cae79，三线停止写入条件没有确认。
- 本地D线隔离测试：8/8 PASS，Python 3.13.5。本地副本测试，不是GitHub Actions，也不是完整Godot。
- GitHub连接器读取源文件并执行跨域静态关系校验：72章、66Boss、40活跃地图、20职业、120支线。
- 完整仓库的D线审计Python命令：未在本地执行（当前环境没有完整仓库文件）。
- Godot 4.7.2 完整运行测试：NOT RUN（执行环境没有Godot编辑器，也无法下载；三线尚未确认冻结）。
- 最新过往完整Actions成功记录为 run 40274482154，运行SHA 6c32e274182aeb6460af913742be48d8626da1bb，不能代表新HEAD已通过。
- 商业级最终验收：NOT PASSED。

## 全域静态证据（只对上述静态SHA成立）

| 项目 | 已核实事实 | 仍需运行验证 |
| --- | --- | --- |
| 72主线 | 每幕6章，前36章144场景、后36章145场景；章节顺序、必需前章flag、场景ID唯一；无空章 | 逐章真实解锁、场景恢复、奖励幂等 |
| 66 Boss | 正典Boss与机制记录66/66 ID及对应章节一致；64份仍标注 a_line_runtime_pending_godot，2份标注 legacy_runtime_not_replaced | 各Boss真战、失败与胜利结算 |
| 40活跃地图 | 40布局存在，基础目录另有2个prototype；40张活跃地图 art_status 均为 not_final_painted | 资源、传送、室内读档与移动性能 |
| 20职业 | 20个职业ID与20份配置完全匹配，职业目录仍注明 design_ready_not_implemented | 战斗装备职业切换和旧档 |
| 120支线 | 36普通+36地区+48同伴，唯一ID；120地图锚点无缺失、重复或无效map_id；120个first_chapter匹配required_chapter | 84地区/同伴运行时接取、推进、结算及存档 |
| 四/五阶段任务 | 地区/同伴84个任务每项四阶段、普通36个每项五阶段；没有重复stage ID | 实际NPC交互与分支序列 |

84条地区/同伴任务没有顶层rewards字段（普通36条有）。这不是不存在奖励的证明，需由B线提供运行时真实结算来源。

## 风险分级（静态代码证据，不冒充崩溃复现）

- P0-SAVE-01：scripts/story_runtime.gd 的 save_story 直接写正式剧情存档，不采用V3临时文件+备份+校验流程；断电/损坏恢复待补丁和故障注入。
- P0-SAVE-02：scripts/story_runtime.gd 的 _finish_scene 在save_story失败时仍继续发出 reward_granted；需测试失败保存—重启—恢复—重新结算是否重复发奖。尚未实机复现。
- P1-QUEST-01：scripts/story_catalog.gd::get_quest 仅查询36条普通side_quests。调用其story_runtime.start_side_quest接取其他84ID不会直接命中；scripts/first_act.gd/rpg_core.gd/story_world_bindings.gd另有主场景运行路径，不能因此断言84任务都不可玩。B线需给出84条的实际可执行映射。
- P1-SAVE-03：game_state V1、first_act_state V3、story_runtime剧情V1/V2并存，缺三档域跨系统断电恢复和黄金旧档覆盖证据。
- P1-INTEGRATION-01：A/B/C尚无共同冻结SHA，最新HEAD继续变化，不能给出最终统一验收结果。
- P2-PERF-01：正式40图均在基础清单中标注美术待完成；没有iPhone GPU峰值、内存/帧耗/过热实测。

## 完整Godot验收前置条件及验收命令

A/B/C都显式声明停止写入并交付专项回归之后，D读取最新main SHA，确认P0修复、共享契约、旧档兼容、84条支线的运行接口，然后统一一批执行：
1. python -m unittest discover -s tools/d_control -p test_*.py -v
2. python tools/d_control/audit.py --root . --output /tmp/starlit-d-audit.json --strict
3. 现有完整Godot 4.7.2 Core Validation（workflow_dispatch仅一次），保存目标SHA、run ID、所有步骤及日志。
4. 不修改docs/qa-batch-trigger.json，不以跳关、锁血、强制完成任务代替验收，不使用旧SHA成功结果冒充最新QA。

**本次没有运行完整GitHub Actions或Godot；统一最终测试没有成功结果，商业级验收不通过。**
