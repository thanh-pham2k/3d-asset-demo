# Feature Matrix (ASCII-First)

| Feature | Reference Source | P1 (ASCII VERY MVP) | Alpha Expansion (`P2–P6`) | Feature ID |
| --- | --- | --- | --- | --- |
| Farm Grid & Interaction | Hay Day | Clickable ASCII plot tiles (`[ . ]`, `[ ~ ]`, `[ * ]`, `[ X ]`) in `scenes/ascii/` | 6–12 plots + batch plant/harvest (`P2`) | `FARM-001` |
| Real-Time Crop Growth | Hay Day | `CropTimer` driven by `GameClock.now()` + debug `advance()` | 5–8 crops with varied timers (`P2`) | `FARM-002` |
| Harvest | Hay Day | Click `READY` tile -> `+2` carrots to `Inventory` | Multi-crop yields & storage cap (`P2`) | `FARM-001` |
| Inventory | Hay Day | Carrot counter in `Inventory` & ASCII HUD | Shared multi-item storage + upgrades (`P2`, `P4`) | `ECON-002` |
| Wallet | Hay Day | Coin (`xu`) counter in `Wallet` & ASCII HUD | Shared `xu` + `XP` rewards (`P3–P6`) | `ECON-001` |
| Order Board | Hay Day | Single order: `4` carrots -> `+60 xu` | Multi-slot orders, special orders, refresh (`P3`) | `ORDER-001` |
| Land Expansion | Hay Day | Unlock `LOCKED` plot (`-120 xu`) | Level-gated plots & capacity (`P2–P3`) | `PROG-001` |
| Persistence | Hay Day | `SaveManager` (`save_version: 1`) + `GameClock` offline math | `save_version` migrations + bounded offline (`P2`, `P6`) | `SAVE-001` |
| Production & Restaurant | Family Farm / Animal Restaurant | Out of scope in `P1` | Recipes/queues (`P4`), Hu Tieu shop (`P5`), staff automation (`P6`) | `P4–P6` |
| Boy, Girl, Miu Miu, Garage | Pocket Love / Cat Snack Bar | Out of scope in `P1` | Deferred to `P7–P10` (`scenes/ascii/`, 3D deferred) | `P7–P10` |
