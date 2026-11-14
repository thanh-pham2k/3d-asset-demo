# UI / UX Guidelines — ASCII-First (`P1–P12`)

## P1–P2: Single-Screen ASCII Presentation (`scenes/ascii/`)
- No 3D models, textures, or complex UI assets needed.
- Render the farm grid cleanly using pure ASCII symbols (`#` / `-` progress bars, `[ . ]`, `[ ~*~ ]`, `[ *!* ]`, `[ XXX ]`) and simple Godot `Control` buttons/labels.
- Include a compact HUD bar: Coins (`xu`), Carrots (`Inventory`), `GameClock` display + Debug Time Travel buttons (`+1m`, `+5m`, `+1h`), `OrderBoard`, and `Save / Reload / Reset`.

## P3+: Tabbed ASCII Navigation
- Starting in **P3**, organize growing systems into clean ASCII tabs (`[1] Farm`, `[2] Orders`, `[3] Inventory`, `[4] Upgrades`, plus `[Production]` in `P4` and `[Restaurant]` in `P5`) while keeping a persistent top HUD (`xu`, `Level`, `XP`, `Next Goal`, `GameClock`).
- Keep `scenes/ascii/` strictly decoupled from `scripts/` Game Core logic.

## 3D Presentation (`scenes/3d/`) — Deferred
- All 3D prototypes, spikes, cameras, and assets are **deferred** until explicitly requested after ASCII gameplay validation.
