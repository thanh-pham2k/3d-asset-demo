# Project Guidance — Couple Chaos 3D (ASCII-First VERY MVP)

## 1. Development Strategy: ASCII-First, Gameplay First, Assets Later
- Validate gameplay, economy, progression, and retention in **ASCII** first before investing in 3D assets, animations, or polished UI.
- **Current Stage (Phase 1 — ASCII VERY MVP):** Use **ASCII presentation** (`scenes/ascii/`). Do **not** build complex 3D/2D assets, meshes, or animations right now.
- **Roadmap:**
  - `Phase 0`: Repository Foundation
  - `Phase 1`: ASCII VERY MVP (Hay Day core loop + `GameClock` deterministic time)
  - `Phase 1.5`: 3D Interaction Spike (4–6 simple box plots + fixed isometric camera to verify click feel, no real assets)
  - `Phase 2`: ASCII Gameplay Expansion
  - `Phase 3`: ASCII Vertical Slice (7-day loop & playtest)
  - `Phase 4`: Asset Integration (low-poly pastel 3D assets)

## 2. Architecture: Pure Game Core vs Presentation
- Keep **Game Core** (`scripts/`) completely decoupled from Godot UI/3D nodes (`Label`, `Button`, `Node3D`, `MeshInstance3D`):
  - `FarmSystem` (`EMPTY` / `GROWING` / `READY` / `LOCKED`)
  - `CropTimer` + `GameClock` (`now()`, `advance(seconds)`, `reset()`, `offline_elapsed()`)
  - `InventorySystem` (carrot count)
  - `EconomySystem` / `Wallet` (`xu` balance)
  - `OrderSystem` (`OrderBoard`: `4` carrots -> `+60 xu`)
  - `ProgressionSystem` (`FarmUpgrade`: `-120 xu` to unlock plot)
  - `SaveSystem` (`SaveManager`: save/load & offline timestamp progression)
- **Presentation (`scenes/ascii/`, later `scenes/3d/`)** only reads state / calls Game Core methods and renders characters/UI.

## 3. VERY MVP Scope Guardrails
- **Core loop to pass:** `Plant (-5 xu) -> Wait / Fast-forward -> Harvest (+2 carrots) -> Complete Order (4 carrots -> +60 xu) -> Unlock Plot (-120 xu) -> Save / Reload`.
- **Out of scope:** Garage, Hu Tieu shop, NPC AI, multiplayer, daily quests, multiple crop types, crafting/processing, energy system, furniture shop, complex 3D assets.

## 4. Repository & Execution Rules
- **Read before editing:** Always read the relevant `docs/` and `prompts/` before modifying code.
- **Keep structure minimal:** Only create folders and classes needed for the active phase.
- **Godot conventions:** `snake_case` for Godot files/folders, `PascalCase` for `class_name`, `kebab-case` for docs. Preserve `.tscn`, `.tres`, `.gd`, and `.uid` references.
- **Window mode:** Run the project in a window by default (`1280x720`), never fullscreen by default.
- **Testing:** Distinguish automated/headless checks from hands-on gameplay checks.
