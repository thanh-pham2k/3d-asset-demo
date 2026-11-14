# Technical Architecture — ASCII-First VERY MVP

## 1. Core Principle: Game Core != Presentation
Game Core scripts (`scripts/`) must **not** reference `Label`, `Button`, `Control`, `Node3D`, `MeshInstance3D`, or animations.

```text
                  GAME CORE
       (Pure GDScript, asset-independent)
                      │
   ┌──────────┬───────┴────────┬──────────┐
FarmSystem  EconomySystem  OrderSystem  ProgressionSystem
   └──────────┴───────┬────────┴──────────┘
                  GameClock + SaveSystem
                      │
                 GAME STATE
                      │
                PRESENTATION
         ┌────────────┴────────────┐
     ASCII VIEW                3D VIEW
   (Phase 1–3)           (Phase 1.5 / Phase 4)
```

## 2. Deterministic Time (`GameClock`)
All growth timers use `GameClock` instead of raw frame timers or direct `Time.get_unix_time_from_system()` calls scattered in gameplay code:
- `now() -> int`: current simulated or real Unix timestamp.
- `advance(seconds: int)`: fast-forward time in debug/ASCII playtests (`+1m`, `+5m`, `+1h`).
- `reset()`: reset simulated time offset.
- `offline_elapsed(last_saved_unix: int) -> int`: elapsed time since last save.

## 3. Seven VERY MVP Modules
| Module | Folder | Responsibility |
| --- | --- | --- |
| `GameClock` | `scripts/core/` | Deterministic timestamp provider & debug fast-forward |
| `FarmSystem` / `FarmPlot` / `CropTimer` | `scripts/farming/` | Plot states (`EMPTY`, `GROWING`, `READY`, `LOCKED`) & timestamp growth |
| `InventorySystem` & `Wallet` | `scripts/economy/` | Carrot count & `xu` balance |
| `OrderSystem` | `scripts/orders/` | Fulfill `4` carrots -> `+60 xu` |
| `ProgressionSystem` | `scripts/progression/` | Unlock `LOCKED` plot for `120 xu` |
| `SaveSystem` | `scripts/persistence/` | Persist state + compute offline crop maturity on load |
