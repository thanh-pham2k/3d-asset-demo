# Design Principles

1. **Single Source of Truth:** Each type of information lives in one place (`docs/` for What & Why, `prompts/` for How to Execute, `data/` for balance config, `scripts/` for pure Game Core logic).
2. **ASCII-First, Gameplay First, Assets Later:** Validate the *Hay Day* core loop in **ASCII** (`scenes/ascii/`) during Phases 1–3 before investing in 3D presentation (`scenes/3d/` in Phase 1.5 spike & Phase 4).
3. **Game Core Decoupled from Presentation:** `scripts/` must never depend on `Label`, `Button`, `Node3D`, or `Camera3D`; presentation layers only observe state and invoke Game Core APIs.
4. **Minimal UI:** Favor direct interaction (clicking plot tiles) and compact HUD counters over nested menus.
5. **Data-Driven Balance:** Store crop timers, costs, and order rewards in `data/crops/`, `data/orders/`, and `data/upgrades/` rather than hard-coding numbers across scripts.
6. **Respect Scope:** In Phase 1 VERY MVP, do not add Garage, Hu Tieu shop, NPC AI, multiplayer, daily quests, furniture shopping, or complex 3D assets.
