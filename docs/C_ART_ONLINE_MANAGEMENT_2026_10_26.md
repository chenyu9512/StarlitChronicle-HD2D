# C线在线美术目录与管理核对 | 2026-10-26

核对基线：`eff089e1c762275ef2bc7d1b25675e45fcfb63dd`，只读Git树确认图片/SVG共 **1,178** 项，约 **77.2 MB**。在线`assets/art/external/imported/`尚不存在，不能将Windows本地分配器的4,831条记录当作GitHub资产。

## 当前唯一管理链
1. `data/assets/c_art_catalog.json`：首页和开发画廊共用的**唯一可浏览图片清单**，完整1,178项、21类。
2. `data/assets/c_art_selection.json`：101项晨露村优先 / 410核心备用 / 667外部候选；属于**制作优先级**，不是逐项运行验收。
3. `data/assets/external_cc0_named_index.json`：实际存在的667份外部候选的来源、历史哈希与许可声明，不负责游戏场景载入。旧版索引有807项，其中140个已删Kenney UI double路径；已修复。
4. `scripts/c_art_overrides.gd`：本机 `user://` 映射，正式`res://`图片只读，游戏数据和替换配置分离。
5. `scripts/c_art_manager_ui.gd`：首页分类/搜索/缩略图/本地替换/恢复；增加提醒：外部候选未绑定，不表示游戏会自动显示。
6. `scripts/art_gallery.gd`：独立开发画廊统一从首页目录读取，不再另行拼接B02/B03索引。

## 本轮整理
- 将旧外部索引中的140条不存在的Kenney double候选记录剔除，保留667条存在的正式候选及其source pack数据。
- 删除7张旧样例的过时staging索引，以及3份已删除PixelKensei旧路径的上传清单；其3个Zip SHA-256与来源/许可审查状态已经汇总进外部来源索引。本轮**未删除任何图片**，也未复制素材备份。
- 新增 `tools/validate_c_art_management.py` 对目录、优先级、外部索引和仓库实际图片作交叉检查。

## 仍有的现实边界
- B02静态肖像不等于行走动画；B03的5张Boss静态图不等于完整攻击帧。
- 外部像素素材尚未自动绑定到晨露村、战斗、NPC和UI；不得仅凭目录计数认定游戏已使用。
- 素材标注CC0等许可，源于已有说明，**未独立核验公开再分发权**。
- 本次没有实际运行Godot 4.7.2解析、动画、缩略图交互、性能、存档或结算测试。不能据此保证零问题。

下一轮验收：`python tools/validate_c_art_management.py`、`python tools/validate_c_art_catalog.py`、`godot --headless --path . --script res://tools/smoke_c_art_overrides.gd`，然后现场核对首页替换和前三章。
