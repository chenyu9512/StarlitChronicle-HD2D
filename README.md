# 星灯纪行 · Main2 游戏运行精简版

> 运行分支：`Main2游戏运行精简版`。源自 `Main2美术优化版` 的提交 `8e3a5871fdedea5b42e8338f7577bddc84c27ad4`。
> 本分支不是全部原档或美术制作分支；**不包含** `assets/art/source_packs/`。
> 保留全部正式 GDScript、Godot 场景、剧情 JSON、数值与地图数据、导出配置及游戏内可加载的图像、着色器。

## 已保留的美术

- `assets/art/external/cc0_named_v1/`：正在被美术迁移、角色四方向动画、地图、UI 等使用的第三方运行图片。
- `assets/art/runtime/act01_global_v14/props/`：10 类第一幕世界道具。
- `assets/art/runtime/act01_global_v14/scenery/`：6 类第一幕场景美术（含灯塔）。
- `assets/art/runtime/act01_global_v14/monsters/`：9 类海岸普通怪物。
- `assets/art/runtime/imported/librarium/`：2 张实际接线的故事 Boss 帧图。
- `assets/art/b02/`、`assets/art/b03/`：游戏加载的角色/Boss 元数据；`assets/art/runtime/manifest.json` 等兼容性文件。
- `assets/shaders/`、`assets/audio/`：当前项目提供的着色器和音频登记。

## 没有拷进来的文件

全部制作原始包、DragonBones/MV ZIP、1748 张静态 Boss 原图、候选美术库、20 张仅作为 V14 预览或备用的图、素材上传缓存与大批开发报告。原档继续保存在 `Main2美术优化版`，不受此分支影响。

本分支的 `data/assets/c_act01_global_distribution_v14.json` 改成仅记录真实入库的 25 个接线图，避免旧索引继续声称 3534 份原始文件存在。

## 运行和测试

安装 Godot 4.7.2，直接打开项目根目录 `project.godot`。运行入口 `scenes/first_act.tscn`。
本分支推送会自动执行 Godot 全项目解析、六章世界构建、美术贴图载入与首幕基础战斗回归。
商业级画面审核和第 2/4/5 章独立场景完善依然是未完成工作，不因为精简分支创建而自动通过。
