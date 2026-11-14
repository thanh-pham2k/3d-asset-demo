# Phase 1 — Core Farming VERY MVP (Status & Acceptance)

> For the full 12-phase ASCII-first roadmap (`P1–P12`), see [roadmap.md](roadmap.md).

## Phase 1 Completion Loop (ASCII Only)
All steps must work end-to-end in `scenes/ascii/` without any 3D/2D assets:
1. `Plant` carrot on `EMPTY` plot (`-5 xu`)
2. `Wait / Fast-forward` via `GameClock` (`GROWING` -> `READY`)
3. `Harvest` (`+2` carrots into `Inventory`, plot -> `EMPTY`)
4. `Complete Order` on `OrderBoard` (`4` carrots -> `+60 xu`)
5. `Unlock Plot` (`-120 xu`, `LOCKED` -> `EMPTY`)
6. `Save / Reload` (close & reopen, offline elapsed time accurately advances crop growth without data loss)

## Strictly Out of Scope for Phase 1
- Any 3D/2D art assets, animations, or sound effects
- `P2–P12` systems (multiple crops, tabbed UI, production chain, Hu Tieu restaurant, automation, Home/Pets, Garage, NPCs, multiplayer)
