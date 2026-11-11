# Automated Visual Gameplay Test Report

**Project**: Couple Chaos (Godot 4.7.2 3D Low-Poly Life Simulation)
**Date**: 2026-11-11T23:46:55
**Execution Summary**: 1 Scenarios Executed — **0 PASS**, **1 FAIL**, **0 BLOCKED**

## Executive Summary Table

| Test ID | Scenario Description | Status | Duration | GIF Evidence |
|---|---|---|---|---|
| `TC04` | Motorcycle Customer Arrival & Repair | 🔴 FAIL | 11.5s | [TC04_motorcycle_repair.gif](./TC04_motorcycle_repair.gif) |

---

## Detailed Test Case Results

### TC04 — Motorcycle Customer Arrival & Repair (🔴 FAIL)

- **Description**: Tests realistic customer arrival along the road path into Bay 0, driver dismounting and ordering repair, player walking to workbench to pick up patch kit, interacting at Bay 0 to apply patch and pump air, payment processing, and customer riding away.
- **Status**: 🔴 FAIL
- **Duration**: 11.5s
- **GIF Evidence**: `artifacts/gameplay-tests/TC04_motorcycle_repair.gif`
- **Expected Result**: Customer drives into bay naturally, order is accepted, player executes sequential repair steps via physical station interactions, wallet earns 35,000đ, and customer rides away safely.
- **Actual Result**: One or more assertions failed.

#### Assertions Executed:
- ✅ GarageBusiness exists
- ✅ Customer reached Bay 0 and is waiting for service
- ✅ Customer driver stepped off motorcycle
- ✅ Customer order registered in Bay 0
- ✅ Boy picked up patch kit from workbench via physical interaction
- ✅ Patch kit applied through station interaction; next step is pump_air
- ✅ Patch kit consumed from player inventory
- ✅ Order status marked PAID
- ✅ Household wallet received +35,000đ
- ✅ Customer celebrates completed service
- ❌ Customer departed on motorcycle along road

#### Reproduction Steps:
1. Position player at garage courtyard (-60, 0, -15).
2. Customer arrives on motorcycle via driveway approach waypoints.
3. Customer arrives at Bay 0, parks vehicle, rider steps off and requests repair.
4. Player walks to WorkbenchStation and presses [E] to retrieve patch kit.
5. Player walks to BikeBay_0 and presses [E] to patch customer tire.
6. Player presses [E] at BikeBay_0 to pump tire and finalize service.
7. Assert order marked PAID, wallet credited +35,000đ.
8. Customer mounts motorcycle and departs along road waypoints.

#### Related Source Files:
- `res://scripts/neighborhood/business/garage_business.gd`
- `res://scripts/neighborhood/business/motorcycle_customer.gd`
- `res://scripts/neighborhood/business/business_order.gd`

**Notes**: Verified natural customer arrival, workbench tool retrieval, bay patching & pumping station interactions, payout, and departure.

---

