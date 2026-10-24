# 星灯纪行｜全游戏资源设计数据库 v0.2
本次建立可被 Godot 4 直接读取的离线、版本化 JSON 图鉴，完整建模世界设定及各类资源的首轮目录，并非已经完成正式 PNG/战斗/地图。
## 内容数量
- regions：8
- characters：12
- npcs：40
- maps：42
- items：90
- weapons：81
- armor：54
- skills：63
- monsters：63
- bosses：12
- quests：84
## 设计约束
- 世界「洛维恩」：现世、映世、岁影回廊；七座母灯、寂潮、万灯永昼。
- 六大主要地域、天轨圣域及十二年后建立的群灯之城。72 条主线任务与另一剧情分支 PR #1 的正式 72 章标题、剧情摘要、章节事件标志同步；该分支包含第一轮对白文本，但本分支尚无正式地图触发器。
- 稳定 ASCII ID；跨类引用以 ID 关联；所有 JSON 均有 category / entries 与 manifest 中相同的 schema。
- sprite_key、portrait_key、icon_key、fx_key 等是资源需求键，不代表这些图片文件已存在；art_status:not_produced 明确标记未完成。
- 旧版「晨露村」「星落遗迹」为试玩关卡，状态 playable，真实路径指向 res://data/village.json 与 res://data/ruins.json。其他 scene_path 为 null，不可调用旧世界场景直接载入。
- 旧版可存档角色「黎昂」「澪」仍留在 game_state.gd，不擅自替换为正式灯行者/岚音，不升级存档协议。
- 旧原型敌人 PNG 只作为 monster.preview_fallback 供将来占位，不能当作原创正式怪物立绘。
## 数据使用
在 Godot 内通过 `const Catalog = preload("res://scripts/content_db.gd")`，再用 `Catalog.load_entries("monsters")`，`Catalog.lookup("items","item_herb_01")` 读取。
菜单增加「星灯图鉴」查看数据库分类，纯只读，不影响战斗或存档。
运行 `python tools/validate_content.py` 检查主键、外键、总数及文件路径。仍需 Godot 编辑器编译与 iPhone 实机验证。
## HD-2D 美术规范与下一批优先级
基础图块 32x32；步行动画维持旧版 3x4 张 96x192 的帧约定；每位角色另设战斗立绘、表情与武器显示层；怪物按小/中/大体型制作独立透明 PNG，并提供光影、攻击、受伤动画。不使用任何第三方游戏 IP 的角色、音频或贴图。
第一批应生产：黎昂与岚音 4 方向/角色动画、晨露村（正式版）图块、白砂海岸 9 种正式怪物、第一幕 BOSS 候选、前 9 把武器及药品图标，并逐一配对逻辑资源键。

## 正典同步（PR #1）
七母灯名称固定为「潮歌、律序、炉心、风航、镜眠、根忆、天衡」。主角默认名黎昂，可自定义；岚音为药师，朔弦为领航员，伊泽为吟游者；诺依第七幕以孩童登场，第九幕十二年后成为成年主角，维莎第58章正式入队；赤烬将军名称「库洛萨」。群灯之城另建第八个地域节点但 **不是第八座母灯**。

主线 72 条任务已由 `content/full-story-v1` 的 `act_01..act_12` 实际章节源同步标题、地点、摘要、`ch001..ch072` ID、剧本引用、章结束旗标。源文件位于 [独立 PR #1](https://github.com/chenyu9512/StarlitChronicle-HD2D/pull/1)，尚未合并至本分支；运行主游戏不会自动进入这些章节。

本数据库独立的 12 个 BOSS 方案当前标记为 `design_candidate`，并未擅自绑定到正式剧本。武器、装备、道具与怪物条目也是资源设计及初版参数，后续应基于实战重新平衡。
