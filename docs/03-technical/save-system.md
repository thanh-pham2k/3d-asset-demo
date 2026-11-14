# Save System, Schema Evolution & Offline Progress (`SAVE-001`)

## 1. Storage, Versioning & Atomic Safety
- **Primary Path:** `user://save_very_mvp.json` (or `user://save_game.json` from `P2+` with automatic import from `save_very_mvp.json`).
- **Implementation:** `scripts/persistence/save_manager.gd`
- **Backup & Corruption Guard (`P2+`):**
  - Write to a temporary file (`user://save_game.tmp`) then rename, keeping `user://save_game.bak` of the last valid save.
  - On parse failure or invalid root dictionary, preserve the corrupt file for inspection and fall back cleanly to defaults without crashing.

## 2. Save Schema Evolution (`P1 -> P6`)

| `save_version` | Phase | Key Schema Additions / Migrations |
| --- | --- | --- |
| `1` *(implemented)* | `P1` | `saved_at_real_unix`, `clock_offset_sec`, `wallet_coins`, `inventory_carrots`, `plots[]` |
| `2` | `P2` | Migrate `inventory_carrots` -> `inventory_items: {"carrot": N}`; add `inventory_capacity`; safe defaults for new crop fields |
| `3` | `P3` | Add `progression: {"xp": 0, "level": 1, "unlocked_ids": []}` and `orders: {"slots": [], "next_refresh_unix": 0}` |
| `4` | `P4` | Add `production: {"stations": []}` (queued recipes with `started_at_unix`, `duration_sec`) |
| `5` | `P5` | Add `restaurant: {"kitchen_slots": [], "tables_level": 1, "customers": []}` |
| `6` | `P6` | Add `automation: {"staff": {}, "last_sim_unix": 0}` |
| `7+` | `P7–P12` | Optional additive sections (`home`, `pets`, `garage`, `neighborhood`, `goals`) with empty defaults |

**Migration Rule:** `SaveManager.load_game()` runs sequential pure migrators (`_migrate_v1_to_v2`, `_migrate_v2_to_v3`, ...) before hydrating `WorldState`, so any older save upgrades cleanly.

## 3. Current `P1` Payload Schema (`save_version: 1`)
```json
{
  "save_version": 1,
  "saved_at_real_unix": 1763100000,
  "clock_offset_sec": 0,
  "wallet_coins": 80,
  "inventory_carrots": 0,
  "plots": [
    {
      "id": 0,
      "state": "GROWING",
      "crop_id": "carrot",
      "planted_at_unix": 1763100000,
      "grow_duration_sec": 5
    }
  ]
}
```
*(Note: `grow_duration_sec` is `5` seconds in `data/crops/carrot.json` for fast P1 manual testing; `300` seconds is the standard starter balance target.)*

## 4. Deterministic `GameClock` & Offline Progress Rule
- `GameClock.now()` is defined as: `real_unix_now + clock_offset_sec`.
- All timestamps (`planted_at_unix`, `started_at_unix`, `next_refresh_unix`) are stored in `GameClock.now()` coordinates.
- **On Load:**
  1. Restore `clock_offset_sec` (so debug `GameClock.advance()` remains consistent after reload and never regresses a mature crop back to `GROWING`).
  2. Compute `offline_elapsed = maxi(0, real_unix_now - saved_at_real_unix)`.
  3. Evaluate `FarmSystem.tick(clock)` and (`P4+`) `Production` / `Restaurant` timers against `GameClock.now()`.
  4. In `P6+`, run bounded `AutomationSystem.simulate_offline(capped_elapsed, world_state)` consuming only actual `Inventory` stock.
- Auto-save on key state changes (plant, harvest, order delivery, unlock, craft, serve, clock advance) and `NOTIFICATION_WM_CLOSE_REQUEST`.
