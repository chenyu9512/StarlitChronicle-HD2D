# D线七项Batch 0 验收与修复交付（2026-10-27）

## 权威代码与实测边界

用户请求一次性处理截图中的7项：最新main全库编译启动、奖励事务重复回调、保存失败异常退出、V1/V2/V3旧档与损坏恢复、A战斗奖励事务、B任务状态奖励幂等、C资源工程运行素材。

- 新增七项独立真实Godot 4.7.2 CI：`.github/workflows/batch0-seven-qa-gates.yml`，工具 `tools/d_control/run_seven_gate_qa.py`，每项独立退出码、完整原始日志、JSON工件，未因其它项失败跳过。
- 首轮被测SHA：`dd6f53472a03b7dbed4a716cafa11cdf0f72b933`，原始 https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40437334870
- **修复后复测SHA**：`4b24adfe9dba221d51ecfd57c29605b5b2a6e4a5`，原始 https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40437992601
- 首次93脚本全量证据： https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40437178097（它不是复测SHA）
- 同期最新全量Runner： https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40437994406（同样需独立读取最终日志）
- 本报告写入前现行main `82f3bcf278a6a14181913c44fea48bd9c2e9234b` 已有A/B/C并行提交，不能把上面的旧SHA绿色结果冒认新HEAD全部PASS。
- 本任务没有操作截图所属项目管理界面的「待核验」下拉框；这里只更新了真正可审计的GitHub源码/CI/记录。

## 截图七项状态（严格依赖上述复测SHA）

| 项目 | 负责线 | 真实Godot复测 | 结果 |
|---|---|---:|---|
| 最新main全库编译与启动 | D/P0 | 8/8 | PASS（仅针对复测SHA） |
| 奖励事务与重复回调 | D/P0 | 5/5 | PASS |
| 保存失败回滚与异常退出 | D/P0 | 5/5 | PASS |
| V1/V2/V3旧档兼容损坏安全回退 | D/P0 | 4/4 | PASS |
| 战斗奖励与事务专项回归 | A/P0 | 6/7 | FAIL；高章Boss真实指令战败 |
| 任务状态与奖励不重复 | B/P1 | 5/6首轮、第二轮大型用例正在执行 | NOT_FULLY_VERIFIED |
| 资源工程与运行素材 | C/P1 | 11/11 | PASS |

## 实际代码修复

1. **C资源三层归档**：新增 `data/assets/c_art_source_originals.json`，将756份新增外部制作原档作为不可直接运行的独立源索引，保留原文件和blob SHA。维护原有C运行候选画廊，登记63份新增SVG/美术候选，删去已不存在的 `assets/art/_spec/preview_batch_0_3.png` 的**索引引用**（并未删除其它真实美术）。同步 `data/assets/c_art_catalog.json` / `data/assets/c_art_selection.json`，修订 `tools/validate_c_art_catalog.py` / `tools/validate_c_art_management.py`，使用当前实际的 `first_act_world.gd` 纹理绑定接口。
2. 对GitHub远端文件树与两份索引实际交叉核对：**1,996**份图片，**1,240**份画廊/候选，**756**份原档；未分类0、丢失0、分类重复0、候选列表与画廊不匹配0。没有把新增源原稿当已验收正式运行素材。
3. 修复 `tools/smoke_c_art_packs.gd` 已打印成功但 `quit(0)` 后继续走 `quit(1)` 的退出码问题。另一个C动作矩阵冒烟测试在并行C线提交中已修复相同退出码问题，第二轮真实运行PASS。
4. **QA工具修复**：修正标题页测试真实路径 `tools/d_control/smoke_title_foyer.gd`；保留120任务世界与40区域世界路径的全部断言，为耗时用例设置独立较长时限，避免用统一180秒超时误判功能失败。所有脚本都产生独立执行日志和原始返回码。

## A线仍未通过：真实第58-70章Boss

`tools/smoke_a_line_live_bosses.gd` 复测FAIL；22组中后期 Boss-难度组合出现真正团灭，胜利回调=1且胜利=false，Boss HP未归零。例：ch058标准回合8，Boss剩2708 HP、队员HP=[0,0]；ch068挑战回合6，Boss剩3968 HP。奖励/V3结算、战败回到世界、前三章流程等其它6项已PASS。**不能调低断言、伪造胜利或将此结果写成PASS**。A线完整Boss数值问题已记录 https://github.com/chenyu9512/StarlitChronicle-HD2D/issues/12 。

## B线验收

`smoke_b_story_transactions`、`smoke_batch02_quest_and_b_outbox`、`smoke_story_side_quests`、`smoke_branch_story_phase19`、`smoke_b_coast_three_chapter_routes` 在首轮PASS。 `smoke_story_world_phase19_2` 120任务、40区域实证曾超过210秒，未得到完成证明，已增加单独540秒运行时限。是否PASS**以第二轮B job最终日志为准**，不得略去第6项的实际结果。

## 最终门禁

**Batch0尚不是完整PASS；M1/Batch1继续HOLD。** 正式发行前还需要处理A线Boss、B世界/剧情运行路径、全量CI其它未关闭P0，并在A/B/C/D共享文件冻结后的精确main SHA重跑全部验证及人工连续游玩。