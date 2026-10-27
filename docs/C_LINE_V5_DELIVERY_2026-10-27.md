# 《星灯纪行》C线 V5 一次性美术库整理及DLC全局替换交付

日期：2026-10-27，仓库main-only直接执行；不建立分支、PR，不强推。最后一次发布SHA以GitHub main当前状态为准。

## 1. 目录优化（物理文件与引用分离）
| 阶段 | 位置 | 内容 | 结果 |
|---|---|---|---|
| 制作原档 | `assets/art/source_packs/` | 873个源文件，含756张不同图片、85个动画ZIP及原始元数据；重用Git blob，不重复上传字节 | 成功 |
| 候选素材 | `assets/art/candidates/manifest.json` | 756条来源路径、Git blob SHA、类别、用途及待适配说明，**无重复PNG** | 成功 |
| 正式运行 | `assets/art/runtime/manifest.json` | 101条优先正式路径引用，保留原项目res://路径与ID | 成功 |
| DLC主题 | `data/assets/c_art_packs.json` | 2套内置主题，共28条映射，支持本地用户外置DLC JSON | 成功 |

候选分配：390角色动画、35 Q版身份参考、238城镇装饰/图块、4等距布局参考、42前视怪物动作、47侧视怪物图；不将候选素材未经适配标为正式运行。

## 2. 去重及无效文件清理
- SHA核验：旧`external/imported`的660张PNG全部在原`备份区`拥有相同blob。
- 将`备份区`的857个有效非垃圾文件原样保留在`source_packs`，另外16个导入元信息文件存于`source_packs/import_metadata`。
- 删除旧`assets/art/external/imported/`子树（1336个原有文件：660图片、660 *.import及16元信息）；此前元信息已保留。
- 删除旧`assets/art/备份区/`子树（862个原有文件：857已逐SHA保留及5个无用的.dir/.url旁路文件）。
- 合计清理原有2198个重复或无用的路径；有用的正式运行图片、B02、B03、现有CC0原图没有删除。Git历史仍保留原提交，普通分支清理不缩减历史仓库存储。
- 重新统计结果以最新版main为准，其他开发线会继续新增美术，不能把其提交计入C线去重。

## 3. 一键全局画风/DLC系统
- 在`scripts/c_art_overrides.gd`新增：
  - 内置及安装的主题映射；
  - `list_packs()`、`active_pack()`、`activate_pack(id)`；
  - `install_pack(json_path)`：本地DLC JSON与相对图片导入，验证目标slot、PNG/JPEG/WebP和尺寸，安装到`user://c_art_packs`；失败保持原版；
  - `uninstall_pack(id)`：卸载用户安装主题，不删除内置资源；
  - `restore_everything()`：一键恢复所有原图，清空个人单图覆盖并关闭主题，保留个人备注和已安装的DLC；
  - 优先级：单图用户覆盖 > 当前主题映射 > 官方原版；未知/损坏资源回退原图；缓存修订驱动地图图集重载。
- 首页`scripts/c_art_manager_ui.gd`新增“全局主题包/DLC”选择、一键应用、一键恢复全部原始美术、导入DLC与卸载DLC按钮。
- `scripts/rpg_menu.gd`角色头像、`scripts/first_act_world.gd`任务场景道具改用C Art Resolver；原有世界地表、建筑、室内、怪物及标题等通过现有C Resolver加载。
- 内置`b02_illustrated`12条角色肖像/战斗/对话映射；`coast_ink`16条地表SVG、岸边布景和背景映射。
- 安装外部DLC清单示例：`docs/examples/c_art_dlc_manifest.example.json`；要求将其`file`所列图片放在清单所在目录的相对路径。选择清单导入后，在首页选中并点击“一键应用”。
- 一次全局应用仅覆盖**主题包内显式映射的游戏资源ID**；未适配的756张候选不会自动进入正式场景，也不改变剧情、地图碰撞与进度。
- 已建立`data/assets/c_art_allocation_v5.json`，将主角、NPC、Boss、怪物、地图、城镇、UI、道具按最合适来源分配。

## 4. 测试状态（仅使用成功/未测试）
| 验证 | 状态 |
|---|---|
| GitHub树：旧重复目录不存在 | 成功 |
| 756条候选来源路径有效 | 成功 |
| 101条正式运行清单路径有效 | 成功 |
| 28条内置DLC来源与目标路径有效 | 成功 |
| 三份关键GDScript的括号结构静态检查 | 成功 |
| Python `tools/validate_c_art_pipeline_v5.py` 真实执行 | 未测试 |
| Godot `tools/smoke_c_art_packs.gd` 专项测试 | 未测试 |
| Godot正式编辑器启动、全部场景回归 | 未测试 |
| DLC导入、卸载、恢复的Windows设备体验 | 未测试 |
| 40地图/97室内真实游戏画面验收 | 未测试 |

未实际生成或采集Godot游戏截图；不得宣称商业级美术已经全部完成。无Godot 4.7.2本地可执行文件，故不捏造测试通过。

### 集中验证命令
```bash
python tools/validate_c_art_pipeline_v5.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_art_packs.gd
godot --headless --path . --script res://tools/smoke_c_art_overrides.gd
godot --headless --path . --script res://tools/smoke_town_entrances.gd
```

## 5. 未完成与D线交接
- 目前新增的两套主题是可以批量切换的映射功能，并不是完整的高品质新美术；DLC只替换显式目标ID。要覆盖63怪物、66 Boss、40张地图，还需实际绘制/适配每个资源和动画。
- 现有某些旧代码仍直接调用`load(texture_path)`或处理资源不经过CArtOverrides，不能保证所有画面瞬时热切换。切换主题后重新进入场景；缓存不直接改变已经生成的Node2D/TileMapLayer。
- 直接往`source_packs`添加外部图片只会成为制作原档；不会自动绑定游戏。候选清单必须人工按身份/地图/动作选择，不允许改变正式剧情、任务、保存格式。
- D线后续可将统一`ArtOverrides.revision()`广播至全部已建立的场景节点，做无需重进地图的热更新；同时跑40地图及97室内完整回归并截图验收。
