# Project Guidance — Couple Chaos (ASCII-First, 12-Phase Roadmap)

## 1. Development Strategy: Single-Player, ASCII-First, Gameplay First
- **Single-player only:** Boy, Girl, and Miu Miu share one unified game world. Multiplayer is out of scope.
- **ASCII-first:** Validate all gameplay, economy, progression, and retention in **ASCII** (`scenes/ascii/`) before any 3D work.
- **3D deferred:** Do **not** build Phase 1.5 3D spikes, 3D assets, `Camera3D`, meshes, or animations until explicitly requested.
- **Current Stage:** `P1` (Core Farming VERY MVP) implemented in ASCII and ready for runtime verification; next milestone is `P1–P6` **Playable Alpha**.
- **Approved 12-Phase Roadmap:**
  - `P1` Core Farming VERY MVP *(implemented, verify runtime)*
  - `P2` Farming & Inventory Expansion
  - `P3` Orders, Economy & Progression *(tabbed ASCII UI starts here)*
  - `P4` Production Chain
  - `P5` Hu Tieu Restaurant
  - `P6` Automation & Offline Progression *(Playable Alpha milestone)*
  - `P7` Home & Couple Life
  - `P8` Pets & Cozy Collection
  - `P9` Garage & Delivery Network *(logistics/delivery & unique rewards, not a redundant coin generator)*
  - `P10` NPC, Neighborhood & Stories
  - `P11` Long-Term Goals & Collections
  - `P12` Balancing, Polish & Validation

## 2. Architecture: Pure Game Core vs Presentation
- Keep **Game Core** (`scripts/`) completely decoupled from Godot UI/3D nodes (`Label`, `Button`, `Control`, `Node3D`, `MeshInstance3D`, `Camera3D`):
  - `FarmSystem` / `FarmPlot` / `CropTimer` (`EMPTY` / `GROWING` / `READY` / `LOCKED`)
  - `GameClock` (`now()`, `advance(seconds)`, `reset()`, `offline_elapsed()`)
  - `Wallet` (`xu` balance) & `Inventory` (shared storage)
  - `OrderBoard`, `FarmUpgrade`, `SaveManager` (shared across all phases)
- **Presentation (`scenes/ascii/`)** only reads state / calls Game Core methods and renders ASCII/Control UI.

## 3. Cross-Cutting Guardrails
- **No dead-ends (P2+):** Players must never get stuck with 0 coins, 0 seeds, and 0 crops.
- **Save compatibility (P1–P2+):** Maintain `save_version` and forward migrations with safe defaults.
- **Bounded offline progression:** Cap offline simulation so it never generates infinite coins/items.
- **Quality gate after every phase:** Validate the phase loop in ASCII before starting the next phase.
- **P1 Scope Guardrail:** Keep `P1` minimal (`Plant -> Wait/Fast-forward -> Harvest -> Complete Order -> Unlock Plot -> Save/Reload`); do not leak `P2–P12` features into `P1`.

## 4. Repository & Execution Rules
- **Read before editing:** Always read `AGENTS.md`, `docs/04-roadmap/roadmap.md`, and relevant `docs/` and `prompts/` before modifying code.
- **Keep structure minimal:** Only create folders and classes needed for the active phase.
- **Godot conventions:** `snake_case` for Godot files/folders, `PascalCase` for `class_name`, `kebab-case` for docs. Preserve `.tscn`, `.tres`, `.gd`, and `.uid` references.
- **Window mode:** Run the project in a window by default (`1280x720`), never fullscreen by default.
- **Testing:** Distinguish automated/headless checks from hands-on gameplay checks.
