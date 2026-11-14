# VERY MVP Roadmap & Acceptance Criteria (ASCII-First)

## Active Roadmap
1. **Phase 0 — Repository Foundation:** Clean minimal folders, `AGENTS.md`, design docs, prompts.
2. **Phase 1 — ASCII VERY MVP:** Pure Game Core + `GameClock` + `scenes/ascii/` playable prototype. No 3D/2D assets.
3. **Phase 1.5 — 3D Interaction Spike:** Minimal 4–6 box-plot isometric scene to verify click-to-plant/harvest feel.
4. **Phase 2 — ASCII Gameplay Expansion:** More crops, orders, upgrades, offline rewards, economy tuning.
5. **Phase 3 — ASCII Vertical Slice:** 7-day experience & user playtest.
6. **Phase 4 — Asset Integration:** Replace ASCII with low-poly pastel 3D assets, animation, and audio.

## Phase 1 (ASCII VERY MVP) Completion Loop
All steps must work end-to-end in ASCII **without any 3D/2D assets**:
1. `Plant` carrot on `EMPTY` plot (`-5 xu`)
2. `Wait / Fast-forward` via `GameClock` (`GROWING` -> `READY`)
3. `Harvest` (`+2` carrots into `Inventory`, plot -> `EMPTY`)
4. `Complete Order` on `OrderBoard` (`4` carrots -> `+60 xu`)
5. `Unlock Plot` (`-120 xu`, `LOCKED` -> `EMPTY`)
6. `Save / Reload` (close & reopen, offline elapsed time accurately advances crop growth without data loss)

## Strictly Out of Scope for Phase 1
- Any 3D/2D art assets, animations, or sound effects
- Garage, Hu Tieu shop, NPC AI, multiplayer, daily quests, multiple crops, crafting, energy system, furniture shop
