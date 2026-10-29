# Starlit Chronicle / 星灯纪行 — Game Core, No Art Images

**Derived from:** `Main2美术优化版` by automatic non-image source synchronization; inspect the latest `sync(core)` commit message for the exact source commit.
**Branch:** `Main2-GameCore-NoArt`.
**Synchronization status:** Source revisions change frequently. The latest `sync(core): mirror Main2 non-art game files at <SHA>` commit records the exact source snapshot; do not treat this README's own modification commit as a new game-code sync. The verification script checks the artwork-free working tree.

## Preserved
- Full Godot project source, scenes, game scripts, battle/quest/NPC/story logic, maps and their collision/geography data, save system, project/export settings, shaders, tests, and source-code documentation.
- Art-related JSON/CSV/Markdown descriptors and manifest paths are retained for later matching and re-import. These are **text metadata, not actual image resources**.
- The current automated core mirror also retains `addons/starlit_art_pipeline/` editor **code**; this does not contain game artwork. The code requires external art to display a completed game, and is not an independent downloadable replacement application.
- Non-art audio/shader directories as found in the parent revision.

## Removed from the latest tree
- All runtime sprites, battle portraits, backgrounds, terrains, tileset textures and UI art inside `assets/art/`.
- Named third-party image libraries and all artwork source packs (including their image archives).
- No blank PNG, SVG or proxy art files have been added.

## Intended use
This is a **code/data skeleton for continued game development**, not a ready-to-play visual build. Existing path references still point to art removed from this branch; loading art-dependent scenes or running art-availability validators can fail until appropriate resources are reattached. Logic, coordinates, quest IDs and gameplay data have **not** been rewritten or reset.

**Main2 and main remain unchanged.** This is not the curated playable Runtime release branch.

## Verify the current checkout
```bash
python3 tools/verify_game_core_no_art.py
```

Note: This branch's *tip* contains no image assets, but its Git ancestry still contains historical art objects. For a light local checkout use GitHub's Download ZIP for this branch or:

```bash
git clone --depth 1 --single-branch --branch Main2-GameCore-NoArt https://github.com/chenyu9512/StarlitChronicle-HD2D.git
```

A full clone of repository history can still transfer past art blobs.
