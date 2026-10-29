# C-line / Morning Dew Village -- movement and town audiovisual implementation

Date: 2026-10-26. Source-of-truth implementation records: `data/assets/c_town_motion_matrix.json`.

## Changes that run today
- `first_act_actor.gd` still implements `setup(image)`, `set_motion(delta, velocity)`, and `react()`. It now drives a direction/state controller, shows stop/turn/idle movement feedback, and plays a small original synthesized footfall when actual movement advances.
- Logical eight-way headings map onto the four genuinely existing atlas directions, with no generated fake diagonal frames. An independently authored eight-way character atlas is **not** present.
- `world_npc_visual.gd` gives role-specific motion/life gestures to silhouette citizens, keeps approved B02 static portraits distinct from animations, and aims the visual toward a nearby party member. `face_player` and `end_conversation` are available to the existing dialogue integration.
- `world_structure.gd` retains the existing collision footprint and facade rendering, adds proximity-triggered visual door open/close, door Foley, banner sway, and smith chimney smoke. It does not grant entrance permission or modify quests.
- `world_interior_art.gd` retains V4 room geometry, furniture and light occluders. It now generates a distinct original room soundscape and exposes `play_prop_action()` / `show_interaction()` to the scene event integrator. The inn has an authored six-frame fireplace from the previous batch; we do not claim to have authored replacement frames.
- `c_town_soundscape.gd` has indoor room profiles and procedural fallback Foley, with two-player volume crossfades. Real BGM, voice, door recordings and high-quality ambience are still missing.
- `world_ambience.gd` now offers a reduced-motion update mode. No collision or authoritative time changes.

## Player-facing scope and integration limits
Morning Dew Village `map_coast_01` is the intended first sample. Automatic presentation uses actor set_motion, NPC _process, interior install, and building setup without editing B or D world controllers. Explicit dialogue-start, chest state, house exit transition and BGM changes are not newly wired into the B/D event producers: call these C-only methods when D synchronizes events. Visual chest opening is a drawn feedback overlay **not** a gameplay chest item grant.

## Asset/acceptance status
The coast inn illustration and 5 other village interior room JSON files exist, but none is signed off as commercial-ready. Exterior structures beyond authored coast facades still fall back to procedural illustration. Existing B02 full-body NPC stills remain **stills**. Original procedural audio has no third-party redistribution exposure; future uploaded external assets need separate terms/attribution review. No Godot run, iOS playback, visual art review, or listening QA claimed.

## Deferred unified QA
```sh
godot --headless --path . --script res://tools/smoke_c_character_motion.gd
godot --headless --path . --script res://tools/smoke_c_town_presentation.gd
godot --headless --path . --script res://tools/smoke_town_life.gd
godot --headless --path . --script res://tools/smoke_coastal_interiors.gd
```
Tests deliberately remain out of GitHub Actions until the three-line integration batch.
