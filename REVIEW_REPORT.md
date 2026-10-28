# Review Report: Emberdeep (Phase 1)

_Generated: 2026-10-28. This is a review snapshot only; nothing in the project was changed to make it._

## 1. Overview

**Emberdeep** is an original 2D action metroidvania prototype written in Godot **4.7.2 stable** with GDScript and the GL Compatibility renderer. You play the Wick, a lantern-spirit, exploring an underground cavern ("The Drip Caverns") that contains one enemy type, the Gloomshell. Phase 1, the playable prototype, is complete. Phase 2 has not been started.

There are no imported assets. All art is drawn procedurally in `_draw()`, and there is no audio, no fonts beyond Godot's default, no shaders, no tilesets and no addons or plugins.

### Current features
- **Player:**
  - Acceleration-based running and directional facing.
  - Jump buffering (0.12 s), coyote time (0.1 s), and variable jump height via a jump cut (×0.4).
  - Dash: 330 px/s for 0.15 s with a 0.4 s cooldown, once per airtime.
  - Forward and upward melee attack with real hitbox/hurtbox detection; each target is hit once per swing.
  - 5 HP, knockback, a 0.3 s stun and 1 s of invulnerability after a hit.
  - Drop-through on one-way slabs (Down + Jump).
- **Enemy (Gloomshell):**
  - State machine: PATROL → TELEGRAPH → CHARGE → RECOVER, plus HURT and DEAD.
  - Turns at ledges and walls.
  - Visual telegraph: the shell glows, the eye turns red, it rears up and a "!" appears.
  - Charge ignores stagger. 3 HP, contact damage, hit flash, death fade.
- **Level:**
  - 80×30 tile ASCII-authored map with a spike pit, a step, a pillar, a raised floor, one-way slabs and two optional climbs leading to collectibles ("glimmers").
  - Two checkpoint shrines that fully heal and set the respawn point.
  - Spikes cost 1 HP and send the player back to the last safe ground.
  - The camera follows with smoothing, stays within the map bounds and shakes on hits. The map is enclosed by a boundary wall.
- **UI:** ember health HUD, glimmer counter, and a pause menu (Resume, Restart at Shrine, Quit, controls list).
- **Death:** after 1.2 s the level reloads at the last shrine. Glimmers persist; enemies reset.

## 2. Main scene and key scripts

**Main scene:** `res://scenes/levels/cavern_01.tscn`, set as `run/main_scene` in `project.godot`.
**Autoload:** `GameState` → `scripts/autoload/game_state.gd`.

| File | Role |
|---|---|
| `scripts/level/level.gd` (`Level`) | Builds the level at runtime from a `LevelLayout`: terrain, player, enemies, shrines, pickups. Binds the HUD and handles death → respawn. |
| `scripts/level/level_layout.gd` (`LevelLayout`) | Resource holding the ASCII map. Contains the legend, cell queries and greedy rectangle merging. |
| `levels/cavern_01_layout.tres` | The cavern map data. Edit this to change the level. |
| `scripts/level/terrain_builder.gd` | Builds rock collision, one-way slabs, spike hitboxes and the boundary walls. |
| `scripts/level/terrain_renderer.gd` | Draws all terrain art procedurally. |
| `scripts/player/player.gd` (`Player`) | Player movement, dash, attack and damage state machine. All tuning values are `@export`. |
| `scripts/enemies/gloomshell.gd` (`Gloomshell`) | Enemy AI state machine. |
| `scripts/components/hitbox.gd`, `hurtbox.gd`, `health.gd` | Reusable combat components. Hitboxes poll overlaps every physics frame. |
| `scripts/autoload/game_state.gd` | Session state (checkpoint and collected pickups) that survives scene reloads. |
| `tests/test_runner.gd` | Headless gameplay test suite: 25 tests that drive the real scenes with simulated input. |
| `tools/capture.gd` | Windowed screenshot tool. Plays the opening route with scripted input. |

The architecture, collision-layer table and conventions are documented in **`CLAUDE.md`** inside the bundle.

## 3. File inventory (everything in the archive)

The archive root folder is `emberdeep/`; paths below are relative to it. Sizes are in bytes.

| Size | Path |
|---:|---|
| 30 | `.gitignore` |
| 6366 | `CLAUDE.md` |
| 6004 | `PROJECT_STATE.md` |
| 1836 | `README.md` |
| (this file) | `REVIEW_REPORT.md` |
| 8468 | `project.godot` |
| 2694 | `levels/cavern_01_layout.tres` |
| 1877 | `scenes/enemies/gloomshell.tscn` |
| 871 | `scenes/levels/cavern_01.tscn` |
| 476 | `scenes/objects/checkpoint.tscn` |
| 418 | `scenes/objects/glimmer.tscn` |
| 2114 | `scenes/player/player.tscn` |
| 1021 | `scenes/ui/hud.tscn` |
| 1631 | `scenes/ui/pause_menu.tscn` |
| 1264 | `scripts/autoload/game_state.gd` |
| 826 | `scripts/components/game_camera.gd` |
| 776 | `scripts/components/health.gd` |
| 2010 | `scripts/components/hitbox.gd` |
| 452 | `scripts/components/hurtbox.gd` |
| 3984 | `scripts/enemies/gloomshell.gd` |
| 2237 | `scripts/enemies/gloomshell_visual.gd` |
| 2395 | `scripts/level/level.gd` |
| 3839 | `scripts/level/level_layout.gd` |
| 2352 | `scripts/level/terrain_builder.gd` |
| 3481 | `scripts/level/terrain_renderer.gd` |
| 1669 | `scripts/objects/checkpoint.gd` |
| 833 | `scripts/objects/glimmer.gd` |
| 8566 | `scripts/player/player.gd` |
| 2600 | `scripts/player/player_visual.gd` |
| 1198 | `scripts/ui/health_display.gd` |
| 607 | `scripts/ui/hud.gd` |
| 905 | `scripts/ui/pause_menu.gd` |
| 20623 | `tests/test_runner.gd` |
| 167 | `tests/test_runner.tscn` |
| 3604 | `tools/capture.gd` |
| 164 | `tools/capture.tscn` |
| 19–20 each | 20 × `*.gd.uid`, one next to every `.gd` script above |

That is 56 files in total: 20 `.gd`, 20 `.gd.uid`, 9 `.tscn`, 1 `.tres`, `project.godot`, `.gitignore` and 4 Markdown docs. The project contains no textures, audio, fonts, shaders, tilesets, addons or `export_presets.cfg`.

## 4. Test and build results

All of these commands were actually run on 2026-10-28 with Godot `4.7.2.stable.official.ed1daf0bf` on Windows 11 (Intel Iris Xe, OpenGL 3.3), from the project root, with
`G=/c/Users/user/Downloads/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe`.

| Command | Result |
|---|---|
| `"$G" --version` | `4.7.2.stable.official.ed1daf0bf` |
| `"$G" --headless --path . --import` | exit 0, no errors or warnings |
| `"$G" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn` | exit 0, **25/25 PASS**, `ALL TESTS PASSED`, no errors or warnings |
| `"$G" --headless --path . --quit-after 300` (main scene smoke run) | exit 0, no errors or warnings |
| **Clean-room check:** extracted `review_bundle.zip` into an empty temp directory, then ran `--import` and the test suite there | see §4.1 |

Tests run: layout_is_valid, merge_rects, health_component, terrain_builder, run_and_facing, variable_jump_height, coyote_time, coyote_time_expires, jump_buffer, dash, single_air_dash, one_way_platform, attack_hits_once_and_kills, up_attack, contact_damage_knockback_iframes, spikes_respawn_to_safe_ground, player_death, enemy_telegraph_charge_cycle, enemy_patrol_turns_at_ledges, enemy_charge_ignores_stagger, checkpoint_heals_and_sets_spawn, glimmer_pickup, level_loads, level_spawns_at_checkpoint, pause_menu.

**Graphical verification (earlier in Phase 1, not repeated for this package):** `"$G" --path . --fixed-fps 60 res://tools/capture.tscn -- <dir>` ran in a real window. With scripted input, the player crossed the step, the spike pit and the stepping stone without damage. Screenshots of the terrain, HUD, shrine, enemy telegraph, slash, pause menu and level overview were inspected.

### 4.1 Clean-room check
`review_bundle.zip` was extracted into a new, empty directory, where no `.godot/` cache existed. These commands were then run inside `emberdeep/`:
- `"$G" --headless --path . --import` → exit 0, no errors or warnings.
- `"$G" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn` → exit 0, **25/25 PASS**, no errors or warnings.

The bundle is therefore self-sufficient: no excluded file is needed to import the project or pass its tests.

**What has not been verified:** play with a real keyboard or gamepad (game feel, difficulty), gamepad bindings on actual hardware, a full human run of the left optional climb to its glimmer, mouse use in the pause menu, and window resizing or fullscreen.

## 5. Known bugs and incomplete features
- No reproducible bugs are currently known. One found during Phase 1 was fixed: a spike respawn could place the player on a pit lip, from which they fell straight back in.
- All art is procedural placeholder drawing. There is no audio and no animation system.
- Hits have no hit-stop (freeze frames).
- Enemies reset on every level reload, including Restart at Shrine.
- No save to disk; progress lasts for the session only.
- After a spike hit, the player respawns at the last safe ground, which can be some distance back after a long airborne stretch.
- The Python script originally used to generate the cavern map was a temporary helper and is not part of the project. The map is edited directly in `levels/cavern_01_layout.tres`.
- The Phase 2 plan (not started) is in `PROJECT_STATE.md`: hit-stop and a downward strike, wall-jump, a second enemy, room transitions, saving and audio.

## 6. Exclusions

| Excluded | Reason |
|---|---|
| `.godot/` (about 23 KB) | Godot's import and editor cache. It is regenerated automatically by `--import` or by opening the editor. |
| `review_bundle.zip` | The archive itself. |

Nothing else was excluded. The project has no `.git/`, export builds, installers, logs, temporary files, `node_modules/` or other dependency caches. A scan for API keys, tokens, passwords and private keys found nothing. Godot itself is not included; it is a separate download (4.7.2 stable, standard build).

## 7. Archive

- **Path:** `C:\Users\user\Desktop\HollowKnight\review_bundle.zip`
- **Size:** 47917 bytes (about 47 KB), Deflate level 9. The uncompressed source totals about 107 KB (excluding this report's own archive).
- **Layout:** a single top-level folder `emberdeep/` that mirrors the project's relative directory structure. Open `emberdeep/project.godot` in Godot 4.7.2, or run the commands in §4 from inside `emberdeep/`.

The archive is small, so no size reduction is needed. For a future project with large assets, the largest files can be found with `find . -path ./.godot -prune -o -type f -printf "%s %p\n" | sort -rn | head`. A smaller package should then omit only bulky media that the review doesn't need, list every omitted file in this report, and keep all `.gd`, `.tscn`, `.tres`, `.uid` and `project.godot` files plus any asset that a scene references (otherwise the project will not load).
