# GitHub Actions 首先恢复：运行器诊断与A16验收

## 2026-10-25 实际平台症状（已经复测）
- 仓库：`chenyu9512/StarlitChronicle-HD2D`，**私有**仓库（GitHub REST 元数据）。
- 多个工作流（Godot Core、Battle Animation、Desktop Preview）立即 `failure`，作业记录显示 `runner_id=0`，`steps=[]`；没有 checkout、Godot、Python 或其他步骤开始。
- 战斗工作流运行记录：`40195505702`，对失败任务执行了 `rerun_failed_workflow_run_jobs`，GitHub API 返回 success；**第二次 attempt仍然立即 failure，runner_id=0、0步骤**。
- 无法从这个症状推断是 GDScript 报错。当前没有任何真实 Godot 报错日志，不能宣称自动验收通过。
- 最近的 GitHub Status 曾报告 Actions 服务事故，但历史事故不能证明本次故障成因。

## 需要仓库账户所有者检查
1. 在 GitHub 的账户 **Settings → Billing and licensing → Usage / Budgets and alerts** 核对 Actions 当月私有仓库运行分钟、预算与硬性支出限额。若达上限，调整预算或等待下月额度；任何付费操作都只能由账户所有者自己批准。
2. 在仓库 **Settings → Actions → General** 核对 GitHub Actions 是否允许以及 runner 策略。检查组织/账户层是否禁用托管运行器。
3. 在 GitHub Status 查看 Actions 的当前公告，并在作业详情页面检查“workflow job was not acquired by runner”或账单相关错误提示。
4. 恢复后手动在 `Battle Animation and Audio Validation` 工作流页面点 **Run workflow**，或对 `40195505702` 重跑失败作业。必须出现非零 `runner_id`、执行的步骤和最终测试输出才算基础恢复。
5. 再运行 `Godot 4.7.2 Core Validation` 与地图、序章和桌面预览工作流，不可用战斗专项的成功代替整体验收。

## 代码层已做的运行分钟优化
- 战斗工作流新增 **concurrency**：按分支保留最新版、取消旧的待验证战斗作业，减少频繁提交的重复构建。不能修复已经停用或额度耗尽的账号托管运行器。

## A16 实际已提交功能
- 4套六帧 **角色动作特效图集**：攻击、防御、治疗/聚星、受击（独立于角色本体立绘）。
- 1套六帧 **Boss觉醒光纹** 和 1套四帧 **高阶魔法** 图集。
- `battle_actors.gd` 为已有每位人物独立挂载 `AtlasTexture`，动作按实际攻击/防御/施法/受伤计时切换六帧，低动态模式固定无快速闪烁帧。所有主角 B02 身份图片保持不变。
- `battle_boss_awakening.gd` 和 `first_act_battle.gd` 将六帧转场接入实际Boss血量低于一半、进入第二阶段的已有逻辑；不修改原第二阶段加攻与掉落。
- `battle_fx.gd` 在5级以上技能施法时叠加四帧元素染色，保留原来63技能个性签名和九属性绘画效果。
- `tools/smoke_a16_keyframes.gd` 检查Boss全部帧、角色四类动画、四帧高阶技能、低动态、过期资源清理、真实Boss层挂载和HP不变。
- `tools/capture_a15_battle.gd` 将截图从3张增加到4张，额外产出 `a16_boss_phase.png`；CI通过后在Actions Artifact下载，当前**未成功产出新截图**。

## 当前可确认与不可确认
GitHub源码路径/资源/实际动作触发的静态接线已检查、相关提交已推送 `main`。**Godot解析/实时渲染、截图内容、60 FPS、Windows与iPhone真机验收未通过本轮认证**。角色本体仍是原有立绘配合动作补间与逐帧特效，并非已重新绘制所有人物的全套分身动作帧。

请不要修改/覆盖主线、存档、Boss伤害与回合结算来规避验收。
