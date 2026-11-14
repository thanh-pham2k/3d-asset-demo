# PROG-001 — FarmUpgrade

**Docs:** `docs/02-game-design/progression.md`, `docs/02-game-design/economy.md`

## Scope
- Implement `FarmUpgrade` (`scripts/progression/farm_upgrade.gd`) to unlock a `LOCKED` `FarmPlot` (`LOCKED` -> `EMPTY`) when the player spends `120 xu` via `Wallet`.
- Persist unlocked state through `SaveManager`.
