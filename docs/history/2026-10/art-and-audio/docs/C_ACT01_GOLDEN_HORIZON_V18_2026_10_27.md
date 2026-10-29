# 第一幕六章 Golden Horizon V18 场景材质接入

- Main2美术优化版 专用；main 不变。五张实体地图复用支持第一幕六章。
- 制作原档保留在 source_packs/ 并被 Godot 忽略。仅 27 张正式引用 PNG 使用原始 Git blob SHA 在 runtime/act01_hd2d_v18/ 复用，不重编码、不整包复制。
- 晨露村：市集、花围栏、村树、长椅。白砂港：货箱、木桶、船只、市场摊位。鲸骨浅滩：潮池、船骸、海岸岩壁。断桅海蚀洞：晶体、遗迹、岩架。潮歌灯塔：石崖遗迹、暖灯、旗帜、花围栏。
- 地面统一实际 Golden Horizon 地表 texture（沙、草、道路、木栈、海水及石壁）。维持 8×8×32 tile atlas 协议，不改道路、碰撞或存档。
- 高精度贴图只在安全路缘放置；建筑、真实门、剧情锚点、出口、主路附近避免形成无碰撞假障碍。
- Game entry: FirstActWorld -> CoastalScene.configure() -> CAct01HD2DDressing.configure()，以实图 Texture2D 显示。
- 验收：tools/smoke_c_act01_hd2d_v18.gd；Core、Full Smoke 与六章人工截图。画面尚未人工签收；特殊鲸骨地标、塔内、酒馆室内家具缺口仍需补绘。
