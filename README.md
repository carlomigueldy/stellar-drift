# Stellar Drift

A 2D top-down twin-stick space shooter built in **Godot 4.6**.

Pilot a ship through a bounded asteroid field, survive escalating waves of
enemies, and chase a persistent high score. The whole game — design, plan,
implementation, original CC0 sprites — was built in a single ~40-minute
session from a blank `Hello World` Godot project.

![Engine](https://img.shields.io/badge/Godot-4.6.3-478CBF?logo=godotengine&logoColor=white)
![Language](https://img.shields.io/badge/GDScript-2.0-3776AB)
![Assets](https://img.shields.io/badge/Assets-CC0-green)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Table of Contents

- [Quick Start](#quick-start)
- [Controls](#controls)
- [Gameplay](#gameplay)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Development Notes](#development-notes)
- [Adding Audio](#adding-audio)
- [Tweaking Difficulty](#tweaking-difficulty)
- [Credits](#credits)
- [License](#license)

---

## Quick Start

### Requirements

- Godot **4.6** or newer ([download](https://godotengine.org/download))
- Linux, macOS, or Windows. Tested on Linux (WSL2) with the GL Compatibility renderer.

### Run

Open the project in the Godot editor:

```bash
godot --path .
```

Or from the editor: **Import → select `project.godot` → Run**.

The repo ships with `.import/` sidecar files committed, so the SVG sprites
load without manual reimport on first run.

---

## Controls

| Action  | Input                       |
| ------- | --------------------------- |
| Move    | <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> or arrow keys |
| Aim     | Mouse                       |
| Shoot   | Left mouse button (held)    |

Movement uses smooth acceleration and damping for game feel — your ship has
weight. Mouse aim is independent of movement, so you can strafe while
shooting in any direction (twin-stick style).

---

## Gameplay

### The Loop

1. **Main Menu** — start a run or quit. Shows your persistent high score.
2. **Game** — survive waves of enemies in a bounded arena.
3. **Game Over** — see your final score; retry or return to menu. New high
   scores persist to `user://highscore.cfg`.

### Enemies

| Enemy   | HP | Behavior                                    | Score |
| ------- | -- | ------------------------------------------- | ----- |
| Chaser  | 1  | Homes in on the player; dies on contact     | +10   |
| Shooter | 2  | Keeps distance, fires red projectiles at you | +25   |

Wave `N` spawns `N + 2` enemies at random arena edges, staggered ~350 ms apart.
Shooter chance increases by 10% each wave, capped at 60%. The next wave starts
~2 seconds after the last enemy dies.

### Asteroids

10 asteroids scatter at the start of each run (more than 140 px from player
spawn, more than 90 px apart). Each takes 2 hits, blocks bullets and enemies,
and gives **+5** when destroyed. They make movement tactical — duck behind
one to break a shooter's line of sight.

### Player

- 3 HP, shown as hearts top-right.
- 0.6 second invulnerability + red flash on damage.
- Camera shakes ~10 px for 0.28 s when you take a hit.
- Muzzle flash on every shot.

---

## Project Structure

```
godot-game-sample/
├── project.godot                # Engine config, autoload, input map, collision layers
├── main.tscn                    # Entry scene: redirects to MainMenu
├── icon.svg                     # Project icon
├── assets/
│   ├── sprites/                 # 8 hand-authored CC0 SVG sprites
│   ├── audio/                   # Empty by default — drop SFX here (see below)
│   ├── fonts/                   # Reserved for custom fonts
│   └── CREDITS.md
├── globals/
│   └── GameState.gd             # Autoload: score, wave, high score, signals
├── scripts/
│   ├── Main.gd                  # Entry loader
│   ├── MainMenu.gd              # Title screen logic
│   ├── Game.gd                  # Arena root: spawns asteroids, owns camera shake, handles death
│   ├── Player.gd                # Movement, aim, shooting, damage, invuln, flashes
│   ├── PlayerBullet.gd          # Player projectile (Area2D)
│   ├── EnemyChaser.gd           # Homing melee enemy
│   ├── EnemyShooter.gd          # Distance-keeping ranged enemy
│   ├── EnemyBullet.gd           # Enemy projectile (Area2D)
│   ├── Asteroid.gd              # Static destructible obstacle
│   ├── Spawner.gd               # Wave logic: count + shooter ratio escalation
│   ├── HUD.gd                   # CanvasLayer listening to GameState signals
│   ├── GameOver.gd              # Final score + retry/menu
│   └── Explosion.gd             # Reusable particles + optional SFX
├── scenes/
│   ├── menus/                   # MainMenu.tscn, GameOver.tscn
│   ├── game/                    # Game.tscn (arena, walls, camera, player, HUD, spawner)
│   ├── actors/                  # Player, enemies, bullets, asteroid, explosion
│   └── ui/                      # HUD.tscn
└── docs/superpowers/
    ├── specs/2026-05-23-stellar-drift-design.md
    └── plans/2026-05-23-stellar-drift.md
```

---

## Architecture

### Core principles

- **Composition over inheritance.** Each actor is its own scene with one
  responsibility (player, chaser, shooter, bullet, asteroid). Game wires
  them together but never reaches inside them.
- **Loose coupling via signals + groups.** Enemies find the player via
  `get_tree().get_nodes_in_group("player")`, never via direct reference.
  HUD listens to `GameState` signals — actors never touch HUD code.
- **Physics-layer-based separation.** Five collision layers keep collisions
  predictable without complex masks scattered across nodes.

### Collision Layers

| Layer | Name           | Used by                |
| ----- | -------------- | ---------------------- |
| 1     | `world`        | Arena walls, asteroids |
| 2     | `player`       | Player ship            |
| 3     | `player_bullet`| Player projectiles     |
| 4     | `enemy`        | Chasers, Shooters      |
| 5     | `enemy_bullet` | Enemy projectiles      |

Player bullets mask world + enemies. Enemy bullets mask world + player.
Asteroids are on world so they block both sides.

### GameState (Autoload)

`GameState` is the only globally accessible state holder. It exposes:

| Signal              | Fired when                       |
| ------------------- | -------------------------------- |
| `score_changed`     | A scoring event happens          |
| `wave_changed`      | Spawner advances the wave        |
| `player_hp_changed` | Player HP changes (incl. spawn)  |
| `game_over_requested` | Game-over flow is initiated    |

| Method                | Purpose                                       |
| --------------------- | --------------------------------------------- |
| `reset_run()`         | Zero out score + wave at run start            |
| `add_score(amount)`   | Increment and emit                            |
| `set_wave(n)`         | Update current wave and emit                  |
| `report_player_hp(h)` | Re-broadcast HP for HUD                       |
| `report_game_over()`  | Save high score if beaten; emit game-over    |

High score persists to `user://highscore.cfg` via `ConfigFile`.

### Scene Flow

```
Main (main.tscn)
  └── deferred change_scene_to_file → MainMenu
                                        ├── Start → Game
                                        └── Quit  → exit

Game
  ├── Background, Camera2D (with shake)
  ├── Arena (walls + asteroids + enemies)
  ├── Player (emits died, damaged)
  ├── HUD (listens to GameState signals)
  └── Spawner (escalating waves)
       └── on player.died → save high score → 1s pause → GameOver

GameOver
  ├── Retry → Game
  └── Main Menu → MainMenu
```

---

## Development Notes

This project was built using the Superpowers brainstorming → writing-plans →
executing-plans → finishing-a-development-branch workflow. The full design
spec and 17-task implementation plan are committed under `docs/superpowers/`,
so you can read how the codebase came together step by step.

### Verification model

The project has no unit tests by design — game-dev verification is best
done by play. The Godot MCP server was used for headless smoke testing at
each task boundary, confirming that:

- Resources import cleanly
- Scripts parse without errors
- The game scene runs for 12+ seconds without runtime errors
- The full menu → game → death → game-over → retry loop fires cleanly

### Known assets caveat

The original plan called for Kenney's CC0 *Space Shooter Redux* pack, but
Kenney's CDN is gated behind a JavaScript download flow that bare `curl`
cannot reach. Instead, the project ships with **hand-authored SVG sprites**
(8 of them, in `assets/sprites/`) released under CC0. They're stylistically
simple but functional and license-clean.

Audio (`assets/audio/`) is empty — see below to add it.

---

## Adding Audio

The game runs silently by default. Audio loading is graceful — `Explosion.gd`
and `Player.gd` both check `ResourceLoader.exists()` and skip cleanly if a
file is missing. To enable sound, drop CC0 audio files into `assets/audio/`
using these names (either `.ogg` or `.wav` works):

| File              | Plays when                |
| ----------------- | ------------------------- |
| `laser.ogg`       | Player fires a bullet     |
| `hit.ogg`         | Player takes damage       |
| `explosion.ogg`   | Enemy or asteroid is destroyed |

Suggested CC0 sources:

- [Kenney Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds)
- [OpenGameArt.org](https://opengameart.org/) (filter for CC0)

After dropping files in, re-open the editor once so Godot generates
`.import` sidecars for each audio file.

---

## Tweaking Difficulty

Most gameplay values are exported as scene properties on each actor — open
the relevant `.tscn` in the editor inspector, or edit the `@export` defaults
directly in script:

| Where                        | Property             | Default | Effect |
| ---------------------------- | -------------------- | ------- | ------ |
| `scripts/Player.gd`          | `speed`              | 320     | Movement speed |
|                              | `fire_rate`          | 0.18 s  | Lower = faster shooting |
|                              | `max_hp`             | 3       | Starting health |
|                              | `invuln_time`        | 0.6 s   | Damage immunity window |
| `scripts/EnemyChaser.gd`     | `speed`              | 130     | Chaser homing speed |
|                              | `score_value`        | 10      | Points per kill |
| `scripts/EnemyShooter.gd`    | `preferred_distance` | 320     | Where shooters orbit at |
|                              | `fire_interval`      | 1.5 s   | Time between shots |
|                              | `score_value`        | 25      | Points per kill |
| `scripts/Asteroid.gd`        | `max_hp`             | 2       | Hits to destroy |
| `scripts/Spawner.gd`         | `wave_break_seconds` | 2.0     | Pause between waves |
|                              | `spawn_stagger_seconds` | 0.35 | Time between spawns in a wave |
| `scripts/Game.gd`            | `ASTEROID_COUNT`     | 10      | Asteroid density |

Wave count grows as `wave_number + 2` and shooter chance ramps `+10%` per
wave up to a 60% cap. To change those, edit `Spawner._start_next_wave()`.

---

## Credits

- **Engine:** [Godot 4.6](https://godotengine.org/) — MIT
- **Sprites:** Original CC0 SVGs authored for this project (see
  [assets/CREDITS.md](assets/CREDITS.md))
- **Audio:** Drop CC0 audio in `assets/audio/` to enable
- **Build assistance:** Implemented with [Claude Code](https://claude.com/claude-code)
  using the Superpowers plugin (brainstorming → planning → execution → review)

---

## License

The source code in this repository is released under the **MIT License**
(see `LICENSE` if present, or treat as MIT until added).

Original sprites in `assets/sprites/` are **CC0** (Public Domain).
