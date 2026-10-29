# 游戏主体无美术分支自动同步

**源分支：** `Main2美术优化版`。
**目标分支：** `Main2-GameCore-NoArt`。

工作流：`.github/workflows/main2-game-core-no-art-sync.yml`。

## 何时同步
- Main2每次提交游戏主体文件时自动触发，无需每5分钟轮询。提供手动 `workflow_dispatch` 备用。
- 多个更新排队顺序执行，每次读取源分支**最新HEAD**，避免旧事件将新代码覆盖。
- 只在目标分支有代码或数据差异时提交；图片单独更新不会产生新的核心分支提交。

## 精确同步范围
- 同步全部非图片的游戏主体：`scripts/`, `scenes/`, `data/`, `story/`, `tools/`, `docs/`, `project.godot`, `export_presets.cfg`, 音频及shader。
- `assets/art/` 只允许 `.json/.csv/.md/.txt/.gdignore` 的索引及语义配置；排除全部 `source_packs/`, `external/`。
- 在任何目录都禁止图片后缀（PNG/SVG/JPG/WebP等）及素材压缩包，以防后续出现新目录时泄漏美术。
- 目标特有的 `README_GAME_CORE_NO_ART.md`、`tools/verify_game_core_no_art.py` 与现有 `.github/` 工作流原样保留，不被源分支覆盖。

## 安全和效果
- 基于 GitHub Git Trees API 的SHA差异更新：不检出、下载或者复制任何图片；无需重新推送Git历史。
- **只更新现有目标分支**，绝不操作 `main`、Runtime或源Main2文件；不创建PR、不开新分支、不强制推送。
- 缺少必要游戏源文件、Git tree被截断、检查到图片或合并冲突时直接失败并保留目标现状。
- 同步保留图像资源的路径/ID引用作为游戏设计契约，目标无任何图像文件；不能当作有画面的可玩发行包。
- Git历史仍可能包含过去的图片，下载最新工作树时使用ZIP或 shallow clone。

## 同步验证
GitHub Actions的同步记录将输出源SHA、目标SHA、修改文件数和被复制图片数（必须0）。检出新分支后执行：
```bash
python3 tools/verify_game_core_no_art.py
```
