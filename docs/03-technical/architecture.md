# Unified Gameplay Architecture — Couple Chaos (12-Phase ASCII-First)

> **Scope:** Single-player unified world. **P1–P6** are specified in implementation-ready detail; **P7–P12** are defined at integration-contract level. All presentation remains in `scenes/ascii/` (3D deferred).

---

## 1. Layering & Dependency Rules (No Circular Dependencies)

Game Core (`scripts/`) must **never** reference Godot UI/3D nodes (`Label`, `Button`, `Control`, `Node3D`, `MeshInstance3D`, `Camera3D`) or `scenes/`. Dependencies flow strictly downward:

```text
+-----------------------------------------------------------------------+
| PRESENTATION LAYER (scenes/ascii/)                                    |
| - Reads state via WorldState / getters & listens to signals           |
| - Dispatches player actions; renders ASCII tiles, tabs, HUD, logs     |
+-----------------------------------+-----------------------------------+
                                    | calls actions / reads snapshots
                                    v
+-----------------------------------------------------------------------+
| COORDINATOR & SHARED SERVICES (scripts/core/, progression/, persist/) |
| - WorldState (owns system instances & cross-system transactions)      |
| - GameClock (deterministic Unix time + debug offset)                  |
| - ProgressionSystem (XP, Level, UnlockRules, RewardHandling)          |
| - SaveManager (schema versioning, migrations, atomic save/load)       |
+-----------------------------------+-----------------------------------+
                                    | orchestrates
          +-------------------------+-------------------------+
          v                         v                         v
+-------------------+   +-----------------------+   +-------------------+
| SHARED ECONOMY    |   | ALPHA DOMAIN (P1-P6)  |   | LIFE & WORLD      |
| (scripts/economy/)|   | - FarmSystem (P1-P2)  |   | CONTRACTS (P7-P10)|
| - Wallet (xu)     |   | - OrderBoard (P1, P3) |   | - HomeSystem (P7) |
| - Inventory       |   | - Production (P4)     |   | - PetSystem (P8)  |
|   (items + cap)   |   | - Restaurant (P5)     |   | - Garage (P9)     |
|                   |   | - Automation (P6)     |   | - Neighborhood(10)|
+-------------------+   +-----------------------+   +-------------------+
          ^                         |                         |
          +-------------------------+-------------------------+
          (Domain modules depend ONLY on Wallet, Inventory, GameClock,
           Progression/UnlockRules, and BalanceLoader — NEVER on each other)
```

**Anti-Circular Rule:** Domain modules (`FarmSystem`, `OrderBoard`, `ProductionSystem`, `RestaurantSystem`, `GarageSystem`) must **not** directly reference each other. Cross-system interactions (e.g., Farming supplying Restaurant, Garage boosting Order/Restaurant delivery) happen exclusively through **Shared Inventory**, **Shared Wallet**, **Progression/UnlockRules**, or **WorldState** orchestration.

---

## 2. Shared Systems: Responsibilities & Data Ownership

| System | Folder | Owns (Single Source of Truth) | Current `P1` Status & `P2–P6` Evolution |
| --- | --- | --- | --- |
| **WorldState** *(P2+)* | `scripts/core/` | Composition root holding `GameClock`, `Wallet`, `Inventory`, `ProgressionSystem`, and active domain systems; executes multi-system transactions & `tick()`. | In `P1`, `ascii_farm_main.gd` holds references directly; extract into `WorldState` in `P2` before adding tabs/systems. |
| **GameClock** | `scripts/core/` | `clock_offset_sec`; deterministic `now()`, `advance()`, `reset()`, `offline_elapsed()`. | Implemented (`game_clock.gd`). All timers use `GameClock.now()`. |
| **BalanceLoader** | `scripts/core/` | Read-only JSON config cache (`data/crops/`, `orders/`, `upgrades/`, `recipes/`, `dishes/`). | Implemented (`balance_loader.gd`). |
| **Wallet** | `scripts/economy/` | `balance` (`xu` integer >= 0); `can_afford()`, `spend()`, `earn()`. | Implemented (`wallet.gd`). Single currency across all 12 phases. |
| **Inventory** | `scripts/economy/` | `items: Dictionary` (`item_id -> count`), `capacity` (`P2+`); `has_item()`, `add_item()`, `remove_item()`, `free_space()`. | Implemented (`inventory.gd`). Add `capacity` & batch checks in `P2`. |
| **Progression** *(P3+)* | `scripts/progression/` | `xp`, `level`, `unlocked_ids: Dictionary/Set`, `milestones_claimed`. | `P1` has `FarmUpgrade` only; `P3` adds `ProgressionSystem` unifying XP, Level, and unlocks. |
| **UnlockRules** *(P3+)* | `scripts/progression/` | Pure evaluation: `is_unlocked(feature_or_item_id, progression_state) -> bool` from `data/`. | Prevents scattered `if level >= X` checks across UI and domains. |
| **RewardHandling** *(P3+)* | `scripts/core/` | `RewardBundle` (`xu`, `xp`, `items`, `unlocks`, `cosmetics`) applied atomically via `WorldState`. | Ensures Orders, Restaurant, Garage, and Goals grant rewards consistently. |
| **SaveManager** | `scripts/persistence/` | Serialization, `save_version`, schema migration, backup, and load-time `offline_elapsed` reconciliation. | Implemented (`save_manager.gd`, `v1`). Extend via migrations in `P2+`. |

---

## 3. Domain Module Integration Contracts

### A. Playable Alpha (`P1–P6`, Implementation-Ready)

1. **FarmSystem / FarmPlot / CropTimer (`P1–P2`)**
   - **Owns:** `plots: Array[FarmPlot]` (`id`, `state`, `crop_id`, `CropTimer`).
   - **State Machine:** `LOCKED -> EMPTY -> GROWING -> READY -> EMPTY`.
   - **Contract:** `plant_plot()` validates `EMPTY` + `UnlockRules` + `Wallet.spend(seed_cost)` -> starts `CropTimer(clock.now(), duration)`. `harvest_plot()` validates `READY` + `Inventory.free_space()` -> `Inventory.add_item()` -> resets plot to `EMPTY`.
   - **Supplies:** Raw crops into shared `Inventory` for `OrderBoard`, `ProductionSystem`, and `RestaurantSystem`.

2. **OrderBoard (`P1, P3`)**
   - **Owns:** Active order slots (`order_id`, `requirements: Dictionary`, `reward: RewardBundle`, `expires_or_refresh_at_unix`).
   - **Contract:** Reads `UnlockRules` to generate valid orders; `deliver()` atomically verifies & removes `requirements` from `Inventory` -> applies `RewardBundle` (`xu` + `XP`).
   - **No Duplication:** Never spawns free items; strictly consumes `Inventory`.

3. **ProductionSystem (`P4`)**
   - **Owns:** Stations & crafting queues (`recipe_id`, `started_at_unix`, `duration_sec`, `max_slots`).
   - **Contract:** `queue_recipe()` validates `UnlockRules` + `Inventory.has_items(inputs)` -> deducts inputs immediately -> records `GameClock.now()` start. `collect()` (or auto-collect if space) moves output to `Inventory` when `now >= started_at + duration`.

4. **RestaurantSystem (`P5`)**
   - **Owns:** Kitchen cooking slots, served/waiting customer queue, table/kitchen upgrade levels, unlocked Hu Tieu dishes.
   - **Contract:** Cooking **must consume real `Inventory` ingredients** (raw crops + `P4` processed items). Serving completes customer order -> applies `RewardBundle` (`xu` + `XP` + special customer recipe unlock).

5. **AutomationSystem (`P6`)**
   - **Owns:** Hired staff roles, speed/capacity tiers, last automated simulation timestamp.
   - **Contract:** On `tick(clock)` and load-time offline catch-up, staff may queue `Production` or cook/serve `Restaurant` **only while required `Inventory` items exist**. Never generates items or coins out of thin air.

### B. Cozy Life & World Expansion (`P7–P12`, Integration-Contract Level)

| Phase | System | Consumes | Produces / Modifies | Contract Guardrail |
| --- | --- | --- | --- | --- |
| **P7** | `HomeSystem` | `Wallet` (`xu`), `UnlockRules` | Placed furniture, room layout, Boy/Girl active state, collection progress | Purely optional emotional/cosmetic rewards; zero mandatory coin/stat buffs. |
| **P8** | `PetSystem` | `Wallet` (`xu`), home items | Miu Miu interactions, mood/moments, pet collection entries | Uses shared `Wallet`; no second currency; no punishing offline decay. |
| **P9** | `GarageSystem` | `Wallet` (`xu`), `GameClock`, orders | Delivery routes, capacity/speed modifiers for `OrderBoard`/`Restaurant`, rare cosmetic/item rewards, capped side `xu` | Logistics & unique rewards only; never competes as a redundant coin farm. |
| **P10** | `NeighborhoodSystem` | `Progression`, `OrderBoard`/`Restaurant`/`Garage` | Unlocked areas, NPC requests, short story flags | Generates demand for existing `P1–P9` systems via `OrderBoard`/special guests. |
| **P11** | `GoalSystem` | Cross-system events/signals | Optional daily/weekly & milestone rewards (`RewardBundle`) | Non-mandatory; progress persists across sessions. |

---

## 4. State Transitions & Transaction Boundaries

Every player or automation action follows a strict **Validate -> Deduct -> Mutate/Grant -> Emit -> Auto-Save** boundary inside Game Core:

1. **Validate all preconditions first** (`UnlockRules`, `Wallet.can_afford`, `Inventory.has_items`, `Inventory.free_space`, plot/slot state). If any check fails, return `{"ok": false, "reason": "..."}` with **zero state mutation**.
2. **Deduct costs/inputs** (`Wallet.spend`, `Inventory.remove_item`). For multi-item recipes/orders, check all items before removing any so partial deductions cannot occur.
3. **Mutate domain state or grant rewards** (`plot.plant`, `RewardHandling.apply`).
4. **Emit signals** (`coins_changed`, `inventory_changed`, `plot_changed`, `progression_changed`) for ASCII UI refresh.
5. **Trigger `SaveManager`** at transaction boundaries (or throttled on `tick` when items mature).

---

## 5. Offline Time Handling

- **Single Clock:** `GameClock.now() = Time.get_unix_time_from_system() + clock_offset_sec`.
- **P1–P5 (Timestamp Completion):** Plots and Production/Cooking slots store `started_at_unix` and `duration_sec`. On load, `clock.offline_elapsed(saved_at_real_unix)` is computed and `tick(clock)` transitions any elapsed timers to `READY`.
- **P6+ (Bounded Offline Simulation):**
  - Cap simulated offline automation window (e.g., `max_offline_sec = 28800` / 8 hours, configured in `data/`).
  - Step/simulate `Production` & `Restaurant` automation using **only** existing `Inventory` + crops/queues that finish within the capped window.
  - Return a structured `OfflineSummary` (`elapsed_sec`, `capped_sec`, `items_crafted`, `dishes_served`, `xu_earned`) to display once on load.

---

## 6. Error, Dead-End & Recovery Behavior

- **Economic Dead-End Prevention (`P2+`):** If `Wallet.balance < min_seed_cost`, `Inventory` has no sellable/plantable items, and no `FarmPlot` is `GROWING`/`READY`, `WorldState` enables an automatic/manual **Emergency Recovery** (e.g., free starter seed or forage action) so the player can never soft-lock.
- **Storage Full (`P2+`):** Harvesting into a full `Inventory` is blocked cleanly (`{"ok": false, "reason": "Kho đầy"}`), leaving the `READY` crop safely on the plot until the player delivers an order, cooks, or upgrades storage.
- **Corrupt / Missing Save:** `SaveManager.load_game()` validates JSON structure and required keys; on corruption, it preserves the broken file as `.bak` and falls back to a clean default `WorldState` instead of crashing.

---

## 7. Architectural Risks & Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| **God-Object UI (`ascii_farm_main.gd`)** | UI absorbs business logic as tabs grow in `P3–P6`. | Extract `WorldState` in `P2`; UI only binds tabs to `WorldState` APIs. |
| **Circular Module Dependencies** | `Restaurant` importing `FarmSystem` directly breaks modularity. | Enforce dependency rule: domains communicate only via `Inventory`, `Wallet`, `Progression`, and `WorldState`. |
| **Partial-Deduction Bugs** | Multi-ingredient recipes/orders fail midway and lose items. | Validate all inputs before mutating; centralize multi-item consumption in `Inventory.remove_items(dict)`. |
| **Unbounded Offline Exploits** | System clock jumps or infinite automation break economy. | Hard offline cap in `P6` + real `Inventory` consumption check. |
| **Save Breakage Across Phases** | Adding `Inventory` cap, `Progression`, `Production` breaks `v1` saves. | Increment `save_version` per schema change with explicit forward migrations in `SaveManager`. |
