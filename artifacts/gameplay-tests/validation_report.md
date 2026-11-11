# Couple Chaos — Visual Validation Report

**Generated:** 2026-11-11T23:44:26

## Summary Table

| Test ID | Title | Status | Duration | Evidence GIF |
|---|---|---|---|---|
| TC01 | Motorcycle Repair Messages | 🟢 **PASS** | 6.1s | [TC01_repair_messages.gif](artifacts/gameplay-tests/TC01_repair_messages.gif) |
| TC02 | Minimap and Expanded Map | 🟢 **PASS** | 7.0s | [TC02_minimap_expanded_map.gif](artifacts/gameplay-tests/TC02_minimap_expanded_map.gif) |
| TC03 | Boy/Girl Motorcycle Riding Poses | 🟢 **PASS** | 6.5s | [TC03_riding_poses.gif](artifacts/gameplay-tests/TC03_riding_poses.gif) |
| TC04 | Hu Tieu Customer Sitting and Eating | 🟢 **PASS** | 3.8s | [TC04_customer_sitting_eating.gif](artifacts/gameplay-tests/TC04_customer_sitting_eating.gif) |

## Detailed Test Cases

### TC01 — Motorcycle Repair Messages
- **Status:** PASS
- **Evidence GIF:** `artifacts/gameplay-tests/TC01_repair_messages.gif`
- **Notes:** Verified clear guidance when empty-handed, workbench tool pickup, next action prompts, and non-overlapping labels.
- **Assertions (14 executed):**
  - ✅ GarageBusiness exists
  - ✅ BikeBay_0 exists
  - ✅ Prompt guides player: 'Cần lấy bộ vá săm ở Bàn Thợ trước!'
  - ✅ Speech label sits above bay label (no overlapping text)
  - ✅ WorkbenchStation exists
  - ✅ Workbench prompts: 'Lấy bộ vá săm & keo dán'
  - ✅ Boy picked up patch kit from workbench via physical interaction
  - ✅ Prompt with patch kit: 'Dán miếng vá săm (Khoang 1)'
  - ✅ Patch kit applied through station interaction; next step is pump_air
  - ✅ Patch kit consumed from player inventory
  - ✅ Prompt guides next step: 'Bơm lốp xe (Khoang 1)'
  - ✅ Order status marked PAID
  - ✅ Household wallet received +35,000đ
  - ✅ Customer celebrates completed service

### TC02 — Minimap and Expanded Map
- **Status:** PASS
- **Evidence GIF:** `artifacts/gameplay-tests/TC02_minimap_expanded_map.gif`
- **Notes:** Verified bottom-right HUD minimap, real-time player orientation, M key modal toggle, landmark pins, and smooth return to gameplay.
- **Assertions (8 executed):**
  - ✅ InteractiveMinimap node exists
  - ✅ HUD minimap visible at bottom-right
  - ✅ Minimap expanded state is active
  - ✅ Expanded modal window is visible
  - ✅ All neighborhood landmarks registered on map
  - ✅ Expanded map modal closed
  - ✅ Modal window hidden
  - ✅ HUD minimap remains active

### TC03 — Boy/Girl Motorcycle Riding Poses
- **Status:** PASS
- **Evidence GIF:** `artifacts/gameplay-tests/TC03_riding_poses.gif`
- **Notes:** Verified natural sitting posture, hands on handlebars, feet on footboard, leaning into turns, for both Boy and Girl models.
- **Assertions (11 executed):**
  - ✅ Neighborhood world exists
  - ✅ Boy scooter exists
  - ✅ Girl scooter exists
  - ✅ Boy successfully mounted scooter
  - ✅ Player visual node exists
  - ✅ Boy hips aligned at seat height (y=0.46)
  - ✅ Motorcycle and rider lean realistically into turn
  - ✅ Boy dismounted scooter
  - ✅ Girl successfully mounted scooter
  - ✅ Girl hips aligned flush on seat cushion
  - ✅ Girl dismounted scooter

### TC04 — Hu Tieu Customer Sitting and Eating
- **Status:** PASS
- **Evidence GIF:** `artifacts/gameplay-tests/TC04_customer_sitting_eating.gif`
- **Notes:** Verified full WALK -> SIT -> ORDER -> EAT -> STAND -> LEAVE cycle, accurate chair alignment, leg bending, and slurp animation.
- **Assertions (10 executed):**
  - ✅ HuTieuBusiness exists
  - ✅ Customer state is WALKING_TO_TABLE (WALK)
  - ✅ Transitioned to SEATED_ORDERING (SIT)
  - ✅ Customer diner visual exists
  - ✅ Legs bent naturally downward in front of chair (not clipping table)
  - ✅ Arms resting gently on table surface
  - ✅ Transitioned to EATING
  - ✅ Steaming noodle bowl placed on table
  - ✅ Customer stood up and transitioned to LEAVING
  - ✅ Leg rotations restored to upright standing posture

