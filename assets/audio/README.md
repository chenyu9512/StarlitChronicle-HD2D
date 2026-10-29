# C-line audiovisual resource and rights staging

No external audio files have been acquired, licensed, imported, or validated in this change.
Put media under `assets/audio/` only after an owner confirms provenance and commercial redistribution permission. Add its hash, author, source, license evidence and dated review to `data/assets/av_registry.json`; `asset_path` must remain empty until the file really exists. Repository visibility is not permission to redistribute third-party assets.

The legacy combat and cinematic sounds are original procedural PCM generated at runtime, not authored BGM masters; they are explicit fallbacks. Static portraits and 5 static Boss images are not sprite animation. Do not turn any missing entry into `qa_passed` without Godot import, game binding, artistic review and iPhone device playback. Do not overwrite existing finished artwork with placeholders.

Run `python3 tools/validate_av_assets.py --json` to audit canonical IDs, available static asset headers and path coverage. This is not a listening or visual acceptance test. A/B event producers should bind by the `event_bridge` IDs only in the shared integration stage.
