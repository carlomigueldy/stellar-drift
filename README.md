# Stellar Drift

A 2D top-down twin-stick space shooter built in Godot 4.6.

## Controls

| Action | Input |
|--------|-------|
| Move | WASD / Arrow keys |
| Aim | Mouse |
| Shoot | Left mouse button |

## Run

```bash
godot --path .
```

Or open `project.godot` in the Godot editor.

## Build

This project ships as source — no build step. Godot reimports `.svg` assets on
first editor launch (sidecar `.import` files are committed so headless runs
work out of the box).

## Architecture

See `docs/superpowers/specs/2026-05-23-stellar-drift-design.md` for the design
spec and `docs/superpowers/plans/2026-05-23-stellar-drift.md` for the
implementation plan.

## Assets

All sprites in `assets/sprites/` are CC0 originals authored for this project.
See `assets/CREDITS.md`.

Audio is currently absent — drop CC0 `.ogg` / `.wav` files into `assets/audio/`
(named `laser.*`, `hit.*`, `explosion.*`) to enable SFX. The game runs silently
without them.
