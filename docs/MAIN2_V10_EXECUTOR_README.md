# Main2 V10 · 统一美术生成器

唯一推荐入口（统一美术生成器、安全升级版）：

```powershell
py tools/generate_art.py --project .
```

实现模块位于 `tools/art_pipeline.py`，旧根目录 V10 脚本仅作为临时兼容转发层保留，不再维护两份生成实现。

保留原始执行器文件名：

```powershell
py tools/generate_art.py --project .
```

只校验现有正式资源（不修改）：

```powershell
py tools/generate_art.py --project . --verify-only
```

仅预览待清理旧文件：

```powershell
py tools/generate_art.py --project . --cleanup-only --cleanup-dry-run
```

用已经人工核对身份、画质的完整模型包生成：

```powershell
py tools/generate_art.py --project . --refined --model-source build/starlit_hd2d_studio_v9/refined_models
```

V9 负责绘制 451 个核心美术槽位，安装前自动转换到现有 Godot V4.2 正式合同：401 张法线贴图、16 张地面与水面 atlas，逐一验证 PNG、SHA256 与路径，之后再完成原子替换与唯一登记表同步。V10 另外补齐并核实 109 个正式语义槽及 7 个 UI 图标。

原始上传脚本的清理算法可能误删动态路径引用的正常贴图、动作与法线图。新脚本只处理 retired / obsolete / legacy_generated 明确废弃目录里，经注册表和实际脚本检查均未使用的文件；其他运行资源一律保留。备份在 build/starlit_v10_cleanup_backups 中。

旧 CI 命令 python tools/generate_art.py --project . --force 仍保留兼容模式，只生成不发布的 V3 候选素材。程序美术生成成功不等于通过 Godot 实机验证或商业级画质验收。
