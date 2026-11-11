# Automated Visual Gameplay Test Report

**Project**: Couple Chaos (Godot 4.7.2 3D Low-Poly Life Simulation)
**Date**: 2026-11-12T00:07:41
**Execution Summary**: 13 Scenarios Executed — **13 PASS**, **0 FAIL**, **0 BLOCKED**

## Executive Summary Table

| Test ID | Scenario Description | Status | Duration | GIF Evidence |
|---|---|---|---|---|
| `TC01` | Character Selection | 🟢 PASS | 2.7s | [TC01_character_selection.gif](./TC01_character_selection.gif) |
| `TC02` | House Entry & Exit | 🟢 PASS | 8.8s | [TC02_house_exit.gif](./TC02_house_exit.gif) |
| `TC03` | Motorcycle Riding & Parking | 🟢 PASS | 20.3s | [TC03_motorcycle_commute.gif](./TC03_motorcycle_commute.gif) |
| `TC04` | Motorcycle Customer Arrival & Repair | 🟢 PASS | 11.2s | [TC04_motorcycle_repair.gif](./TC04_motorcycle_repair.gif) |
| `TC05` | Hu Tieu Preparation & Opening | 🟢 PASS | 5.9s | [TC05_hutieu_preparation.gif](./TC05_hutieu_preparation.gif) |
| `TC06` | Hu Tieu Customer Service | 🟢 PASS | 11.6s | [TC06_hutieu_customer_service.gif](./TC06_hutieu_customer_service.gif) |
| `TC07` | Incorrect Order Rejection & Discard | 🟢 PASS | 2.5s | [TC07_incorrect_order.gif](./TC07_incorrect_order.gif) |
| `TC08` | Multiple Concurrent Customers | 🟢 PASS | 2.4s | [TC08_multiple_customers.gif](./TC08_multiple_customers.gif) |
| `TC09` | Navigation & Camera Tracking | 🟢 PASS | 2.1s | [TC09_navigation_camera.gif](./TC09_navigation_camera.gif) |
| `TC10` | Return Home & Persistence | 🟢 PASS | 4.8s | [TC10_return_home_persistence.gif](./TC10_return_home_persistence.gif) |
| `TC11` | Customer Timeout & Departure | 🟢 PASS | 6.2s | [TC11_customer_timeout.gif](./TC11_customer_timeout.gif) |
| `TC12` | House & Business Upgrades Progression | 🟢 PASS | 4.5s | [TC12_house_business_upgrades.gif](./TC12_house_business_upgrades.gif) |
| `TC13` | Visual Regression & System Integrity | 🟢 PASS | 1.8s | [TC13_visual_regression.gif](./TC13_visual_regression.gif) |

---

## Detailed Test Case Results

### TC01 — Character Selection (🟢 PASS)

- **Description**: Validates seamless switching between Boy and Girl characters, verifying 3D model instantiation, animation controller attachment, and bedroom spawn location.
- **Status**: 🟢 PASS
- **Duration**: 2.7s
- **GIF Evidence**: `artifacts/gameplay-tests/TC01_character_selection.gif`
- **Expected Result**: Both Boy and Girl visual models swap smoothly, retain physics/movement collision, and remain properly positioned within the house interior.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ Character is Boy
- ✅ Boy 3D visual model is active
- ✅ Boy starts inside shared house interior (Z > 83)
- ✅ Character switched to Girl
- ✅ Girl 3D visual model is active
- ✅ Girl remains inside shared house interior

#### Reproduction Steps:
1. Spawn player at home bedroom coordinates (-45, 0, 89).
2. Select Boy character: assert selected_character == 'boy' and model is active.
3. Simulate walking in bedroom circle to verify locomotion animations.
4. Switch character to Girl: assert selected_character == 'girl' and female visual model is active.
5. Walk in bedroom circle with Girl character.
6. Switch back to Boy character for subsequent scenarios.

#### Related Source Files:
- `res://scripts/player.gd`
- `res://scripts/player_config.gd`
- `res://scripts/animation_controller.gd`

**Notes**: Verified Boy and Girl selection, visual meshes, and initial spawn inside house without collision degradation.

---

### TC02 — House Entry & Exit (🟢 PASS)

- **Description**: Tests complete house entry and exit cycle: validates closed door collision blocking passage, [E] interaction to open, smooth walking through doorway into yard, turning around to re-enter, closing door, and camera tracking.
- **Status**: 🟢 PASS
- **Duration**: 8.8s
- **GIF Evidence**: `artifacts/gameplay-tests/TC02_house_exit.gif`
- **Expected Result**: Door collision prevents walk-through when closed, allows passage when open via [E], and camera tracks smoothly both exiting and entering.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ House front door exists
- ✅ Door starts in closed state
- ✅ Door collision active in closed state
- ✅ Solid door collision prevents walking through closed doorway
- ✅ Door opened after E interaction
- ✅ Doorway collision disabled allowing pass-through
- ✅ Player walked out of house into front yard (Z <= 80)
- ✅ Player is within front yard bounds (Z >= 63)
- ✅ Camera tracks player smoothly
- ✅ Camera centered horizontally with player
- ✅ Player walked back into house interior through open door
- ✅ Door closed after second E interaction
- ✅ Door collision re-enabled upon closing

#### Reproduction Steps:
1. Spawn player in bedroom at (-45, 0, 89).
2. Verify house front door starts closed with solid collision enabled.
3. Attempt to walk through closed door: assert player is blocked at doorway.
4. Press [E] on front door to open: assert door.toggle == true and collision layer cleared.
5. Walk through doorway into front yard: assert Z <= 80.
6. Verify camera horizontally tracks player position.
7. Turn around and walk through open doorway back into bedroom: assert Z > 84.
8. Press [E] to close door: assert collision is restored and blocks outward passage.
9. Re-open door and step into front yard for next scenario.

#### Related Source Files:
- `res://scripts/room.gd`
- `res://scripts/interactable.gd`
- `res://scripts/player.gd`

**Notes**: Verified complete entry and exit cycle, physical door collision blocking, smooth camera tracking, and bidirectional navigation.

---

### TC03 — Motorcycle Riding & Parking (🟢 PASS)

- **Description**: Tests walking to motorcycle in front yard, mounting vehicle, folding kickstand, driving along road waypoints without building clipping, parking smoothly into garage workplace bay, and dismounting.
- **Status**: 🟢 PASS
- **Duration**: 20.3s
- **GIF Evidence**: `artifacts/gameplay-tests/TC03_motorcycle_commute.gif`
- **Expected Result**: Player mounts motorcycle, kickstand retracts, drives road grid at cruise speed (11 m/s), parks squarely in designated workplace bay with kickstand down.
- **Actual Result**: All assertions passed successfully.

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

#### Reproduction Steps:
1. Spawn player in front yard at (-45, 0, 76).
2. Walk to Boy's motorcycle at parking bay (-47, 0, 72).
3. Mount motorcycle: assert kickstand retracted and riding_scooter meta set.
4. Drive along road waypoints (yard gate -> street -> West Avenue -> Boulevard -> garage driveway).
5. Enter garage workplace parking bay and dismount.
6. Verify motorcycle parked at work_parking_pos and kickstand deployed.

#### Related Source Files:
- `res://scripts/neighborhood/player_scooter.gd`
- `res://scripts/neighborhood/world.gd`

**Notes**: Verified walking to bike, mounting, driving entire road path to garage, parking, and dismounting cleanly.

---

### TC04 — Motorcycle Customer Arrival & Repair (🟢 PASS)

- **Description**: Tests realistic customer arrival along the road path into Bay 0, driver dismounting and ordering repair, player walking to workbench to pick up patch kit, interacting at Bay 0 to apply patch and pump air, payment processing, and customer riding away.
- **Status**: 🟢 PASS
- **Duration**: 11.2s
- **GIF Evidence**: `artifacts/gameplay-tests/TC04_motorcycle_repair.gif`
- **Expected Result**: Customer drives into bay naturally, order is accepted, player executes sequential repair steps via physical station interactions, wallet earns 35,000đ, and customer rides away safely.
- **Actual Result**: All assertions passed successfully.

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
- ✅ Customer departed on motorcycle along road

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

### TC05 — Hu Tieu Preparation & Opening (🟢 PASS)

- **Description**: Tests Hu Tieu stall starting in CLOSED state, player interacting with prep station, natural real-time cooking and preparation progress (0% -> 100%), transition to READY state, and player opening the shop to receive customers.
- **Status**: 🟢 PASS
- **Duration**: 5.9s
- **GIF Evidence**: `artifacts/gameplay-tests/TC05_hutieu_preparation.gif`
- **Expected Result**: Shop starts closed, prep station triggers gradual real-time progress accumulation to 100%, and second interaction opens stall with updated overhead billboard.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ HuTieuBusiness exists
- ✅ Shop starts in CLOSED state
- ✅ Shop is closed, customer arrivals blocked
- ✅ Shop entered PREPARING phase
- ✅ Preparation progress reached 100%
- ✅ Shop naturally entered READY state
- ✅ Prompt offers to open shop
- ✅ Shop officially entered OPEN state
- ✅ is_open flag is true
- ✅ Overhead billboard reflects shop open status

#### Reproduction Steps:
1. Position player at Hu Tieu stall (-45, 0, -14).
2. Reset shop to CLOSED state: assert customers blocked and billboard indicates closed.
3. Walk to PrepStation at cooking counter and press [E] to start preparation.
4. Shop enters PREPARING phase: wait and capture frames as progress naturally accumulates to 100%.
5. Assert stall transitions to READY state once progress hits 100%.
6. Press [E] at PrepStation to officially open shop: assert prep_state == OPEN and is_open == true.
7. Verify overhead billboard reflects active open status.

#### Related Source Files:
- `res://scripts/neighborhood/business/hutieu_business.gd`
- `res://scripts/neighborhood/business/business_shop.gd`

**Notes**: Verified CLOSED state, real-time natural preparation accumulation (0% -> 100%), READY transition, and E open interaction.

---

### TC06 — Hu Tieu Customer Service (🟢 PASS)

- **Description**: Tests complete dining service cycle: customer arriving and seating at Table 0, placing order, player sequentially cooking dish (blanching noodles naturally, ladling broth, garnishing toppings), serving food to table, payment processing, eating, and customer departure.
- **Status**: 🟢 PASS
- **Duration**: 11.6s
- **GIF Evidence**: `artifacts/gameplay-tests/TC06_hutieu_customer_service.gif`
- **Expected Result**: Customer seats naturally, player cooks complete dish through physical kitchen stations, customer receives food, wallet earns 45,000đ, and customer departs cleanly.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ HuTieuBusiness exists
- ✅ Customer is seated on chair
- ✅ Customer placed order for 'Hủ tiếu Nam Vang'
- ✅ Bowl in blanching strainer
- ✅ Noodles cooked to perfection naturally
- ✅ Hot bone broth ladled into bowl
- ✅ Bowl fully prepared
- ✅ Prepared dish is 'Hủ tiếu Nam Vang'
- ✅ Order marked PAID
- ✅ Shared wallet credited +45,000đ
- ✅ Customer is eating served food
- ✅ Hot noodle bowl visible on dining table
- ✅ Customer finished meal and departed along sidewalk

#### Reproduction Steps:
1. Position player at Hu Tieu kitchen (-50, 0, -17).
2. Customer approaches from sidewalk and sits at Table 0: assert order placed for Hủ tiếu Nam Vang.
3. Walk to BlanchingStation and press [E]: wait for blanch timer (1.6s) to cook noodles naturally.
4. Walk to BrothStation and press [E] to ladle broth.
5. Walk to ToppingsStation, select Nam Vang recipe, and press [E] to assemble dish.
6. Walk to Table 0 and press [E] to serve food: assert order marked PAID and +45,000đ credited.
7. Customer enters EATING state with visible noodle bowl.
8. Customer finishes meal and departs along sidewalk waypoints.

#### Related Source Files:
- `res://scripts/neighborhood/business/hutieu_business.gd`
- `res://scripts/neighborhood/business/hutieu_customer.gd`
- `res://scripts/neighborhood/business/business_order.gd`

**Notes**: Verified customer seating, realistic sequential cooking (natural blanch, broth, toppings), table serving, payment, and departure.

---

### TC07 — Incorrect Order Rejection & Discard (🟢 PASS)

- **Description**: Tests order validation rejecting mismatched food orders: customer orders Nam Vang noodles, player prepares Pork Rib noodles instead, attempts to serve at dining table (rejected, 0đ reward, bowl preserved), and player discards wrong bowl at blanching pot.
- **Status**: 🟢 PASS
- **Duration**: 2.5s
- **GIF Evidence**: `artifacts/gameplay-tests/TC07_incorrect_order.gif`
- **Expected Result**: Serving wrong dish is rejected with zero financial reward, customer order remains pending, and wrong bowl can be discarded cleanly to remake.
- **Actual Result**: All assertions passed successfully.

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

#### Reproduction Steps:
1. Position player at Hu Tieu stall (-50, 0, -17).
2. Customer at Table 0 orders 'Hủ tiếu Nam Vang'.
3. Player intentionally prepares 'Hủ tiếu sườn heo' at cooking counter.
4. Walk to Table 0 and press [E] to attempt serving incorrect dish.
5. Assert order is REJECTED, remains PENDING, and wallet receives 0đ.
6. Assert kitchen bowl is preserved and not consumed.
7. Walk to BlanchingStation and press [E] to discard incorrect bowl.
8. Assert bowl state is reset to EMPTY.

#### Related Source Files:
- `res://scripts/neighborhood/business/hutieu_business.gd`
- `res://scripts/neighborhood/business/business_order.gd`

**Notes**: Verified dish validation rejecting incorrect food, zero payment, and bowl discard capability.

---

### TC08 — Multiple Concurrent Customers (🟢 PASS)

- **Description**: Tests multiple concurrent customers dining at Hu Tieu tables and repairing motorcycles at Garage service bays simultaneously, validating independent order tracking, non-overlapping 3D positions, and capacity reservation bounds.
- **Status**: 🟢 PASS
- **Duration**: 2.4s
- **GIF Evidence**: `artifacts/gameplay-tests/TC08_multiple_customers.gif`
- **Expected Result**: Both tables and both repair bays handle independent customers simultaneously without spatial collisions, state corruption, or order interference.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ Both businesses exist in world
- ✅ Hu Tieu Customers occupy separate tables without overlapping (dist > 3m)
- ✅ Customers have independent food orders
- ✅ Both Hu Tieu tables marked occupied
- ✅ Motorcycle customers occupy distinct bays without overlapping (dist > 2.5m)
- ✅ Both garage bays properly marked as occupied

#### Reproduction Steps:
1. Position camera and player at neighborhood junction (-50, 0, -18).
2. Spawn two customers at Hu Tieu dining tables (Table 0 and Table 1).
3. Assert customers occupy distinct physical positions (> 3.0m apart) without overlapping.
4. Assert distinct food orders registered for Table 0 and Table 1.
5. Spawn two motorcycle customers at Garage (Bay 0 and Bay 1).
6. Assert motorcycles occupy distinct service bays (> 2.5m apart) and bay_reserved tracks both.
7. Simulate player walking between stalls to visually showcase concurrent customer operations.

#### Related Source Files:
- `res://scripts/neighborhood/business/garage_business.gd`
- `res://scripts/neighborhood/business/hutieu_business.gd`
- `res://scripts/neighborhood/business/business_shop.gd`

**Notes**: Verified multiple concurrent customers across tables and bays with non-overlapping positions and independent order queues.

---

### TC09 — Navigation & Camera Tracking (🟢 PASS)

- **Description**: Tests the 3D workplace guidance navigation system, including screen-edge directional arrows, HUD objective cards, distance countdown, 3D pulsing ground beacon, arrival state detection, and orthogonal camera tracking without perspective distortion.
- **Status**: 🟢 PASS
- **Duration**: 2.1s
- **GIF Evidence**: `artifacts/gameplay-tests/TC09_navigation_camera.gif`
- **Expected Result**: Navigation accurately points toward off-screen objectives, updates distance smoothly during player locomotion, hides edge pointer upon arrival (<2.5m), and orthogonal camera centers on player.
- **Actual Result**: All assertions passed successfully.

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

#### Reproduction Steps:
1. Position player in front yard (-45, 0, 76).
2. Guidance system resolves destination: points toward Boy's motorcycle.
3. Assert HUD card is visible and edge pointer points toward motorcycle.
4. Walk player toward motorcycle: assert distance decreases continuously.
5. Walk within 2.5m of motorcycle: assert edge pointer hides and arrival text confirmed.
6. Verify 3D ground beacon is present at destination.
7. Verify main camera is in orthogonal projection mode.

#### Related Source Files:
- `res://scripts/workplace_guidance.gd`
- `res://scripts/shared_camera.gd`

**Notes**: Verified camera-relative direction arrows, real-time distance countdown, arrival hiding, ground beacon, and orthogonal camera.

---

### TC10 — Return Home & Persistence (🟢 PASS)

- **Description**: Tests end-of-day return home flow: revenue accumulation in household wallet, walking from front yard into bedroom, bed rest interaction triggering automatic state saving to disk, waking up, and reloading saved state to verify balance, earnings, and deduplication cache.
- **Status**: 🟢 PASS
- **Duration**: 4.8s
- **GIF Evidence**: `artifacts/gameplay-tests/TC10_return_home_persistence.gif`
- **Expected Result**: Bed rest triggers automatic file save, reloaded wallet balance and lifetime earnings match exactly, and processed transaction IDs persist without data loss.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ Player entered house interior
- ✅ Bed interactable exists
- ✅ Player is resting in bed
- ✅ Progression saved to disk automatically upon resting
- ✅ Player woke up refreshed
- ✅ Persisted balance matches after reload (255000 đ)
- ✅ Persisted earnings match after reload (75000 đ)
- ✅ Transaction history and idempotency cache preserved

#### Reproduction Steps:
1. Position player in yard at (-45, 0, 72).
2. Simulate daily business revenue deposit (+75,000đ) into shared household wallet.
3. Walk player through front yard into house interior (Z > 83).
4. Interact with Bed: assert player resting pose and automatic save to disk.
5. Wake up from bed via second interaction.
6. Reload save file into fresh wallet and inventory instances.
7. Assert reloaded balance, total earned, and transaction cache match perfectly.

#### Related Source Files:
- `res://scripts/economy/economy_save_system.gd`
- `res://scripts/economy/household_wallet.gd`
- `res://scripts/room.gd`
- `res://scripts/interactable.gd`

**Notes**: Verified returning home, bed rest interaction, automatic state save, and exact reload of wallet/earnings.

---

### TC11 — Customer Timeout & Departure (🟢 PASS)

- **Description**: Tests customer patience expiration: a customer is seated and places an order, the player does not serve the order in time, patience bar drains to 0%, the customer becomes frustrated, the order is marked FAILED with zero payment, and the customer departs cleanly, freeing the dining table.
- **Status**: 🟢 PASS
- **Duration**: 6.2s
- **GIF Evidence**: `artifacts/gameplay-tests/TC11_customer_timeout.gif`
- **Expected Result**: Order fails cleanly upon patience expiration, customer displays angry feedback bubble, departs along sidewalk waypoints, table is freed for next customer, and zero money is paid.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ HuTieuBusiness exists
- ✅ Customer seated and placed order
- ✅ Order is initially PENDING
- ✅ Order is in active queue
- ✅ Order transitioned to FAILED after patience expired
- ✅ Failed order removed from active orders queue
- ✅ Customers lost counter incremented
- ✅ Zero payment awarded to wallet for unserved order
- ✅ Customer stood up and is leaving stall
- ✅ Customer displayed angry frustration feedback

#### Reproduction Steps:
1. Position player at Hu Tieu cooking counter (-50, 0, -17).
2. Customer arrives and sits at Table 0 with a 3.0s patience order.
3. Player remains idle at cooking counter, observing the customer waiting.
4. Record frames as patience bar counts down from green to yellow to red.
5. Patience hits 0%: assert order status transitions to FAILED.
6. Assert customers_lost counter increments and order removed from active list.
7. Assert customer shows angry speech bubble ('Chờ lâu quá...') and stands up.
8. Customer departs along sidewalk waypoints and frees Table 0.
9. Assert household wallet receives 0đ.

#### Related Source Files:
- `res://scripts/neighborhood/business/business_shop.gd`
- `res://scripts/neighborhood/business/hutieu_business.gd`
- `res://scripts/neighborhood/business/hutieu_customer.gd`
- `res://scripts/neighborhood/business/business_order.gd`

**Notes**: Verified realistic customer patience countdown, FAILED order transition, loss counter increment, angry speech feedback, and clean table departure without payout.

---

### TC12 — House & Business Upgrades Progression (🟢 PASS)

- **Description**: Tests progression mechanics for household and business upgrades: player walks to House Upgrade Board in bedroom, reviews Level 2 requirements, initiates two-step confirmation, executes house upgrade (wallet deducted 75,000đ, tiled kitchen spawned, room bounds expanded), verifies business equipment upgrade at Garage, and confirms save/load persistence.
- **Status**: 🟢 PASS
- **Duration**: 4.5s
- **GIF Evidence**: `artifacts/gameplay-tests/TC12_house_business_upgrades.gif`
- **Expected Result**: House upgrade board requires two-step confirmation, deducts correct funds from wallet, triggers real-time architectural rebuild with kitchen area, and unlocks business upgrades.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ HouseProgressionManager and UpgradeBoard exist
- ✅ House starts at Level 1
- ✅ Upgrade board is interactive
- ✅ Prompt shows Level 2 upgrade fee (75,000 đ)
- ✅ Board entered confirmation mode for Level 2
- ✅ Prompt requests confirmation ('Nhấn E lần nữa để XÁC NHẬN')
- ✅ House successfully upgraded to Level 2 (Căn hộ ấm cúng)
- ✅ Wallet deducted 75,000đ (new balance: 75000 đ)
- ✅ Tiled kitchen area unlocked in Level 2
- ✅ Room bounds physically expanded to accommodate kitchen
- ✅ Garage business exists
- ✅ Second bay starts locked
- ✅ Second service bay unlocked
- ✅ Second bay visual platform spawned in 3D world
- ✅ Progression saved to disk
- ✅ Reloaded save preserves house level 2

#### Reproduction Steps:
1. Position player in bedroom (-45, 0, 89) and deposit 150,000đ into shared wallet.
2. Verify house starts at Level 1 with compact starter bounds.
3. Walk to HouseUpgradeBoard on wall (-46.8, 0, 83.6).
4. Press [E] once: assert board enters confirmation state ('Nhấn E lần nữa để XÁC NHẬN').
5. Press [E] second time: execute upgrade to Level 2 (Căn hộ ấm cúng).
6. Assert house level is 2, wallet deducted 75,000đ, and tiled kitchen spawned.
7. Assert room bounds expand in Z and X dimensions.
8. Unlock Garage Second Bay upgrade and verify visual platform instance created.
9. Save state and assert reload preserves Level 2 and owned upgrades.

#### Related Source Files:
- `res://scripts/house/house_progression_manager.gd`
- `res://scripts/house/house_upgrade_board.gd`
- `res://scripts/room.gd`
- `res://scripts/neighborhood/business/garage_business.gd`
- `res://scripts/economy/economy_manager.gd`

**Notes**: Verified two-step confirmation, wallet deduction, house rebuild with kitchen area, garage second bay upgrade, and persistence.

---

### TC13 — Visual Regression & System Integrity (🟢 PASS)

- **Description**: Executes critical regression checks: camera occlusion cutaway verification for trees/structures, UI vertical offset separation (speech labels vs bay status labels), duplicate reward rejection, corrupted save file recovery, and physical boundary collision enforcement.
- **Status**: 🟢 PASS
- **Duration**: 1.8s
- **GIF Evidence**: `artifacts/gameplay-tests/TC13_visual_regression.gif`
- **Expected Result**: Camera views remain unobstructed by registered cutaways, UI labels maintain distinct vertical offsets, duplicate rewards are blocked, corrupted saves recover safely, and wall collisions block passage.
- **Actual Result**: All assertions passed successfully.

#### Assertions Executed:
- ✅ Environment trees present with foliage models
- ✅ Camera instance valid and active
- ✅ Garage Bay 0 status label exists
- ✅ UI vertical clearance between speech (2.9m) and bay status (2.35m) is 0.55m (>= 0.5m, no overlap)
- ✅ First claim of completed order succeeded (+20,000đ)
- ✅ Second claim of same order was REJECTED by duplicate protection
- ✅ Household wallet balance unchanged on duplicate claim attempt
- ✅ First deposit with transaction ID succeeded
- ✅ Duplicate deposit with same transaction ID blocked by idempotency cache
- ✅ Corrupted save file safely recovered to default balance without crashing engine
- ✅ Solid room wall collision prevents player from escaping house boundaries (Z: 92.2 <= 93.5)

#### Reproduction Steps:
1. Position player in courtyard under tree canopy.
2. Verify tree meshes registered in cutaway_meshes for camera occlusion.
3. Verify vertical clearance between speech bubble (Y=2.9) and bay status label (Y=2.35) >= 0.5m.
4. Attempt to claim completed order twice: assert duplicate payout is rejected.
5. Attempt duplicate transaction ID in HouseholdWallet.deposit(): assert blocked.
6. Write corrupted malformed string to save path and load: assert safe default recovery without engine crash.
7. Simulate walk into solid exterior bedroom wall: assert CharacterBody3D collision stops player.

#### Related Source Files:
- `res://scripts/shared_camera.gd`
- `res://scripts/neighborhood/business/business_shop.gd`
- `res://scripts/economy/economy_save_system.gd`
- `res://scripts/economy/household_wallet.gd`
- `res://scripts/room.gd`

**Notes**: Verified tree occlusion registration, UI label vertical clearance, duplicate reward rejection, corrupted save file recovery, and physical boundary collision enforcement.

---

