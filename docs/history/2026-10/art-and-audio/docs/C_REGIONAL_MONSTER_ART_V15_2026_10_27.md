# Main2 · regional real monster-image integration V15

Branch: Main2美术优化版. No main changes.

Seven source PNGs from the Aekashics Librarium *Static Battlers / Frontview*
source library are reused by identical **Git blob SHA** under short, importable
gameplay paths. No massive PNG is copied into multiple per-map source archives.

| Monster ID | Original gameplay role | Actual source |
| --- | --- | --- |
| mon_oaths_01 | mon_oaths_01 species candidate | Frontview Batch Battlers/Forest Deer.png |
| mon_oaths_02 | mon_oaths_02 species candidate | Frontview Batch Battlers/Insects Bee.png |
| mon_forge_01 | mon_forge_01 species candidate | Frontview Batch Battlers/Insects Fire Ant.png |
| mon_forge_02 | mon_forge_02 species candidate | Frontview Batch Battlers/Fire Elemental Bat.png |
| mon_isles_02 | mon_isles_02 species candidate | Frontview Batch Battlers/Sea Jellyfish.png |
| mon_mirror_04 | mon_mirror_04 species candidate | Frontview Batch Battlers/Mushroom Shroomslinger.png |
| mon_oldland_01 | mon_oldland_01 species candidate | Frontview Batch Battlers/Insects Ant Lion.png |

Each is wired through scripts/c_art_regional_monsters_v15.gd and the existing
scripts/art_assets.gd battle_image() entrypoint, for ordinary monsters only.
Main2 V14 Act-I monster images remain first preference, and B03 chapter bosses
are NOT replaced. No new skills, encounters, damage, stats or save IDs are added.

This is a **static front-facing battle image** integration. File/semantic species
names and actual Godot texture loading must both pass; animation-frame, HD2D
rendering, final unique character identity and manual screenshots remain open.
The CI smoke tools/smoke_c_regional_monsters_v15.gd checks the actual image
import and the battle-image selector for all seven monster IDs.
