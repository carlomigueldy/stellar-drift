# Stellar Drift — Design Spec

**Date:** 2026-05-23
**Engine:** Godot 4.6.3 (GL Compatibility renderer)
**Deadline:** 2026-05-23 17:30 PST
**Status:** Approved

## Concept

*Stellar Drift* is a 2D top-down twin-stick space shooter. The player pilots a ship in a bounded asteroid field, surviving escalating waves of enemies. The loop is endless; the goal is to beat the high score.

## Goals

- Ship a playable, polished single-player game by 17:30 PST.
- Demonstrate working Godot 4.6 patterns: scene composition, autoloads, signals, persistent state.
- Use only CC0 / public-domain assets, sourced and downloaded during the build.

## Non-Goals

- Multiplayer, online, or networked play.
- Save slots / progression / unlockables beyond a single persisted high score.
- Mobile / touch controls (desktop keyboard + mouse only).
- Unit test coverage. Verification is manual via Godot MCP `run_project`.

## Controls

- **Move:** WASD or arrow keys (8-directional).
- **Aim:** Mouse position.
- **Shoot:** Left mouse button (rate-limited to ~5 shots/sec).
- **Pause:** Escape (optional, time permitting).

## Arena

Bounded rectangular play area (roughly 1280×720 logical resolution). The player cannot exit the arena — movement is clamped at the edges. No screen wrap.

## Actors

### Player
- 3 HP. One hit = -1 HP. Brief invulnerability + flash on hit (~0.6s).
- Movement: velocity-based, with light acceleration/damping for game feel.
- Shoots forward (toward mouse cursor).
- On death: short delay → game-over screen.

### Enemy: Chaser
- Spawns at a random edge of the arena.
- Homes in on the player at constant speed.
- 1 HP. Dies on bullet hit.
- Contact with player: deals 1 damage and despawns itself.
- Score on kill: **+10**.

### Enemy: Shooter
- Spawns at a random edge.
- Maintains distance from the player (approaches if far, retreats if close).
- Fires a slow projectile at the player every ~1.5s.
- 2 HP.
- Contact with player: deals 1 damage; enemy survives.
- Score on kill: **+25**.

### Asteroid
- Static obstacle, scattered at the start of each run (8–12 instances).
- 2 HP. Despawns on destruction.
- Blocks bullets and enemies (collision).
- Score on destruction: **+5**.

### Bullets
- Player bullet: fast, despawns on enemy/asteroid hit or when leaving arena.
- Enemy bullet: slower, despawns on player/asteroid hit or when leaving arena.
- Both implemented as `Area2D` with a hitbox.

## Wave System

- Wave N spawns `N + 2` enemies total over a few seconds.
- Composition shifts with wave number:
  - Wave 1: 100% Chasers.
  - Each wave: chance of Shooter increases by 10% (capped at 60%).
- Next wave starts ~2 seconds after the last enemy in the current wave dies.
- Wave counter shown in HUD.

## Score & Persistence

- Score increments per the values above.
- High score saved to `user://highscore.cfg` via `ConfigFile`.
- Loaded on game start; updated on game-over if beaten.

## Scenes

```
res://
├── main.tscn                       # entry → loads MainMenu
├── scenes/
│   ├── menus/
│   │   ├── MainMenu.tscn           # title, Start, Quit, high-score line
│   │   └── GameOver.tscn           # final score, high score, Retry, Menu
│   ├── game/
│   │   └── Game.tscn               # arena root: camera, HUD, spawner, player
│   ├── actors/
│   │   ├── Player.tscn
│   │   ├── EnemyChaser.tscn
│   │   ├── EnemyShooter.tscn
│   │   ├── PlayerBullet.tscn
│   │   ├── EnemyBullet.tscn
│   │   └── Asteroid.tscn
│   └── ui/
│       └── HUD.tscn                # score, wave, hearts
├── scripts/                        # GDScript files (one per scene)
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
└── globals/
    └── GameState.gd                # autoload: score, wave, high score, signals
```

## Architecture & Boundaries

- **`GameState` autoload** owns global, cross-scene state: current score, current wave, high score, and signals (`score_changed`, `wave_changed`, `game_over`). HUD listens to these signals — actors never reference the HUD directly.
- **`Game.tscn`** owns the arena: player instance, enemy spawner node, asteroid layout, HUD instance, camera.
- **Spawner** is a child node of `Game` with a timer + RNG. It does not know about HUD or score — it emits enemies into the scene tree.
- **Actors** (Player, Enemies, Bullets) are independent scenes. They communicate only through:
  - Physics layers (player / enemy / player_bullet / enemy_bullet / world).
  - Signals on hit / death.
- **No actor reaches up** into Game or GameState directly for gameplay logic. The only allowed coupling is: actors call `GameState.add_score(n)` on death, and the player emits `died` for Game to handle.

## Collision Layers

| Layer | Used by |
|-------|---------|
| 1 | World (asteroids) |
| 2 | Player |
| 3 | Player bullets |
| 4 | Enemies |
| 5 | Enemy bullets |

Masks set so bullets only hit their opposing side + world.

## Polish (priority order, drop from bottom if time-constrained)

1. Muzzle flash sprite on shoot.
2. Hit flash (modulate red, 0.1s) on damage.
3. Camera shake on player damage (small, ~0.3s).
4. Explosion particles (`CPUParticles2D`) on enemy/asteroid death.
5. SFX: laser shoot, explosion, player hit, enemy hit, game over.
6. Parallax starfield background.
7. Pause menu (Escape).

## Asset Sourcing

All CC0 / public domain.

- **Sprites:** Kenney *Space Shooter Redux* pack (https://kenney.nl/assets/space-shooter-redux).
- **SFX:** Kenney *Sci-Fi Sounds* pack (https://kenney.nl/assets/sci-fi-sounds).
- **Font:** Kenney *Future* or *Pixel* font (CC0, bundled in Kenney UI packs).
- **Fallback:** OpenGameArt.org CC0-tagged assets if a specific sprite is missing.

Assets are downloaded fresh during the build, unpacked into `assets/`, and only the subset actually used is committed.

## Verification Plan

Manual smoke test via Godot MCP `run_project` after each milestone:

1. **After scaffold:** main menu loads, Start button transitions to Game scene.
2. **After player:** ship moves, aims at cursor, shoots bullets that despawn off-arena.
3. **After enemies:** chasers spawn at edges, home in, die to bullets, deal contact damage.
4. **After shooters:** shooters maintain distance and fire bullets that damage the player.
5. **After waves:** wave counter increments, enemy mix shifts, difficulty escalates.
6. **After score/persistence:** score increments correctly; high score persists across restarts.
7. **After polish:** SFX play, particles render, camera shakes on hit.
8. **Final play-through:** survive 3+ waves without crash; game-over → retry works.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Kenney download fails / slow | Fallback to OpenGameArt CC0; placeholder colored rectangles work if both fail. |
| Godot MCP can't run project headlessly | Fall back to direct `godot --headless` CLI invocation. |
| Time overrun on polish | Polish list is explicitly priority-ordered; cut from bottom. |
| Scope creep on enemy variety | Hard-locked to two enemy types in this spec. |

## Out of Scope (explicit)

- Boss enemies.
- Powerups / weapon upgrades.
- Multiple levels or biomes.
- Settings menu / rebindable controls.
- Localization.
