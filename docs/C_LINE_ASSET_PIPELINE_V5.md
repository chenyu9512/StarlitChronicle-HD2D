# 《星灯纪行》C线美术资产V5实施方案（main-only）
基线：2026-10-27。审计旧main baba(e441)时：2603张全部assets图片，其中原有1187张、新增1416张；660个external/imported PNG与备份区SHA完全重复，备份区另有96张非重复PNG。进一步写操作以每次最新main及compare-and-swap验证为准。
## 目录结构
1. `assets/art/source_packs/`：制作原档（来自原备份区的完整素材文件、Animation Source、压缩包、元信息）。只留一份二进制。
2. `assets/art/candidates/`：仅用JSON保存候选图片的分类、目标用途、源档blob及需要的审查，不克隆二进制；禁止直接绑定地图。
3. `assets/art/runtime/`：通过清单记录保留现有正式路径的资源，原来 `assets/art/b02`、`assets/art/b03`、`assets/art/exteriors` 等不移动，避免破坏已有res:// ID。此目录作为运行契约/映射而非另存一次贴图。
4. `data/assets/c_art_packs.json`：DLC风格主题索引；内置B02人物与海岸纹理主题；新增用户导入PNG主题安装到user://并可整体切换。
## 替换优先级
单张本机覆盖 > 当前主题包同ID映射 > 原始`res://`运行资源。切换主题只写`user://`配置，失败不写入；所有程序化道路、地图碰撞、任务、战斗逻辑与存档不受影响。所有正式贴图必须通过`CArtOverrides.texture(path)`或`world_tileset_pool.shared()`加载，未改接的资源只能恢复原版，不能承诺全局热切换。
## 去重策略
对Git树blob SHA完全相等者，只保留制作原档，删除重复的`external/imported`文件与成对`.import`文件；独特的Aekashics原图和嵌套动画ZIP保留。原始许可/README及映射JSON若独特则进入source_packs元数据索引，不做未经核对的图片删除。逐SHA列出删除数量、保存位置及其Git SHA。
## 验收
静态路径、资源引用、pack config约束、README、回退、覆盖优先级、动态地图缓存失效；Godot专项测试和游戏截图尚需运行。状态仅`成功`或`未测试`。未经真实截图不宣称商业级画面验收。
