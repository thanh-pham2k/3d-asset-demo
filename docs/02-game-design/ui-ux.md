# UI / UX Guidelines — ASCII-First (Phase 1–3)

## Phase 1–3: ASCII Presentation (`scenes/ascii/`)
- No 3D models, textures, or complex UI assets needed.
- Render the farm grid cleanly using ASCII/text symbols and simple Godot `Control` buttons/labels, for example:
  - `[ . ]` `EMPTY` (click to plant `-5 xu`)
  - `[ ~ ]` `GROWING` (shows remaining time, e.g. `04:12`)
  - `[ * ]` `READY` (click to harvest `+2` carrots)
  - `[ X ]` `LOCKED` (click or use Upgrade button `-120 xu`)
- Include a compact HUD bar:
  - Coins (`xu`), Carrots (`Inventory`), `GameClock` display + Debug Time Travel buttons (`+1m`, `+5m`, `+1h`), `OrderBoard` (`4 carrots -> +60 xu`), `Save / Reload` test indicator.

## Phase 1.5 & Phase 4: 3D Presentation (`scenes/3d/`)
- Only after the ASCII loop is verified: test a minimal 4–6 box-plot isometric scene (Phase 1.5), then swap in low-poly pastel assets (Phase 4) calling the exact same Game Core APIs.
