# 《星灯纪行》Main2 正式美术生产管线（2026-10-29）

## 唯一生成入口和分层

- 统一命令：`python tools/generate_art.py --project . --force`。入口仅转发到 `tools/global_art_factory_v3.py`，旧 44×28 演示生成器已清除。
- 现行高清2D程序化绘制依赖：`art_style_v8.py → art_style_v7.py → art_style_v6.py`。V5 已退役；V7/V6 仍是**实际依赖**，禁止按文件名误删。
- `tools/global_art_ai_provider_v3.py` 生成模型任务/候选美术，不会自动替代正式资产；`tools/hd2d_production_gate_v6.py` 管理模型画质检查与候选入库。
- 一键正式安装：`python tools/install_global_factory_v3.py --project . --no-prune`（不清理历史候选）或移除 `--no-prune` 使用带引用判断的旧资源清理。正式切换须核对校验、贴图与场景绑定。
- 其他独立输出：`generate_content_icons_v1.py`（图标）、`generate_boss_motion_v1.py`（Boss动作图集）、`generate_shore_waves_v1.py`（海浪）、`animate_coast_monsters.py`（旧海岸怪物动画）、`export_hd2d_svg.py`（SVG栅格化）、`compile_art_atlas_v2.gd`（辅助图集）、`bake_hd2d_normal_maps.gd`（受光法线）。这些职责与主生成器不同，不是可互换的重复脚本。

## 现有产出数量和规格

以 2026-10-29 的 Main2 提交为基线，已跟踪的生成输出：
- 全局工厂：451 项基本图像（包括地图42、V4室内153、角色12、NPC35、怪物63、Boss66、地区地形8、道具64、UI8）；
- 地区地面/水面派生图：16；受光法线图：401；全局工厂共 **868 PNG**；
- 内容图标：288；Boss动作图集：66；海浪动画表：8；四组共 **1,230 PNG**。

以 `assets/art/runtime/global_factory_v3/active.json` 的 `assets`、`normal_map_path`，以及 `data/assets/c_art_runtime_registry_v1.json` 核对资源引用。401张法线由 active 清单引用，**不是未使用缓存**。基于同一PNG Blob的V14/V18别名和不同室内ID必须先迁移引用，不得直接批量删除；Git已按相同Blob去重存储，删除其中一个路径不等于释放其全部文件字节。

## 清理规则

- 仅在 `Main2美术优化版` 清理和开发；不更改 `main`，不覆盖现有档案和玩家V3存档。
- `.gitignore` 排除本地构建、导出、备份、临时文件；不把无用构建产物提交进正式Git树。
- 使用 `python tools/audit_legacy_cleanup.py --json` 查无用旧文件、重复 Blob、有效入口和保留范围；该工具不擅自删除仍被动态路径引用的资源。
- 源原稿 / 候选 / 正式运行分层管理。图像文件存在或生成成功不代表已完成玩家画面、身份辨识度、商用质量签收；清理时不篡改这些验收状态。
