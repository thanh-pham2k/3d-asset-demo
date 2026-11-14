# Couple Chaos 3D

Cozy farming & life-sim developed **ASCII-first** in **Godot 4.7.2** (*Gameplay First, Assets Later*).

## Development Phases
1. **Phase 0 — Repository Foundation:** Clean structure, docs, and prompts.
2. **Phase 1 — ASCII VERY MVP:** *Hay Day* core loop (`Plant -> Wait/Fast-forward -> Harvest -> Order -> Unlock Plot -> Save/Reload`) in ASCII + deterministic `GameClock`.
3. **Phase 1.5 — 3D Interaction Spike:** Minimal 4–6 box-plot isometric prototype to validate click feel.
4. **Phase 2 — ASCII Gameplay Expansion:** More crops, orders, upgrades, offline rewards.
5. **Phase 3 — ASCII Vertical Slice:** 7-day loop & playtest.
6. **Phase 4 — Asset Integration:** Swap ASCII view for low-poly pastel 3D assets without rewriting Game Core.

## Minimal Repository Structure

```text
3d-asset-demo/
├── AGENTS.md           # Rules & ASCII-first VERY MVP guardrails
├── project.godot       # Godot 4.7 project configuration
├── docs/               # Research, game design, technical specs, roadmap
├── prompts/            # Gameplay & asset prompts
├── scripts/            # Pure GDScript Game Core (no UI/3D dependencies)
│   ├── core/           # GameClock, game state, events
│   ├── farming/        # FarmSystem, FarmPlot, CropTimer
│   ├── economy/        # EconomySystem, Wallet, InventorySystem
│   ├── orders/         # OrderSystem, OrderBoard
│   ├── progression/    # ProgressionSystem, FarmUpgrade
│   └── persistence/    # SaveSystem, SaveManager
├── scenes/
│   ├── ascii/          # Phase 1–3 ASCII playable prototype
│   └── 3d/             # Phase 1.5 spike & Phase 4 3D presentation
├── data/               # Crops, orders, upgrades balance config
├── tests/              # Headless/unit tests for Game Core
└── assets/             # Reserved for Phase 4 (unused during ASCII phases)
```
