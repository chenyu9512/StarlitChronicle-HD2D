# D线独立修复交付与待集成清单（2026-10-26）

本交付遵循仅main、无PR、无强推；不改A/B/C共享脚本、不碰 docs/qa-batch-trigger.json、不自行运行完整Actions。**不是已集成的游戏修复或商业级验收。**

## 已直接落地的独立代码

1. tools/d_control/atomic_story_save.gd：真实Godot GDScript安全IO组件。对原版剧情存档v1/v2保留平铺JSON；先写临时文件并flush，重新解码验证后才替换，旧正式档有效时写备份；原档损坏时可回读上一有效备份，不用坏主档覆盖备份。
2. tools/d_control/smoke_atomic_story_save.gd：真实可执行Godot独立回归，process-local user://目录；验证首次保存、覆盖、损坏主档、备用档回退、旧v1、无效新档拒绝。不绕过游戏胜利，也不动正常玩家存档。**尚未在Godot运行**。
3. tools/d_control/propose_story_runtime_fix.py：只生成共享脚本差异补丁，拒绝不匹配原有代码形态；从不直接修改 scripts/story_runtime.gd。B线评审、三线冻结后才能D统一集成。
4. tools/d_control/test_story_patch.py：Python夹具验证补丁保持“先保存、失败回滚、不发奖”的顺序及重复修补拒绝。
5. tools/d_control/verify_crosslinks.py + test_crosslinks.py：对全12幕、66Boss、20职业、40活动地图及120支线，实行独立跨源ID、章节前置与任务地图锚点校验；一处关键关系被篡改就返回FAIL；明确不会把静态PASS当成Godot通过。

## B线共享补丁待集成内容（P0）

- 改 scripts/story_runtime.gd 的save_story/load_story，对接安全IO组件，避免对现有live剧情存档WRITE截断；兼容v1/v2。
- _finish_scene：保存失败恢复旧flags与scene_index，世界事件和奖励推迟至故事进度保存成功之后；失败即return。
- start_side_quest/advance_side_quest/complete_side_quest：保存失败时回滚任务进度/完成flag，禁止继续发出一次性奖励。
- **余留的跨文件事务风险：** 剧情存档成功到A线金钱/经验入账之间可能断电；单纯延迟奖励只能避免写档失败后立即发奖，不足以实现跨两个存档域的严格exactly-once。A/B必须对奖励事件引入持久化事务ID与已应用回执，正常、重试、回滚均要真实Godot注入故障测试。此项未满足前P0不能关闭。
- choose_option/complete_objective/report_battle_result 等其他直接忽略save_story失败的调用点需要B线补充一致性回滚测试；提案没有声称全部覆盖。

## 84条地区/同伴支线

story_catalog.get_quest仅从36条基础side_quests中读取，但主场景rpg_core、世界锚点与独立分支模块有另一套路由。**不应在未确认双方计奖规范时盲目扩容get_quest**，避免重复奖励、双重触发。新的静态验证检查120个任务世界锚点与前置章节一致，具体运行时接取—NPC触发—选择—结算—存档重载仍需B线全量Godot测试。

## 具体命令（无需额外pip包）

静态：
- python -m unittest discover -s tools/d_control -p 'test_*.py' -v
- python tools/d_control/verify_crosslinks.py --root . --json
- python tools/d_control/audit.py --root . --strict

预览补丁（不改共享脚本）：
- python tools/d_control/propose_story_runtime_fix.py --root . --output /tmp/starlit-story-runtime-proposal.diff

Godot专项（待有Godot 4.7.2运行环境）：
- Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/d_control/smoke_atomic_story_save.gd

本次D本地Python夹具测试共21项PASS（隔离工作目录版本）；新提交的GitHub文件尚未通过当前HEAD的GitHub Actions或Godot完整测试；不许以历史成功记录代替验证。

## 合并与发布门槛

等待A/B/C显式确认停止写入，重新取main SHA后，B审核生成的剧情补丁并由D一次性完成共享文件集成；设计持久化reward_nonce/outbox并验证跨存档幂等；复跑全部静态、Godot脚本与完整一批QA，确认无P0/P1之后才可以讨论发行级签收。
