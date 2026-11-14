# SAVE-001 — SaveManager & Offline Persistence

**Docs:** `docs/03-technical/save-system.md`

## Scope
- Implement `SaveManager` (`scripts/save/save_manager.gd`) to serialize and restore:
  - `Wallet` balance (`xu`)
  - `Inventory` carrot count
  - All `FarmPlot` states (`EMPTY` / `GROWING` / `READY` / `LOCKED`) and `CropTimer` timestamps (`planted_at_unix`, `grow_duration_sec`)
- Recompute crop growth against `Time.get_unix_time_from_system()` on load so crops continue growing while the game is closed.
