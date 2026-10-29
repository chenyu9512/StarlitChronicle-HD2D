# 星灯纪行 · Art Theme V2 — Main2 / 2026-10-28

V2 is an additive, semantic art-theme runtime integrated with existing scene loaders. Its baseline is **original**; `starlit_hd2d_act01` is **preview_pending_visual_qa**, not a commercial sign-off.

## Scope shipped in this commit

- `data/assets/art_theme_v2.json`: deterministic IDs, source paths, required gates, aliases, source provenance and stage.
- `scripts/c_art_theme_v2.gd`: read-only curated art resolver, preflight, one-click activation, cache invalidation, persistence and rollback.
- `scripts/c_art_overrides.gd`: prefer personal overrides then V2 curated themes; legacy DLC is bypassed when a V2 theme is active to prevent mixed styles.
- `scripts/c_act01_semantic_art_v17.gd`, `scripts/c_act01_global_art_v14.gd`, `scripts/world_interior_art.gd`: semantic scene consumers, with unchanged gameplay geometry and compatible fallback.
- `scripts/c_art_manager_ui.gd`: V2 preview picker and apply/restore actions; legacy custom PNG import remains available.
- `scripts/world_tileset_pool.gd`: correct cache revision and preserve already canonical 256x256 tilesets rather than repacking arbitrarily.
- `tools/validate_art_theme_v2.py` and `tools/smoke_c_art_theme_v2.gd`: real source and Godot texture tests.

### Explicit exclusions and release gate

This is **not** final art replacement of six chapters. PNG/SVG existence, Godot load success and deterministic source matching are prerequisites, not human visual approval. `assets/art/source_packs/` are never loaded into exported game scenes. Missing art will fall back; never remap a sign to a pond, temple wall to a home, or a single frame to a directional actor.

To extend a theme, add curated, importable runtime textures to `assets/art/runtime/`, register semantic IDs, verify collision/size and test visual screenshots. A theme is only release-approved when all six chapters' captures have a human signoff.

Run:
```bash
python3 tools/validate_art_theme_v2.py --json
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_art_theme_v2.gd
```

Main2 only; main is never merged or written here.

## Full user theme import and semantic atlas compilation

Prepare a folder containing exactly one bitmap per semantic ID (currently 89 slots), e.g. `prop.coast.sign.png`, `interior.tavern.tavern_counter.png`, etc. Every image must match the registered canvas dimensions. A partial set is **rejected rather than silently mixed** with the production art. Then run:

```bash
python3 tools/build_art_theme_dlc_v2.py /path/to/new_theme --id custom_sea --name "Custom Sea"
```

Open **美术资源管理 → 导入完整V2主题** and choose the generated `art_theme.json`. The game checks each image, copies bitmap-only payloads into `user://`, and makes the package selectable. It does not touch campaign saves or overwrite `res://`. All custom themes remain visual-QA pending.

A deterministic eight-row terrain texture can be compiled with:
```bash
godot --headless --path . --script res://tools/compile_art_atlas_v2.gd
```
The compiler uses explicit semantic material rows, writes to `build/art-theme-v2/`, and never auto-publishes an unreviewed atlas. This prevents accidental road-to-water or grass-to-wall reassignment.

`python3 tools/build_art_inventory_v2.py` creates a real tracked-file breakdown in `build/art-theme-v2/inventory.json`. ZIP internals are not counted until extracted and audited.

## Measurable sign-off vs asset count

`python3 tools/report_art_coverage_v2.py` writes `build/art-theme-v2/coverage.json`. It reports inventory, allocation states and semantic slots separately. Commercial completion remains `null` unless a human has approved actual scene screenshots. Runtime success alone is not enough.

Legacy atlas import no longer hashes or pseudo-randomly redistributes source cells. Full 8x8 source ordering is preserved; undersized atlas sources are rejected instead of inventing terrain. Existing terrain/surface role handling remains in `c_coherent_terrain_materials.gd` and the canonical TileSet pool.
