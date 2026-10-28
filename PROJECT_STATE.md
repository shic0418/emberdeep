# Project State

_Last updated: 2026-10-28, Phase 2A. Engine: Godot 4.7.2 stable (GL Compatibility renderer)._

## Phase 2A: Combat feel ✅ complete

### Completed features
- **Hit-stop.** Every landed melee hit slows the game to 5% speed for 0.06 s (both values are `@export`s on `Player`). Misses never trigger it. `GameState` runs it and counts real physics ticks, so it always ends on time, even while paused. Overlapping hits take the longest remaining stop instead of adding up. Opening the pause menu, respawning, `GameState.reset()` and every level load cancel it, so pause, death, restart and reload can't leave the game slowed.
- **Downward strike (Down + Attack in the air).**
  - Reuses the existing `AttackHitbox`. The pivot rotates downward and sits `down_strike_offset` (8 px) lower, so a strike made at full fall speed lands before the body reaches an enemy's contact damage.
  - A landed strike bounces the Wick upward at `pogo_bounce_speed` (340 px/s, about 2.5 tiles). A miss gives no bounce.
  - One bounce, and one hit per target, per activation. The bounce has a fixed height (releasing jump doesn't cut it) and does not refund the air dash, so it can't be chained into extra air movement. Enemies die in 3 hits, which limits chains further.
  - On the ground, Down + Attack is still a forward swing. Down + Jump drop-through is unchanged.
  - Drawn as a flame-orange fan from the feet, unlike the pale side and upward crescents.
  - Every attack ends through `Player._end_attack()` (end of the active window, getting hit, dying), which also clears the bounce flag.
- **Impact effect.** `ImpactBurst` (`scenes/effects/impact_burst.tscn`) is spawned between the blade and the target on every landed hit. It draws a white-hot flash, an expanding ember ring, a cross-streak along the strike line and about 9 sparks thrown along the attack direction that cool from gold to dull red, all in the Wick's flame colors. It is procedural with no assets and frees itself after 0.35 s.

### Files
- New: `scripts/effects/impact_burst.gd`, `scenes/effects/impact_burst.tscn`.
- Changed:
  - `scripts/autoload/game_state.gd`: hit-stop.
  - `scripts/player/player.gd`: down strike, bounce, hit-stop and impact hooks, `_end_attack`.
  - `scripts/player/player_visual.gd`: down-strike art.
  - `scenes/player/player.tscn`: `impact_effect`.
  - `scripts/ui/pause_menu.gd` and `scripts/level/level.gd`: cancel hit-stop.
  - `tests/test_runner.gd`.

### Validation results
- `--import`: no errors or warnings.
- Headless 300-frame run of the main scene: no errors or warnings.
- **Automated suite: 33/33 passing** (25 from Phase 1 and 8 new):
  - `down_strike_hits_and_bounces`: damage, bounce speed, no contact damage, and the burst spawns and frees itself.
  - `down_strike_from_full_fall`: at max fall speed the strike lands and bounces before contact damage.
  - `down_strike_miss_no_bounce`: no bounce, no hit-stop and no effect on a miss.
  - `down_strike_hits_once_per_activation`: keeping the hitbox over the enemy for the whole activation deals only 1 damage, and the next activation hits again.
  - `down_attack_on_ground_is_forward`.
  - `pogo_does_not_refund_air_dash`.
  - `hit_stop_restores_timing`: slows to the configured scale on a hit and is back to 1.0 within the expected frame count.
  - `hit_stop_cleared_by_pause_and_reload`: no stacking, zero duration is a no-op, it expires while paused, and it is cleared by level load, pause, death and `reset()`.
- One Phase 1 test was adjusted: `attack_hits_once_and_kills` now waits 20 frames between swings instead of 15, because hit-stop slows the 0.3 s attack cooldown. Its assertions are unchanged.
- **Graphical check (real window):** a temporary capture of a down strike from a full fall confirmed that the strike connects while the player is at full health, bounces at about −339 px/s and draws the ember burst. The forward-hit burst was also checked. Seeing these screenshots led to two changes: the down-strike reach offset, and moving the fan so it starts at the feet. The final fan shape rendered without errors but has not been looked at in a screenshot.

### Needs manual play-testing
- Whether 0.06 s at 5% speed feels punchy or sticky with real input.
- Pogo timing and the bounce height over the spike pit and on Gloomshells.

## Phase 1: Playable prototype ✅ complete

### Completed features
- **Player (the Wick)**
  - Acceleration-based running with directional facing.
  - Jump buffering (0.12 s), coyote time (0.1 s), and variable jump height: releasing jump early multiplies upward speed by 0.4. Gravity is heavier on the way down.
  - Dash: 330 px/s for 0.15 s with a 0.4 s cooldown, usable once per airtime.
  - Forward and upward melee attack. The hitbox is active for 0.1 s and hits each target once per swing; landing a hit causes recoil and screen shake.
  - 5 HP. Hits cause knockback, a 0.3 s stun and 1 s of blinking invulnerability.
  - Drop-through on one-way slabs (Down + Jump).
- **Enemy (Gloomshell)**
  - State machine with patrol, telegraph, charge, recover, hurt and dead states.
  - Turns at walls and ledges.
  - Telegraph: the shell glows hot, the eye turns red, the front rears up and a "!" appears.
  - Charge ignores stagger. 3 HP, contact damage, white flash on hit, knockback, belly-up death fade.
- **Level (The Drip Caverns)**
  - 80×30 tile ASCII-authored cavern with a step, a spike pit with a stepping stone, a pillar and a raised east floor.
  - Two optional climbs, each leading to a glimmer.
  - Two Ember Shrine checkpoints that fully heal and set the respawn point.
  - Spikes cost 1 HP and send the player back to the last safe ground.
  - Camera follows the player with smoothing, stays inside the map bounds and shakes on hits. The map is enclosed by a boundary wall.
- **UI**: an ember health bar that flashes when health is lost, a glimmer counter, and a pause menu (Resume, Restart at Shrine, Quit, controls list) that works with keyboard and gamepad.
- **Death and restart**: after a 1.2 s delay the level reloads at the last lit shrine. Collected glimmers persist; enemies reset.

### Files
New project. All files were created in this phase:
- `project.godot`: input map, collision layer names, 640×360 viewport scaled to a 1280×720 window, `GameState` autoload.
- `scripts/autoload/game_state.gd`
- `scripts/components/`: `health.gd`, `hitbox.gd`, `hurtbox.gd`, `game_camera.gd`
- `scripts/player/`: `player.gd`, `player_visual.gd`
- `scripts/enemies/`: `gloomshell.gd`, `gloomshell_visual.gd`
- `scripts/level/`: `level.gd`, `level_layout.gd`, `terrain_builder.gd`, `terrain_renderer.gd`
- `scripts/objects/`: `checkpoint.gd`, `glimmer.gd`
- `scripts/ui/`: `hud.gd`, `health_display.gd`, `pause_menu.gd`
- `scenes/`: `levels/cavern_01.tscn`, `player/player.tscn`, `enemies/gloomshell.tscn`, `objects/checkpoint.tscn`, `objects/glimmer.tscn`, `ui/hud.tscn`, `ui/pause_menu.tscn`
- `levels/cavern_01_layout.tres`
- `tests/test_runner.gd` and `tests/test_runner.tscn`
- `tools/capture.gd` and `tools/capture.tscn`
- `README.md`, `CLAUDE.md`, `PROJECT_STATE.md`, `.gitignore`

### Validation results
- `--import`: no errors or warnings.
- Headless 300-frame run of the main scene: no errors or warnings.
- **Automated suite: 25/25 passing.** It covers:
  - Layout validity, rectangle merging, the Health component and the terrain builder.
  - Running and facing, variable jump height, coyote time (works within the window and expires after it), jump buffering, dash, single air dash and its reset on landing, and one-way platforms (drop through, and jump up through and land).
  - Forward attack (hits once per swing, kills in 3), upward attack, contact damage with knockback and invulnerability, spike damage with safe-ground respawn, and player death.
  - Gloomshell telegraph → charge → recover cycle, ledge turning, and charge stagger immunity.
  - Shrine heal and spawn point, glimmer pickup, full level load (entity counts, camera bounds, HUD binding), respawn at a checkpoint with collected glimmers persisting, and the pause action freezing and unfreezing the world.
- **Graphical check (actually launched in a window, Intel Iris Xe, OpenGL 3.3).** The capture tool played the opening route with scripted input. It crossed the step, the spike pit and the stepping stone without damage, then reached the upper route. Screenshots confirmed the rendering of the terrain, HUD, shrine flame, telegraph, slash, pause menu and the whole-level overview. These screenshots led to two fixes: higher rock contrast and a bolder slash.

### Needs manual play-testing
The suite and the capture tool use scripted input. A human still needs to judge:
- Game feel: how well the jump, dash and attack timing respond to real keyboard and gamepad input.
- Difficulty, especially the 4-tile gaps over the spike pit.
- Gamepad bindings. They are mapped (SDL layout: A=jump, X=attack, RB=dash, Start=pause) but were not tested with real hardware.
- Mouse use in the pause menu, and window resizing or fullscreen.
- Climbing the left upper route all the way to the ledge glimmer. Each gap was designed to be 2–3 tiles up and ≤3 tiles across, and the overview screenshot looks consistent with that, but no one has completed the route.

### Known issues and limitations
- All art is procedural placeholder drawing. There is no audio and no animation system.
- Pressing a down strike only a frame or two before touching an enemy can still let its contact damage land first. This is intended: a late press is a mistake, and the hitbox needs a frame to start detecting overlaps. (Hit-stop, previously listed here as missing, was added in Phase 2A.)
- Enemies reset whenever the level reloads, including after Restart at Shrine.
- Spike respawn returns the player to the last safe ground, which can be some distance back if they were airborne for a long time.
- No save to disk. Progress lasts for the session only.

## Next phase (rest of Phase 2: not started)
1. Wall-cling and wall-jump as the first ability gate. (Hit-stop, the downward strike and particles were done in Phase 2A.)
2. A second enemy type (ranged or flying) and an ability pickup that opens a gated route.
3. Room transitions across multiple LevelLayouts, with door markers in the legend.
4. Saving to disk (`user://`): checkpoint, glimmers and abilities.
5. Placeholder audio hooks (jump, slash, hit, shrine).
