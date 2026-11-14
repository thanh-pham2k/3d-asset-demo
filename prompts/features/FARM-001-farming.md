# FARM-001 — FarmPlot & Fixed Isometric Farm Scene

**Docs:** `docs/02-game-design/core-loop.md`, `docs/03-technical/architecture.md`

## Scope
- Implement `FarmPlot` (`scripts/farming/farm_plot.gd` + `scenes/farming/farm_plot.tscn`) with 4 states: `EMPTY`, `GROWING`, `READY`, `LOCKED`.
- Clicking an `EMPTY` plot plants a carrot (`-5 xu` via `Wallet`, starts `CropTimer`).
- Clicking a `READY` plot harvests `+2` carrots into `Inventory` and resets the plot to `EMPTY`.
- Set up the fixed isometric `Camera3D` in `scenes/main/` framing the farm plots and cozy decorative backdrop (house, Boy, Girl, Miu Miu).
