# Save System & Offline Progress (`SAVE-001`)

## Requirements
- Save to `user://save_very_mvp.json` (or `.cfg`).
- Persist:
  - `wallet_coins`: integer
  - `inventory_carrots`: integer
  - `plots`: array of `{ "id": int, "state": String, "planted_at_unix": int, "grow_duration_sec": float }`
- **Offline Progress:**
  - Use `Time.get_unix_time_from_system()` as the single source of truth for `planted_at_unix`.
  - On load, any plot in `GROWING` state computes `elapsed = now_unix - planted_at_unix`.
  - If `elapsed >= grow_duration_sec`, transition immediately to `READY`; otherwise resume `GROWING` with the remaining time.
- Auto-save on key state changes (plant, harvest, order delivery, plot unlock) and on `NOTIFICATION_WM_CLOSE_REQUEST`.
