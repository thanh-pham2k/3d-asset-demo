# Design Principles

1. **Single Source of Truth:** Each type of information lives in one place (`docs/` for What & Why, `prompts/` for How to Execute, `data/` for balance config, `scripts/` for runtime logic).
2. **Playable Core First:** Validate the *Hay Day* core farming loop end-to-end before adding secondary systems.
3. **Low-Poly Pastel Cohesion:** Keep scenes readable from a fixed isometric camera with warm, cozy colors and unobstructed sightlines.
4. **Minimal UI:** Favor direct 3D interaction (clicking plots) and compact HUD counters over nested menus.
5. **Data-Driven Balance:** Store crop timers, costs, and order rewards in `data/` rather than hard-coding numbers across scripts.
6. **Respect Scope:** In VERY MVP, do not add Garage, Hu Tieu shop, NPC AI, multiplayer, daily quests, or furniture shopping.
