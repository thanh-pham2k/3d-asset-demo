# Design Principles

1. **Single Source of Truth:** Each topic lives in one place (`docs/` for What & Why, `prompts/` for How to Execute, `data/` for balance config, `scripts/` for pure Game Core logic).
2. **Single-Player & Unified World:** One shared `Wallet`, `Inventory`, `GameClock`, `SaveManager`, and `Progression` across all systems. Multiplayer is out of scope.
3. **ASCII-First, 3D Deferred:** Validate all gameplay (`P1–P12`) in **ASCII** (`scenes/ascii/`). Do not build 3D spikes, cameras, or 3D assets until explicitly requested.
4. **Game Core Decoupled from Presentation:** `scripts/` must never depend on `Label`, `Button`, `Control`, `Node3D`, `MeshInstance3D`, or `Camera3D`; presentation layers only observe state and invoke Game Core APIs.
5. **Distinct System Roles:** Every new system must connect to existing systems and serve a unique role (e.g., Garage = delivery logistics & unique rewards, not a duplicate coin generator; Home/Pets = optional emotional/collection rewards, not mandatory daily chores or stat buffs).
6. **No Dead-Ends & Safe Persistence:** Starting `P2`, players must always have a recovery path if out of coins/seeds/crops, and save files must preserve compatibility via `save_version` migrations.
7. **Data-Driven Balance:** Store crop timers, costs, recipes, and rewards in `data/` rather than hard-coding numbers in scripts.
8. **Playtest Quality Gates:** Every phase must pass its ASCII playtest quality gate before advancing to the next phase.
