# Automated Visual Gameplay Test Report

**Project**: Couple Chaos (Godot 4.7.2 3D Low-Poly Life Simulation)
**Date**: 2026-11-11T23:10:44
**Summary**: 1 Scenarios Executed — **1 PASS**, **0 FAIL**

## Executive Summary Table

| Test ID | Scenario Description | Status | Duration | GIF Evidence |
|---|---|---|---|---|
| `TC02` | House Exit | 🟢 PASS | 7.7s | [TC02_house_exit.gif](./TC02_house_exit.gif) |

---

## Detailed Test Case Results

### TC02 — House Exit (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 7.7s
- **GIF Evidence**: `artifacts/gameplay-tests/TC02_house_exit.gif`

#### Assertions Executed:
- ✅ House front door exists
- ✅ Door starts in closed state
- ✅ Door opened after E interaction
- ✅ Doorway collision disabled allowing pass-through
- ✅ Player walked out of house into front yard (Z <= 80)
- ✅ Player is within front yard bounds (Z >= 63)
- ✅ Camera tracks player smoothly
- ✅ Camera centered horizontally with player

**Notes**: Verified walking to door, E opening door, collision removal, and smooth walk out to yard.

