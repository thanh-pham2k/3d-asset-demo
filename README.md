# Couple Chaos

Single-player cozy farming & life-simulation game developed **ASCII-first** in **Godot 4.7.2** (*Gameplay First, Assets Later*).

## Development Roadmap (12 Phases, ASCII-First)
- **Stage A — Core Economy (`P1–P3`):**
  1. `P1` Core Farming VERY MVP *(implemented in ASCII; verify runtime)*
  2. `P2` Farming & Inventory Expansion
  3. `P3` Orders, Economy & Progression *(tabbed ASCII UI)*
- **Stage B — Production & Business (`P4–P6`, Playable Alpha):**
  4. `P4` Production Chain
  5. `P5` Hu Tieu Restaurant
  6. `P6` Automation & Offline Progression
- **Stage C–E — Cozy Life, Neighborhood & Polish (`P7–P12`):**
  7. `P7` Home & Couple Life
  8. `P8` Pets & Cozy Collection
  9. `P9` Garage & Delivery Network
  10. `P10` NPC, Neighborhood & Stories
  11. `P11` Long-Term Goals & Collections
  12. `P12` Balancing, Polish & Validation

All 3D assets, cameras, and animations are **deferred** until explicitly requested after gameplay is validated in ASCII. See [roadmap.md](docs/04-roadmap/roadmap.md) for details.

## Repository Structure

```text
3d-asset-demo/
├── AGENTS.md           # Rules & ASCII-first guardrails
├── project.godot       # Godot 4.7 project configuration (1280x720 windowed)
├── docs/               # Vision, 25-game research, design, technical specs, 12-phase roadmap
├── prompts/            # Feature execution & review prompts
├── scripts/            # Pure GDScript Game Core (no UI/3D dependencies)
│   ├── core/           # GameClock, BalanceLoader
│   ├── farming/        # FarmSystem, FarmPlot, CropTimer
│   ├── economy/        # Wallet, Inventory
│   ├── orders/         # OrderBoard
│   ├── progression/    # FarmUpgrade
│   └── persistence/    # SaveManager
├── scenes/
│   ├── ascii/          # Active ASCII playable prototype
│   └── 3d/             # Deferred until explicitly requested
├── data/               # Data-driven JSON balance configs
└── tests/              # Headless/unit tests (when needed)
```
