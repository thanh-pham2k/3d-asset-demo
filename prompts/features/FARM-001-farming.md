# FARM-001 — FarmPlot & ASCII Farm View

**Docs:** `docs/02-game-design/core-loop.md`, `docs/03-technical/architecture.md`, `docs/02-game-design/ui-ux.md`, `docs/04-roadmap/roadmap.md`

## Scope (P1 — ASCII Only)
- Implement pure Game Core `FarmPlot` & `FarmSystem` (`scripts/farming/farm_plot.gd`, `scripts/farming/farm_system.gd`) with 4 states: `EMPTY`, `GROWING`, `READY`, `LOCKED`.
- No Godot UI or 3D node dependencies (`Label`, `Button`, `Node3D`, `Camera3D`) inside `scripts/farming/`.
- In `scenes/ascii/`, render each plot as an interactive ASCII tile/button:
  - `[ . ]` `EMPTY` -> click to plant carrot (`-5 xu` via `Wallet`, starts `CropTimer` using `GameClock.now()`)
  - `[ ~*~ ]` `GROWING` -> shows ASCII progress bar (`#`/`-`) and remaining time from `CropTimer`
  - `[ *!* ]` `READY` -> click to harvest (`+2` carrots into `Inventory`, plot resets to `EMPTY`)
  - `[ XXX ]` `LOCKED` -> unlockable via `FarmUpgrade` (`-120 xu`)
- **Deferred:** All 3D scenes, `Camera3D`, 3D raycasting, and 3D character models are deferred until explicitly requested after ASCII gameplay validation.
