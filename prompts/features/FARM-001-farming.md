# FARM-001 — FarmPlot & ASCII Farm View

**Docs:** `docs/02-game-design/core-loop.md`, `docs/03-technical/architecture.md`, `docs/02-game-design/ui-ux.md`

## Scope (Phase 1 — ASCII Only)
- Implement pure Game Core `FarmPlot` & `FarmSystem` (`scripts/farming/farm_plot.gd`, `scripts/farming/farm_system.gd`) with 4 states: `EMPTY`, `GROWING`, `READY`, `LOCKED`.
- No Godot UI or 3D node dependencies (`Label`, `Button`, `Node3D`, `Camera3D`) inside `scripts/farming/`.
- In `scenes/ascii/`, render each plot as an interactive ASCII tile/button:
  - `[ . ]` `EMPTY` -> click to plant carrot (`-5 xu` via `Wallet`, starts `CropTimer` using `GameClock.now()`)
  - `[ ~ ]` `GROWING` -> shows remaining time from `CropTimer`
  - `[ * ]` `READY` -> click to harvest (`+2` carrots into `Inventory`, plot resets to `EMPTY`)
  - `[ X ]` `LOCKED` -> unlockable via `FarmUpgrade` (`-120 xu`)
- **Deferred:** `Camera3D`, 3D raycasting, and decorative Boy/Girl/Miu Miu 3D models are deferred to **Phase 1.5 (3D Interaction Spike)** and **Phase 4 (Asset Integration)**.
