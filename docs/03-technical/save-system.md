# Save System & Offline Progress (`SAVE-001`)

## Storage & Versioning
- Path: `user://save_very_mvp.json`
- Implementation: `scripts/persistence/save_manager.gd`
- Always include `"save_version": 1` at the root of the JSON payload for forward compatibility.

## Payload Schema
```json
{
  "save_version": 1,
  "saved_at_real_unix": 1763100000,
  "clock_offset_sec": 0,
  "wallet_coins": 100,
  "inventory_carrots": 0,
  "plots": [
    {
      "id": 0,
      "state": "GROWING",
      "planted_at_unix": 1763100000,
      "grow_duration_sec": 300
    }
  ]
}
```

## Deterministic `GameClock` & Offline Progress Rule
- `GameClock.now()` is defined as: `real_unix_now + clock_offset_sec`.
- All `planted_at_unix` timestamps are recorded in `GameClock.now()` coordinates.
- On load:
  1. Restore `clock_offset_sec` (so debug fast-forwards via `GameClock.advance()` remain consistent after reload and never regress a mature crop back to `GROWING`).
  2. Compute `offline_elapsed = max(0, real_unix_now - saved_at_real_unix)`.
  3. Because `GameClock.now()` uses `real_unix_now + clock_offset_sec`, offline wall-clock time automatically advances `GameClock.now()` by `offline_elapsed`.
  4. Evaluate every `GROWING` plot against `GameClock.now()`: if `GameClock.now() - planted_at_unix >= grow_duration_sec`, transition to `READY`.
- Auto-save on key state changes (plant, harvest, order delivery, plot unlock, clock advance) and on `NOTIFICATION_WM_CLOSE_REQUEST`.
