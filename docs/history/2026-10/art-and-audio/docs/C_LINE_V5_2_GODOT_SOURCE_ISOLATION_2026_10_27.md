# 《星灯纪行》C线 V5.2 · 制作原档与候选资源的引擎隔离

日期：2026-10-27；直接在main执行，不建分支/PR。

- `assets/art/source_packs/.gdignore`：禁止Godot把853份制作原档（约218MB源数据，实际体积以仓库为准）当作运行资源导入或打包。
- `assets/art/candidates/.gdignore`：候选清单只供Python和GitHub静态管理；不会被误当作游戏资源。
- `assets/art/runtime/` 未忽略，101项优先运行契约以及B02/B03/战斗、世界与UI的现有资源路径均保留。
- 全局`data/assets/c_art_catalog.json`的1240个可管理槽位没有指向被忽略目录。原档和候选能通过文件系统/Python工具获取，但**不再能通过Godot load()/preload()直接加载**，需要正式投放到运行路径或安装为DLC。
- `export_presets.cfg`沿用原有多平台设置；不动A/B/D线。
- 依据Godot关于`.gdignore`的规范，将制作原档从Godot文件扫描/导出中隔离，目标是减少编辑器导入负担和发行包尺寸，真实缩减值必须以Godot导出为准。

## 测试（仅“成功/未测试”）
- 树和候选/原档阶段的静态路径一致性：成功。
- 1240个美术管理槽位无忽略目录引用：成功。
- V5.2的Godot导入速度、PCK体积与平台打包对比：未测试。
- 40地图/97室内完整画面及DLC替换：未测试。
