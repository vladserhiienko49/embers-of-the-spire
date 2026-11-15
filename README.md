# Embers of the Spire

A PS1-inspired dark fantasy action adventure built with Godot.

The lamps of the Ashen Lands are going out one by one. On the Black Mountain an Eye has opened, and the only map to its altar was torn into pieces long ago. Rebuild the atlas, gather the shards of the ancient Seal and climb the mountain.

- **Engine:** Godot 4.7.2 (Forward+), GDScript — standard build, no .NET
- **Style:** PS1 / PSX dark fantasy: low-poly world, pixelated rendering, dithering, vertex wobble, ash and torchlight
- **Platform:** developed and tested on Windows
- **Status:** playable preview, in active development

## Features

- A large open world of villages, ruins, a lake fortress, bridges and a mountain trail, with day and night, fog and weather
- Third-person (and first-person) action combat: sword, shield with timed parries, bow, stamina, armor and weapon upgrades
- A story with a multi-step main quest, mini-bosses, many side quests, shops and a finale
- A **torn atlas**: the map starts in pieces; bosses and trials guard the fragments and the final location stays hidden until it is rebuilt
- Special enemies and bosses: a skeletal witch who raises the dead from the ground, fast skirmishers, a bone warden, blinking seers, an Ancient Mage who changes tactics, and the final guardian
- Trials with different structures (waves, timed runic pillars, ritual obelisks, a closed arena, following a spirit, searching in fog)
- Mass battles with their own soundtrack, ambushes and random road events
- Horses: buy one, ride at walk, trot and gallop, first-person view in the saddle
- Interiors, cats, a card game, journal and inventory
- Fully procedural content: world, characters and animation are generated in code, and all music and sound effects are synthesised by the project's own tools

## Controls

| Action | Key |
|---|---|
| Move / sprint / jump | `WASD` / `Shift` / `Space` |
| Attack | Left mouse button |
| Shield / parry | `Q` |
| Draw or sheathe sword | `R` |
| Bow | `B` |
| Interact | `E` |
| Torch / lantern | `F` |
| First / third person view | `V` |
| Journal / map / inventory | `J` / `M` / `I` |
| Whistle for horse (when owned) | `H` |
| Pause | `Esc` |

Riding: `W` trot, `Ctrl+W` walk, `Shift` gallop (tires the horse), `E` dismount.

## Open the project in Godot

1. Install **Godot 4.7.2** (standard build).
2. Clone this repository and open `project.godot` in the Godot project manager.
3. Let Godot import the assets on first open.

## Run

Press **F5** in the editor. The first launch generates the terrain and caches it in the user data folder, so later launches are faster.

## Export a Windows build

Install the Godot 4.7.2 export templates, then:

```bash
godot --headless --path . --export-release "Windows Desktop" build/EmbersOfTheSpire.exe
```

The preset is stored in `export_presets.cfg`. Built executables are published through GitHub Releases and are not committed.

## Regenerate audio

All sound is synthesised by `tools/audio_synth.gd`:

```bash
godot --headless --path . -s res://tools/audio_synth.gd
```

Set `SYNTH_ONLY` to `sfx`, `ambient`, `music`, `finale`, `boss`, `mass`, `menu` or `cat` to rebuild a part.

## Project layout

- `scripts/world` — world kits, enemies' brains, trials, events, horses
- `scripts/player` — hero rig, armor, bow, camera effects
- `scripts/ui` — menus, inventory, map scenes, card game
- `scripts/audio`, `tools/audio_synth.gd` — audio manager and synthesiser
- `quests/` and `quest_manager.gd` — quest data and manager
- `docs/` — project website sources and roadmap

## Licence

The original source code is released under the [MIT License](LICENSE). The project's own procedural and synthesised content is distributed under the same terms unless a file says otherwise. MIT does not cover any third-party material — see [ASSETS.md](ASSETS.md) for the origin of the main assets.

## Website

The official site sources are in `docs/` and are published with GitHub Pages: https://vladserhiienko49.github.io/embers-of-the-spire/
