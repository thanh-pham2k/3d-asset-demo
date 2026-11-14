# Feature Matrix (VERY MVP)

| Feature | Reference Source | Implementation Approach | Feature ID |
| --- | --- | --- | --- |
| Fixed Isometric Camera | Hay Day | Fixed elevated isometric `Camera3D` framing the 3D farm and house | `FARM-001` |
| Click Farm Plot | Hay Day | Raycast/click on `FarmPlot` to plant or harvest | `FARM-001` |
| Real-Time Crop Growth | Hay Day | Unix timestamp tracking (`planted_at`, `duration_sec`) with offline progress | `FARM-002` |
| Harvest | Hay Day | Click `READY` crop to add `+2` carrots to `Inventory` | `FARM-001` |
| Inventory | Hay Day | Track carrot count | `ECON-002` |
| Wallet | Hay Day | Track player coins (`xu`) | `ECON-001` |
| Order Board | Hay Day | Fulfill order (`4` carrots -> `+60 xu`) | `ORDER-001` |
| Land Expansion | Hay Day | Unlock a `LOCKED` plot (`-120 xu`) | `PROG-001` |
| Persistence | Hay Day | Save/load plots, timers, inventory, wallet, and unlocked plots | `SAVE-001` |
| Cozy Farm Presentation | My Dear Farm | Low-poly pastel 3D yard, minimal HUD | — |
| Boy, Girl, Miu Miu | Pocket Love | Decorative characters placed in the house/yard (no gameplay AI) | — |
