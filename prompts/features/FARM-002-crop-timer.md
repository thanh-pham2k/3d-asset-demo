# FARM-002 — CropTimer (Deterministic GameClock Growth)

**Docs:** `docs/03-technical/architecture.md`, `docs/03-technical/save-system.md`

## Scope
- Implement `CropTimer` (`scripts/farming/crop_timer.gd`) using **`GameClock` exclusively** (`GameClock.now()`), never calling `Time.get_unix_time_from_system()` directly inside farming logic.
- Track `planted_at_unix` (captured from `GameClock.now()`) and `grow_duration_sec` (loaded from `data/crops/`).
- Expose `get_remaining_seconds(now_unix)`, `get_progress(now_unix)`, and `is_mature(now_unix)` so both real-time play, debug fast-forward (`GameClock.advance(seconds)`), and offline reload behave deterministically.
