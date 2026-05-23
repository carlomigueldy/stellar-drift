# Asset Credits

All sprites in `assets/sprites/` are original, hand-authored SVG files created
specifically for *Stellar Drift* and released under CC0 (Public Domain).

Original sourcing plan called for Kenney's CC0 *Space Shooter Redux* pack,
but the kenney.nl downloads were unavailable at build time (the page uses
a JS-gated download flow that bare `curl` cannot reach). We fell back to
procedurally-designed SVG sprites so the project ships standalone with no
external dependencies.

Audio (`assets/audio/`) is currently empty — the game gracefully handles
absent SFX files. To enable sound, drop CC0 `.ogg` / `.wav` files into
`assets/audio/` using these names:

- `laser.ogg` or `laser.wav` — player shoot
- `hit.ogg` or `hit.wav` — player damage
- `explosion.ogg` or `explosion.wav` — enemy/asteroid destruction

Suggested CC0 source: https://kenney.nl/assets/sci-fi-sounds
