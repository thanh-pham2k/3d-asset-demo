# Couple Chaos — 12-Phase ASCII-First Roadmap

> **Strategy:** Single-player only. All gameplay (`P1–P12`) is built and validated in **ASCII** (`scenes/ascii/`). **P1–P6** form the **Playable Alpha** milestone. All 3D work is deferred until explicitly requested.

## Unified System Dependency Diagram

```text
                OPEN GAME (GameClock + SaveManager)
                               |
                    COLLECT OFFLINE RESULTS
                               |
              +----------------+----------------+
              |                                 |
           FARMING (P1-P2)               PRODUCTION (P4)
              |                                 |
              +-------- SHARED INVENTORY -------+
                               |
              +----------------+----------------+
              |                                 |
          ORDERS (P1, P3)                RESTAURANT (P5)
              |                                 |
              +----------------+----------------+
                               |
                     SHARED WALLET (Xu + XP)
                               |
       +-----------------------+-----------------------+
       |                       |                       |
   REINVEST (P2-P6)      LOGISTICS (P9)        COZY LIFE (P7-P8)
   Farm/Shop/Auto        Garage Delivery       Home / Miu Miu
       |                       |                       |
       +-----------------------+-----------------------+
                               |
                  PROGRESSION & NEIGHBORHOOD (P3, P10-P11)
```

---

## Stage A — Core Economy (`P1–P3`)

### P1 — Core Farming VERY MVP *(Implemented in ASCII; verify runtime)*
- **References:** *Hay Day*
- **Loop:** `Plant (-5 xu) -> Wait/Fast-forward -> Harvest (+2 carrots) -> Complete Order (4 carrots -> +60 xu) -> Unlock Plot (-120 xu) -> Save/Reload`.
- **Modules:** `GameClock`, `BalanceLoader`, `Wallet`, `Inventory`, `CropTimer`, `FarmPlot`, `FarmSystem`, `OrderBoard`, `FarmUpgrade`, `SaveManager`, `scenes/ascii/ascii_farm_main.gd`.
- **Acceptance Criteria:** Full loop playable in `1280x720` ASCII window; save/reload preserves clock offset and offline crop maturity; zero parse/runtime errors.
- **Quality Gate:** Does the basic plant-harvest-order-unlock loop feel responsive and bug-free?

### P2 — Farming & Inventory Expansion *(Implementation-Ready)*
- **References:** *Hay Day*, *My Dear Farm*
- **Gameplay Loop:** Choose between fast/low-profit crops and slower/high-value crops; manage limited storage; expand from 6 to 12 plots; plant/harvest in batches.
- **Inputs / Outputs:** `Wallet` (seed cost, storage/plot upgrades) + `GameClock` -> `Inventory` (multi-crop storage with capacity cap).
- **Dependencies:** `P1` (`FarmSystem`, `CropTimer`, `Inventory`, `Wallet`, `SaveManager`, `BalanceLoader`).
- **Integration Points:**
  - `data/crops/*.json` defines 5–8 crops (`id`, `seed_cost`, `grow_duration_sec`, `harvest_yield`, `unlock_level`).
  - `Inventory` adds capacity limit + upgrade hook; `FarmSystem` supports batch plant/harvest.
  - **No Dead-End Rule:** Include a free starter/emergency seed or recovery action if `xu < min_seed_cost` and `Inventory` + `FarmPlots` are empty.
  - **Save Migration:** Upgrade `save_version` (`1 -> 2`) with safe defaults for new fields and backup before overwrite.
- **Acceptance Criteria:** 5–8 crops selectable in ASCII; storage cap enforced and upgradeable; 0-coin/0-seed recovery works; `save_version: 1` loads cleanly into `v2`.
- **ASCII Playtest Scenario:** Start with `v1` save or fresh game -> plant 2 crop types -> hit storage cap -> upgrade storage -> deplete coins/seeds and trigger recovery.
- **Quality Gate:** Are crop choices meaningful (short vs long) without tedious clicking?

### P3 — Orders, Economy & Progression *(Implementation-Ready)*
- **References:** *Hay Day*, *Township*, *Good Pizza, Great Pizza*
- **Gameplay Loop:** Inspect multi-slot Order Board (normal + special orders); decide which orders to fulfill or refresh/skip; earn `xu` + `XP`; level up to unlock crops, plots, and upgrades.
- **Inputs / Outputs:** `Inventory` (multi-crop items) -> `OrderBoard` -> `Wallet` (`xu`) + `Progression` (`XP`, `Level`, unlocks).
- **Dependencies:** `P2` (multi-crop `Inventory`).
- **Integration Points:**
  - Introduce **ProgressionSystem** (`XP`, `Level`, milestone unlocks) shared by all future phases.
  - Introduce **Tabbed ASCII Navigation** (`[1] Farm`, `[2] Orders`, `[3] Inventory`, `[4] Upgrades`) with persistent top HUD (`xu`, `Level`, `XP`, `Next Goal`, `GameClock`).
  - Order refresh/skip has a cooldown via `GameClock` to prevent infinite reroll exploits.
- **Acceptance Criteria:** Multi-order board generates valid orders from unlocked crops; XP/Level unlocks new crops/plots; tabbed ASCII HUD stays readable in `1280x720`.
- **ASCII Playtest Scenario:** Switch tabs -> skip an unfavorable order -> complete 2 orders -> level up -> verify new crop/plot unlocks.
- **Quality Gate:** Does deciding which order to fulfill and what to invest in feel engaging?

---

## Stage B — Production & Business (`P4–P6`, Playable Alpha Milestone)

### P4 — Production Chain *(Implementation-Ready)*
- **References:** *Family Farm Seaside*, *Tiller Town*
- **Gameplay Loop:** Choose whether to sell raw crops on `OrderBoard` for quick `xu` or queue them in processing stations to craft higher-value ingredients/goods.
- **Inputs / Outputs:** `Inventory` (raw crops) + `GameClock` + queue slots -> `Inventory` (processed goods).
- **Dependencies:** `P2` (multi-crop `Inventory`), `P3` (`Progression` unlocks, tabbed ASCII UI).
- **Integration Points:**
  - `ProductionSystem` (`data/recipes/*.json`) uses `GameClock` timestamps just like `CropTimer` (supports offline completion).
  - `OrderBoard` (`P3`) accepts both raw crops and processed goods for higher `xu`/`XP` rewards.
  - Add `[Production]` tab in ASCII UI; upgradeable queue capacity (`xu`).
- **Acceptance Criteria:** Recipes consume raw inputs, respect queue capacity, complete via `GameClock` (including offline), and feed `OrderBoard`.
- **ASCII Playtest Scenario:** Queue 2 recipes -> advance `GameClock` -> collect processed goods -> deliver high-value order.
- **Quality Gate:** Does processing create a real trade-off (quick cash vs higher margin) rather than busywork?

### P5 — Hu Tieu Restaurant *(Implementation-Ready)*
- **References:** *Animal Restaurant*, *Good Pizza, Great Pizza*
- **Gameplay Loop:** Allocate farm/production ingredients to cook Hu Tieu dishes, serve arriving customers (including special story/recipe customers), and upgrade tables/kitchen speed.
- **Inputs / Outputs:** `Inventory` (crops + processed ingredients) + `GameClock` -> `RestaurantSystem` -> `Wallet` (`xu` + `XP`) + recipe unlocks.
- **Dependencies:** `P4` (processed ingredients), `P3` (`Progression`, `Wallet`).
- **Integration Points:**
  - Add `[Restaurant]` tab in ASCII UI showing customer queue, kitchen slots, and service upgrades.
  - Competes with `OrderBoard` for `Inventory` ingredients, creating resource-allocation tension.
- **Acceptance Criteria:** Customers consume cooked dishes made from `Inventory`; kitchen upgrades increase capacity/speed; special customer unlocks a new dish.
- **ASCII Playtest Scenario:** Harvest & craft ingredients -> cook Hu Tieu -> serve 3 customers -> upgrade kitchen slot.
- **Quality Gate:** Does balancing ingredients between Orders and Restaurant feel rewarding?

### P6 — Automation & Offline Progression *(Playable Alpha Milestone — Implementation-Ready)*
- **References:** *Cats & Soup*, *Idle Farming Empire*
- **Gameplay Loop:** Hire/upgrade staff to auto-process recipes and auto-serve restaurant dishes using **actual available `Inventory`**; collect bounded offline progress on return; focus player decisions on investment & bottleneck balancing.
- **Inputs / Outputs:** `Wallet` (staff hire/upgrades) + `Inventory` (real stock only) + `GameClock.offline_elapsed()` -> automated `Production` & `Restaurant` output.
- **Dependencies:** `P4` (`ProductionSystem`), `P5` (`RestaurantSystem`), `P1` (`GameClock`, `SaveManager`).
- **Integration Points:**
  - **Bounded Offline Rule:** Cap offline simulation window (e.g., max `8 hours` configurable in `data/`) and stop automation whenever required `Inventory` ingredients hit `0` (never conjure free items/coins).
  - Show an ASCII **Offline Summary** modal/banner on load (`+items`, `+xu`, elapsed time).
- **Acceptance Criteria:** Staff automate queues without exceeding `Inventory` or offline cap; closing/reopening after simulated offline time produces accurate, bounded results.
- **ASCII Playtest Scenario:** Stock ingredients -> hire staff -> save & advance clock 10 hours -> reload -> verify offline summary capped at max window and ingredients consumed accurately.
- **Quality Gate (Alpha Gate):** Is the `P1–P6` loop (`Farming -> Production -> Restaurant -> Automation`) cohesive and fun for 5–15 minute sessions?

---

## Stage C–E — Cozy Life, Neighborhood & Polish (`P7–P12`, Integration-Contract Level)

> Detailed specs for `P7–P12` will be expanded only after `P1–P6` passes the Playable Alpha Quality Gate.

| Phase | Name | Primary Role & Integration Contract | Avoid / Guardrail |
| --- | --- | --- | --- |
| **P7** | **Home & Couple Life** | Single-player switches between Boy/Girl; spends `Wallet` (`xu`) to buy/arrange furniture & expand rooms; unlocks cozy interactions & collections. | No mandatory coin/stat buffs on furniture; no multiplayer. |
| **P8** | **Pets & Cozy Collection** | Miu Miu routines, toys, beds, and collectible expressions/moments funded by shared `Wallet`. | No second currency; no punishing decay/chores if offline. |
| **P9** | **Garage & Delivery Network** | Logistics hub: repair vehicles, upgrade delivery capacity/routes for Farm & Restaurant, earn unique/rare rewards & bounded side income. | **Not** a redundant coin generator competing with Restaurant. |
| **P10** | **NPC, Neighborhood & Stories** | Unlockable neighborhood areas, recurring NPCs with preferences, short stories tied to Orders/Restaurant/Garage. | Uses existing `Progression`, `OrderBoard`, and `Wallet`. |
| **P11** | **Long-Term Goals & Collections** | Optional daily/weekly cross-system goals, encyclopedia collections (crops, dishes, furniture, pets), and long-term milestones. | Never force daily login streaks or tedious chores. |
| **P12** | **Balancing, Polish & Validation** | 7–30 day economy simulation, inflation/bottleneck tuning, save-migration & recovery stress tests, cut low-value bloat. | Verify all 7 Feature Design Gate checks pass. |

---

## Cross-Cutting Requirements & Risk Register

| Risk | Mitigation | Starts At |
| --- | --- | --- |
| Economic dead-end (0 xu, 0 seeds, 0 crops) | Free recovery seed / emergency action | `P2` |
| Broken saves across updates | `save_version` migrations + safe defaults + backup | `P1–P2` |
| Infinite offline coins/items | Hard offline cap + consume real `Inventory` only | `P1` / `P6` |
| ASCII UI clutter as systems grow | Tabbed navigation + consistent top HUD | `P3` |
| Scope creep / 3D distraction | Defer all 3D until `P1–P6` Alpha passes playtest | `P1+` |
