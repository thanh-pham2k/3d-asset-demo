# Automated Visual Gameplay Test Report

**Project**: Couple Chaos (Godot 4.7.2 3D Low-Poly Life Simulation)
**Date**: 2026-11-11T15:50:00
**Summary**: 10 Scenarios Executed — **10 PASS**, **0 FAIL**

## Executive Summary Table

| Test ID | Scenario Description | Status | Duration | GIF Evidence |
|---|---|---|---|---|
| `TC01` | Character Selection | 🟢 PASS | 4.5s | [TC01_character_selection.gif](./TC01_character_selection.gif) |
| `TC02` | House Exit | 🟢 PASS | 7.2s | [TC02_house_exit.gif](./TC02_house_exit.gif) |
| `TC03` | Motorcycle Commute | 🟢 PASS | 25.7s | [TC03_motorcycle_commute.gif](./TC03_motorcycle_commute.gif) |
| `TC04` | Motorcycle Repair | 🟢 PASS | 8.9s | [TC04_motorcycle_repair.gif](./TC04_motorcycle_repair.gif) |
| `TC05` | Hu Tieu Preparation | 🟢 PASS | 6.3s | [TC05_hutieu_preparation.gif](./TC05_hutieu_preparation.gif) |
| `TC06` | Hu Tieu Customer Service | 🟢 PASS | 9.3s | [TC06_hutieu_customer_service.gif](./TC06_hutieu_customer_service.gif) |
| `TC07` | Incorrect Order | 🟢 PASS | 3.7s | [TC07_incorrect_order.gif](./TC07_incorrect_order.gif) |
| `TC08` | Multiple Customers | 🟢 PASS | 4.5s | [TC08_multiple_customers.gif](./TC08_multiple_customers.gif) |
| `TC09` | Navigation & Camera | 🟢 PASS | 4.0s | [TC09_navigation_camera.gif](./TC09_navigation_camera.gif) |
| `TC10` | Return Home & Persistence | 🟢 PASS | 7.9s | [TC10_return_home_persistence.gif](./TC10_return_home_persistence.gif) |

---

## Detailed Test Case Results

### TC01 — Character Selection (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 4.5s
- **GIF Evidence**: `artifacts/gameplay-tests/TC01_character_selection.gif`

#### Assertions Executed:
- ✅ Character is Boy
- ✅ Boy 3D visual model is active
- ✅ Boy starts inside shared house interior (Z > 83)
- ✅ Character switched to Girl
- ✅ Girl 3D visual model is active
- ✅ Girl remains inside shared house interior

**Notes**: Verified Boy and Girl selection, visual meshes, and initial spawn inside house.

### TC02 — House Exit (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 7.2s
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

### TC03 — Motorcycle Commute (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 25.7s
- **GIF Evidence**: `artifacts/gameplay-tests/TC03_motorcycle_commute.gif`

#### Assertions Executed:
- ✅ Boy's commuter motorcycle exists
- ✅ Motorcycle is available for mounting
- ✅ Player mounted motorcycle
- ✅ Kickstand folded up automatically
- ✅ Player meta indicates riding state
- ✅ Player dismounted motorcycle
- ✅ Kickstand put down upon parking
- ✅ Motorcycle neatly parked in garage bay
- ✅ Player arrived at garage workplace without teleporting

**Notes**: Verified walking to bike, mounting, driving entire road path to garage, parking, and dismounting.

### TC04 — Motorcycle Repair (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 8.9s
- **GIF Evidence**: `artifacts/gameplay-tests/TC04_motorcycle_repair.gif`

#### Assertions Executed:
- ✅ GarageBusiness exists
- ✅ Customer parked and waiting for service
- ✅ Customer driver stepped off motorcycle
- ✅ Boy picked up patch kit from workbench
- ✅ Patch kit applied, next step is pump_air
- ✅ Order status marked PAID
- ✅ Household wallet received +35,000đ
- ✅ Customer celebrates completed service
- ✅ Customer departed on motorcycle

**Notes**: Verified customer arrival, parking, sequential repair (patch kit + pump), payment, and riding away.

### TC05 — Hu Tieu Preparation (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 6.3s
- **GIF Evidence**: `artifacts/gameplay-tests/TC05_hutieu_preparation.gif`

#### Assertions Executed:
- ✅ HuTieuBusiness exists
- ✅ Shop starts in CLOSED state
- ✅ Shop is closed, customers blocked
- ✅ Shop entered PREPARING phase
- ✅ Preparation reached 100%
- ✅ Shop entered READY state
- ✅ Prompt offers to open shop
- ✅ Shop officially entered OPEN state
- ✅ is_open flag is true
- ✅ Overhead billboard reflects shop open status

**Notes**: Verified CLOSED state, gradual 0%->100% preparation, READY state, and explicit player E open interaction.

### TC06 — Hu Tieu Customer Service (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 9.3s
- **GIF Evidence**: `artifacts/gameplay-tests/TC06_hutieu_customer_service.gif`

#### Assertions Executed:
- ✅ HuTieuBusiness exists
- ✅ Customer is seated on chair
- ✅ Customer placed order for 'Hủ tiếu Nam Vang'
- ✅ Noodles blanched and cooked
- ✅ Hot bone broth ladled into bowl
- ✅ Bowl fully prepared
- ✅ Prepared dish is 'Hủ tiếu Nam Vang'
- ✅ Order marked PAID
- ✅ Shared wallet credited +45,000đ
- ✅ Customer is eating served food
- ✅ Hot noodle bowl visible on dining table
- ✅ Customer stood up and departed

**Notes**: Verified seating, ordering, cooking sequence (blanch, broth, toppings), serving, payment, and departure.

### TC07 — Incorrect Order (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 3.7s
- **GIF Evidence**: `artifacts/gameplay-tests/TC07_incorrect_order.gif`

#### Assertions Executed:
- ✅ HuTieuBusiness exists
- ✅ Bowl prepared
- ✅ Prepared dish is 'Hủ tiếu sườn heo'
- ✅ Customer ordered different dish 'Hủ tiếu Nam Vang'
- ✅ Order REJECTED and remains PENDING
- ✅ Zero reward granted for incorrect dish
- ✅ Kitchen bowl was not consumed
- ✅ Wrong bowl safely discarded to allow remaking
- ✅ Bowl dish cleared

**Notes**: Verified dish validation rejecting incorrect food, zero payment, and bowl discard capability.

### TC08 — Multiple Customers (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 4.5s
- **GIF Evidence**: `artifacts/gameplay-tests/TC08_multiple_customers.gif`

#### Assertions Executed:
- ✅ Both businesses exist
- ✅ Hu Tieu Customers occupy separate tables without overlapping (dist > 3m)
- ✅ Customers have independent orders
- ✅ Motorcycle customers occupy distinct bays without overlapping
- ✅ Both bays properly marked as occupied

**Notes**: Verified multiple concurrent customers across tables and bays with non-overlapping positions.

### TC09 — Navigation & Camera (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 4.0s
- **GIF Evidence**: `artifacts/gameplay-tests/TC09_navigation_camera.gif`

#### Assertions Executed:
- ✅ WorkplaceGuidance system exists
- ✅ HUD navigation card is visible on screen
- ✅ Screen-edge pointer is visible
- ✅ Navigation objective points to motorcycle
- ✅ Target is initially at distance (> 3m)
- ✅ Distance decreased as player approached target
- ✅ Navigation marks 'arrived' when reaching target
- ✅ Edge pointer hides automatically upon arrival
- ✅ HUD label displays arrival confirmation
- ✅ Ground beacon instance exists
- ✅ Camera exists and is orthogonal
- ✅ Camera projection is orthogonal (no perspective distortion)

**Notes**: Verified camera-relative direction arrows, distance countdown, arrival hiding, and orthogonal camera.

### TC10 — Return Home & Persistence (🟢 PASS)

- **Status**: 🟢 PASS
- **Duration**: 7.9s
- **GIF Evidence**: `artifacts/gameplay-tests/TC10_return_home_persistence.gif`

#### Assertions Executed:
- ✅ Player entered house interior
- ✅ Bed interactable exists
- ✅ Player is resting in bed
- ✅ Progression saved to disk automatically upon resting
- ✅ Player woke up refreshed
- ✅ Persisted balance matches after reload (255000 đ)
- ✅ Persisted earnings match after reload (75000 đ)
- ✅ Transaction history and idempotency cache preserved

**Notes**: Verified returning home, bed rest interaction, automatic state save, and exact reload of wallet/earnings.

