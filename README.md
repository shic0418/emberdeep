# Emberdeep

An original 2D action metroidvania prototype made with Godot 4.7.2. You play the Wick, a small lantern-spirit with an ember for a head, exploring the Drip Caverns. The Gloomshells are armored crawlers that patrol the caverns.

## Requirements

- **Godot 4.7.2 stable**, standard build (not .NET). No other dependencies.
  On this machine the executable has been extracted to
  `C:\Users\user\Downloads\Godot_v4.7.2-stable_win64\`. It is not on PATH.

## Launch

From the project folder, in Git Bash:

```bash
G="/c/Users/user/Downloads/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe"
"$G" --path . --import   # first run only: imports the project
"$G" --path .            # play
"$G" --path . -e         # open in the editor (then press F5)
```

Or from PowerShell:

```powershell
& "C:\Users\user\Downloads\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --path .
```

The game starts directly in the playable level.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A / D or ← / → | Left stick / D-pad |
| Jump (hold for higher) | Space or Z | A / Cross |
| Attack (hold Up for an upward strike) | J or X | X / Square |
| Dash (once per jump in the air) | K, C or Shift | RB / R1 |
| Drop through a stone slab | Down + Jump | Down + A |
| Pause | Esc or P | Start |

Touch an **Ember Shrine** to light it. It heals you fully and becomes your respawn point. Spikes cost 1 health and return you to the last safe ground. **Glimmers** are hidden on side routes, and they stay collected after you die.

## Tests

```bash
"$G" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
```

The suite prints `PASS`/`FAIL` for each test and exits with code 0 when everything passes. See `CLAUDE.md` for the architecture and conventions, and `PROJECT_STATE.md` for progress.
