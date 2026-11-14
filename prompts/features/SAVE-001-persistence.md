# SAVE-001 — SaveManager & Offline Persistence

**Docs:** `docs/03-technical/save-system.md`, `docs/03-technical/architecture.md`

## Scope
- Implement `SaveManager` under **`scripts/persistence/save_manager.gd`**.
- Serialize and restore with `"save_version": 1`:
  - `saved_at_real_unix` and `clock_offset_sec` (from `GameClock`)
  - `Wallet` balance (`xu`)
  - `Inventory` carrot count
  - All `FarmPlot` states (`EMPTY` / `GROWING` / `READY` / `LOCKED`) and `CropTimer` `planted_at_unix` / `grow_duration_sec`
- On load, restore `GameClock` offset and evaluate every `GROWING` plot against `GameClock.now()` so both offline real-time elapsed and debug fast-forward progress remain 100% consistent.
