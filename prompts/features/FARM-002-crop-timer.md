# FARM-002 — CropTimer (Real-Time & Offline Growth)

**Docs:** `docs/03-technical/architecture.md`, `docs/03-technical/save-system.md`

## Scope
- Implement `CropTimer` (`scripts/farming/crop_timer.gd`) using real-time Unix timestamps (`Time.get_unix_time_from_system()`).
- Track `planted_at_unix` and `grow_duration_sec` (configured in `data/crops/`).
- Expose `get_remaining_seconds()`, `get_progress()`, and `is_mature()` so closing and reopening the game preserves real-time growth.
