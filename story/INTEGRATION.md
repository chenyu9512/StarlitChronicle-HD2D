# 在Godot主游戏中接入剧情状态机

当前已提供 `StoryCatalog` 只读查询层、`StoryRuntime` 可选任务流程层和 `StoryPreview` 独立预览场景。

## 推荐接入步骤（未来独立提交）
1. 不修改旧版 `State.SAVE_VERSION=1` 结构。新版本制作存档迁移器，将主角黎昂与同伴澪的旧资料映射到玩家主角与岚音的正式正典。
2. 在 `game.gd` 创建 `StoryRuntime` 子节点，连接 `dialogue_opened` 以显示对白，连接 `objective_changed` 以更新任务日志，连接 `choice_requested` 打开选项窗口。
3. 在地图互动 `_handle_interaction(kind,payload)` 中，把正式关卡 `payload.story_target` 传入 `complete_objective(target)`；不要把地图位置写死在故事JSON。
4. `battle_requested` 信号带 `enemy_id`，等待正式战斗数据库创建相应敌人配置。战斗结束必须调用 `report_battle_result(victory)`；结局71章需设置 `ch071.battle_won`。
5. 奖励仅在 `reward_granted` 信号发生时交由正式装备/金币系统处理，不能重复领取；章节完成后保存状态。
6. `world.black_star` 为灾后世界开关；`world.years_passed` 记录十二年时间跨越；`world.distributed_network` 与 `world.seven_lanterns` 根据对应章节结算写入。
7. 支线必须先由任务系统检查完三个阶段目标，才调用 `complete_side_quest(quest_id)`；全部十二张航页完成后会写入 `world.all_twelve_pages`。
8. 在选择结局前调用 `StoryCatalog.can_unlock_ending(id, flags)` 检查条件，并将结局选项展示给玩家。
9. 全部当前章节中的 `location`、`target` 只是内容稳定ID。新的地图、NPC实体、事件触发器、物品和镜头需要另行落地。预览场景不会虚构这些功能已经完成。

## 运行时例子（示意，需接入主游戏现有UI）
```gdscript
const StoryRuntimeScript = preload("res://scripts/story_runtime.gd")
var story

func _ready() -> void:
    story = StoryRuntimeScript.new()
    add_child(story)
    story.dialogue_opened.connect(_on_story_line)
    story.objective_changed.connect(_on_story_objective)
    story.battle_requested.connect(_on_story_battle)
    story.begin_prologue()

func _on_story_line(line: Dictionary) -> void:
    print(str(line.get("speaker", "")), "：", str(line.get("text", "")))

func _on_story_objective(objective: Dictionary) -> void:
    print("目标:", objective)

func _on_story_battle(encounter: Dictionary) -> void:
    print("战斗待实现:", encounter.get("enemy_id"))
```

这是一个可嵌入的逻辑框架，而非“已将72章地图与战斗接进现有两图原型”的承诺。

## 已知待办
- 章首检查与旧存档V2迁移。
- `scene.trigger` 的空间坐标绑定。
- 任务目标对NPC、道具、地图点位的注册和实时高亮。
- 按世界时间与选项旗标分支的NPC不同口径对白。
- 剧情镜头/表情/立绘以及复杂Boss的数值和行为树。
- 完整章节逐场对白扩写与专业润色。