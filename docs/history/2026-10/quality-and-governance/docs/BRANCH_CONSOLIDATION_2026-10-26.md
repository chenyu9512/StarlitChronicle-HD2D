# 2026-10-26 全仓分支核对与选择性合并

本次合并遵循用户要求：**先核对全部分支，合并后测试，今后直接在 main 开发，不再创建分支。**

核对时共7个分支：
- `main` — cf4a8dcfb4b120aa274ba0cdd1ac51a72055afb6（合并前主线）
- `content/full-story-v1` — ddbc7abe5455ef0e1c97f1c0166c7458b9f24453（包含旧剧情/关卡和8份主线尚缺的文档）
- `feature/content-foundation-v0-2` — faaa29b42e9b6955def8cb3794fa57a2835cc0c6（包含44份主线尚缺的原创工程素材/参考文件）
- `fix/p0-save-integrity-20261026` — edc7917322039c7d02d23a6337578bbef9ed7268（存档、导航位置与批次验收更新）
- `chore/actions-history-audit-20261026` — 71a7c1b32c0a3568373dc5a125675204c6cdfb75（原 PR #9 已合并）
- `fix/ci-prologue-visual-qa-20261026` — 405bdd68daaae11ec19c0659210c4b82d0bedb51（原 PR #8 已合并）
- `fix/ci-phase19-npc-night-presentation-20261026` — 2cf147a689533ddfa256fc56e91726b13896c099（原 PR #7 已合并）

**合并决策：** 旧故事分支134个文件中91个与主线完全一致、35个已由主线更新；只补入8个缺失文档。旧美术分支256个文件中100个完全一致、111个主线已更新；只补入44个缺失文件。为防止回滚，35+111个同路径差异使用**主线版本**（其中少数为不同的制作源文件）；旧版本可从原 SHA 追溯。P0修复合入，但特意保留较新的 PR #7 任务 NPC 色彩修复、PR #8 过场元数据修复及场景捕捉规则。

将6个历史分支 SHA 同时记录为本次八十余项资源变更的 merge commit 祖先；这使 Git 可以追踪历史，同时不会把旧数据覆盖现代运行时。GitHub Actions 仅在本次合并写入批次触发标记后运行一次，测试成功才删除历史分支。
