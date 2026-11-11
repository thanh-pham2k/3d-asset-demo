# Couple Chaos — Automated Visual Gameplay Testing System

This test suite executes real gameplay scenarios within a live Godot 4.7.2 windowed session, asserts internal gameplay and business state, and records viewport frames compiled into animated GIFs (960x540, 10–15 FPS) using Pillow (`PIL`).

## Directory Structure

```text
tests/visual/
  visual_test_runner.gd       # Master SceneTree test runner orchestrating all scenarios
  scenarios/
    scenario_base.gd          # Base class with movement, interaction and assertion helpers
    tc01_character_selection.gd
    tc02_house_exit.gd
    tc03_motorcycle_commute.gd
    tc04_motorcycle_repair.gd
    tc05_hutieu_preparation.gd
    tc06_hutieu_customer_service.gd
    tc07_incorrect_order.gd
    tc08_multiple_customers.gd
    tc09_navigation_camera.gd
    tc10_return_home_persistence.gd
  capture/
    frame_recorder.gd         # Captures live rendered viewport textures during execution
    make_gif.py               # Downscales and compiles PNG frames into optimized animated GIFs
  README.md

artifacts/gameplay-tests/
  TC01_character_selection.gif
  TC02_house_exit.gif
  TC03_motorcycle_commute.gif
  TC04_motorcycle_repair.gif
  TC05_hutieu_preparation.gif
  TC06_hutieu_customer_service.gif
  TC07_incorrect_order.gif
  TC08_multiple_customers.gif
  TC09_navigation_camera.gif
  TC10_return_home_persistence.gif
  test_report.md              # Detailed Markdown test report with assertion breakdown
```

## Running the Visual Test Suite

To run all 10 scenarios and generate GIF evidence:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual/visual_test_runner.gd
```

To run a single specific scenario (e.g. TC03):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual/visual_test_runner.gd -- --scenario=TC03
```
