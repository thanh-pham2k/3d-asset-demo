# Project guidance

- Couple Chaos is a Godot 4.7.2 3D prototype with a cozy, stylized cartoon **low-poly** visual direction. Preserve this style when adding or changing characters, furniture, environments, and effects.
- Use the supplied room reference as the layout and color guide: a wide, warm wooden room with cream walls, a green sofa, and a tiled kitchen area. Keep generous, unobstructed space for movement.
- Prefer primitive meshes for placeholders; avoid paid assets and external services unless the user asks for them.
- Keep character gameplay and collision independent of the visual model. Use the existing PlayerConfig and animation adapter so a placeholder can later be replaced by a GLB without rewriting gameplay.
- The current prototype is single-player. Preserve the current controls unless the user requests a change: WASD move, left Shift run, Space dash, E interact/pick up, F throw.
- Run the project in a window by default; do not enable fullscreen by default unless requested.
- After gameplay changes, run `godot --headless --path . --script res://tests/smoke.gd` with the installed Godot 4.7.2 executable. Distinguish automated checks from hands-on gameplay or visual checks.
