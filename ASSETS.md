# Assets and licensing

**Licence.** The project's original source code (GDScript, shaders, tools) is licensed under the MIT License (see `LICENSE`).
The project's own procedural and synthesised content described below is distributed under the same MIT terms unless a file states otherwise.
The MIT licence does **not** extend to any third-party material; this project aims to contain none (see "Third-party material").

## Origin of the main assets

| Asset | Origin |
|---|---|
| 3D world: terrain, roads, bridges, buildings, props | Generated at runtime by code (`terrain_builder.gd`, `world_generator.gd`, `scripts/world/*`). |
| Textures and materials | Procedural PSX-style materials generated in code (`scripts/psx/*`). |
| Characters: hero, NPCs, enemies, bosses, horse | Assembled in code from primitive shapes (`scripts/player/hero_rig.gd`, `scripts/world/humanoid_kit.gd`, `humanoid_anim.gd`, `horse_system.gd`) and animated procedurally. No external models or animation clips are used. |
| Faces | Procedural (`scripts/world/face_kit.gd`). |
| Sound effects, ambience, all music (including `music_menu.wav`, `music_prologue.wav`, `music_finale.wav`, boss and mass-battle themes) | Synthesised offline by `tools/audio_synth.gd` (pure GDScript DSP). Regenerate with `godot --headless --path . -s res://tools/audio_synth.gd`. |
| `assets/menu_bg.png`, `docs/screenshots/*`, `docs/img/*` | Screenshots captured from this game. |
| `icon.svg`, `docs/favicon.svg` | Drawn for this project. |

## Third-party material
- The Godot Engine (MIT licence) is used to run and export the game. Its licence applies to the engine and export templates.
- No third-party models, textures, animations, fonts or audio clips are included in this repository.
- Earlier development versions used Adobe Mixamo character files and a few audio/image files of unrecorded origin. They were replaced by the project's own procedural/synthesised content and are not part of the published history.

## Note on build files
The Windows executable is a compiled build of this repository and is published only through GitHub Releases, not stored in the git history.
