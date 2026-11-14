# Feature Matrix (VERY MVP — Phased)

| Feature | Reference Source | Phase 1 (ASCII-First) | Phase 1.5 / Phase 4 (3D Later) | Feature ID |
| --- | --- | --- | --- | --- |
| Farm Grid & Interaction | Hay Day | Clickable ASCII plot tiles (`[ . ]`, `[ ~ ]`, `[ * ]`, `[ X ]`) in `scenes/ascii/` | Fixed isometric `Camera3D` + 3D box spike (Phase 1.5) -> low-poly plots (Phase 4) | `FARM-001` |
| Real-Time Crop Growth | Hay Day | `CropTimer` driven by `GameClock.now()` + debug `advance()` | Same Game Core, 3D growth stages | `FARM-002` |
| Harvest | Hay Day | Click `READY` tile -> `+2` carrots to `Inventory` | Same Game Core + harvest feedback/VFX | `FARM-001` |
| Inventory | Hay Day | Carrot counter in `Inventory` & ASCII HUD | Same Game Core + icon HUD | `ECON-002` |
| Wallet | Hay Day | Coin (`xu`) counter in `Wallet` & ASCII HUD | Same Game Core + icon HUD | `ECON-001` |
| Order Board | Hay Day | Button/panel: `4` carrots -> `+60 xu` | Same Game Core + 3D/illustrated board | `ORDER-001` |
| Land Expansion | Hay Day | Unlock `LOCKED` plot (`-120 xu`) | Same Game Core + 3D plot unlock | `PROG-001` |
| Persistence | Hay Day | `SaveManager` (`save_version: 1`) + `GameClock` offline math | Same Game Core | `SAVE-001` |
| Cozy Farm Presentation | My Dear Farm | Clean minimal ASCII layout | Low-poly pastel 3D yard (Phase 4) | — |
| Boy, Girl, Miu Miu | Pocket Love | Deferred (not needed in ASCII Phase 1) | Decorative 3D characters in house/yard (Phase 4) | — |
