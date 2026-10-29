# Main2 全库版本命名与清理规则

本文件只管理**现行命名与兼容契约**，不替代 `docs/history/` 中的历史记录。唯一开发入口为 `Main2美术优化版`，不修改 `main`，不建 PR，也不改写 Git 历史。

## 现行规范

- **引擎**：Godot 4.7.2 是引擎依赖版本，不得清除或随意改写。
- **统一美术入口**：`python tools/generate_art.py`，核心实现文件 `tools/art_pipeline.py`；旧根目录 `main2_merge_regen_replace_cleanup_v10.py` 只保留短兼容转发层。内部 V6/V7/V8 绘图层以及 V7/V8/V9 工作室模块目前存在真实导入依赖；在依赖迁移并测试前，不删除旧模块。
- **V10**：全局生成与空缺补齐的现行管线代次；V10 不意味着其他领域已经同步到 V10。
- **V3 地图 / V4 室内**：序列化数据规范与存档兼容，不按“旧版本垃圾”处理。
- **V1 运行资源/索引**：可能是独立资源包的第一版，不与全局开发版本相比较。
- **剧情 v21、艺术配置 v18、流程 v12 等**：子系统 schema / 交付版本，不等于可互相替换的程序版本。
- **脚本与工作流名称**：后续改为描述职能的稳定名称；版本号移到 JSON 的 `schema_version` / `generator_version`、Git commit、发行标签中。迁移必须同时更新调用方、CI、导入链、资源清单及测试。
- **备份、临时、非标准导出附件**：禁止提交 `*.bak`、`*.tmp`、`*.translation`、`*.pyc` 等。审计 CSV/JSON 保留为真实记录。
- **清理方式**：先核对实际 blob SHA、调用关系、动态资源路径、Godot import 与存档兼容，再删除；相同 SHA 不等于可以删除文件路径。

## Git 引用清点（2026-10-29）

在线仓库有 4 个分支：`main`、`Main2美术优化版`、`StarlitChronicle-Runtime`、`Main2-GameCore-NoArt`。前 3 个有明确业务角色；`Main2-GameCore-NoArt` 是否仍要保留须先检查同步工作流使用情况，不能仅因名称旧就删除。

有 2 个历史标签：`archive-v0.1.1-before-core` 与 `archive-v0.2-before-first-act`。它们是恢复锚点，现阶段不删。GitHub Release 数为 0。审计脚本会读取本地已获取的分支和标签；对于未完整 fetch 的 clone，应以 GitHub 在线 API 结果为准。

## 全量版本清单

从项目根目录执行：

```sh
python tools/audit_version_hygiene.py --json --output build/version_audit.json
python tools/audit_version_hygiene.py --strict
```

报告覆盖 Git 跟踪文件、所有路径与可读源码/文档中的版本标记、已获取的分支与标签、按子系统的分组、逐个二进制重复 blob SHA、所有代码与工作流名称、源文件字面引用、临时残留和缺失文件。检查为只读操作，不会删正式美术或改存档。

## 2026-10-29 整理基线与遗留项

整理前所见一个 Main2 快照：约 2,671 个跟踪文件；59 组相同 Git blob、涉及 133 个文件路径；包含大量运行时美术别名。曾存在 `docs/audits/` 下无法作为 UTF-8 读取的 `*.translation` 附属导出文件，属清理对象。精确现值以运行脚本结果为准。

未完成的重构项目：
1. 绘图层 `art_style_v6/v7/v8` 与工作室 `hd2d_studio_v7/v8/v9` 仍有真实 Python 导入关系；不能未经功能测试一次性删除。
2. 已将根目录 V10 实现迁移到 `tools/art_pipeline.py` 并切换正式入口及 CI；旧命令暂存兼容转发层，需在完成本地调用与回归验收后删除。
3. `.github/workflows/` 下还有多个版本后缀的工作流；需逐一核查触发条件、权限、自动推送及相互覆盖，避免 CI 竞态。
4. `assets/art/runtime/`、`data/levels/v3,v4/`、`data/assets/` 有大量带版本字段的当前资源路径；需要整包资源迁移、重写注册表和实机验证，不可按字符串全局删除。
5. 相同 SHA 的图片、UI 图标与室内素材可能是正式 ID 的占位副本；需要美术质量补足与身份去重，不应仅靠文件哈希删除。
6. 未在此 GitHub 在线接口运行 Godot 4.7.2 的完整导入 / 实机回归。未测试的项目一律保持“未测试”。
