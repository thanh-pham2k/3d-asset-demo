# Neighborhood

Choose **KHÁM PHÁ KHU PHỐ** on the main menu, or run `/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/neighborhood.tscn` from the project directory. The indoor game remains the default. WASD moves, left Shift runs, Space dashes, and E/F retain their existing interaction bindings. Tab switches between the follow camera and map; Esc returns to the room menu; F11 toggles fullscreen. The project still starts windowed and is single-player.

The flat terrain is 250 × 250 Godot metres with four collision boundaries. A main east–west boulevard connects three north–south streets, a northern local street, and a shorter southern residential street. Sidewalk segments leave gaps at intersections, with 30 instances of the reusable visual-only crossing module spanning the boulevard, side streets and local roads. The named district nodes in `scripts/neighborhood/world.gd` group the starter home, garage, noodle stall, market, food street, furniture store, park, school, residential alley and expansion lot. Entrances face their nearby roads; small visual surfaces sit on the common collidable ground, so decorative curb heights cannot trap the character. Building walls, school gate columns, market counters, tree trunks, planters, low yard rails and the pond use separate static collisions. The starter yard has front and side openings; clotheslines are decorative and have no collision. The residential area mixes one-storey houses and two-storey townhouses. The noodle shop and food street have modular paved gathering surfaces. The grocery has separate stocked shelves and a counter with a clear central aisle. The furniture store displays independently instanced sofa, bed, table, television and refrigerator modules; the starter house has a sofa and a tiled kitchen area. These pieces are currently non-interactive scenery. `collision_enabled` on each module can disable its generated collision before the scene enters the tree. Building shells also cut away when the follow camera’s orthographic sightline crosses them; collision remains active. Side walls stay visible where they do not face the camera, and map view restores complete buildings. The sightline uses a conservative bounding volume and may hide more than the exact obstruction.

Fifty-two reusable scene modules live in `scenes/neighborhood/`. Their type, tint, transform and generated geometry are independent; the world layout is currently authored in `scripts/neighborhood/world.gd`, with local ground-level pivots and separate collision shapes in `scripts/neighborhood/module.gd`. The available GLBs are characters and small props, not neighborhood buildings, so the map uses primitive placeholders. Script-free, editable Godot scene copies live in `assets/neighborhood/editable/`: open one in the editor to select its individual visual and collision nodes. They are independent snapshots without the procedural scenes’ cutaway behavior or per-instance tint. Generate missing copies with `godot --headless --path . --script res://tools/bake_neighborhood_modules.gd`; the tool skips existing files to preserve edits. Passing `-- --overwrite` replaces those copies, so save custom work elsewhere first. An editable layout snapshot is available at `assets/neighborhood/editable_layout.tscn`. It retains separate district and module nodes, their visual and collision children, route curves and spawn markers, but excludes the player, camera, lighting, HUD and cutaway scripts. It is a static authoring reference: edits to it do not change the playable world. Generate it with `godot --headless --path . --script res://tools/bake_neighborhood_layout.gd`; existing output is skipped unless `-- --overwrite` is passed. Save custom changes elsewhere before overwriting. The running world continues to use the procedural originals. Visual-only GLBs for each module live in `assets/neighborhood/glb/`; each has a local ground-level origin and separate render meshes. Rebuild them with `godot --headless --path . --script res://tools/export_neighborhood_modules.gd`. Collisions, player cutaway behavior and per-instance tint remain in the Godot scene modules rather than the GLBs. The scooter GLB is a standalone visual, with no vehicle gameplay. To replace a module, preserve its local origin, walkable entrance and separate collision, and rerun the route test. World placement batches a module’s visual meshes by material and cutaway visibility at runtime; it does not combine different modules or change their collisions. Standalone modules and the GLB exporter retain the original visual parts. The player uses the unchanged `PlayerConfig` and visual/animation adapter. `NPCWalkingRoutes` contains 11 named Path3D guides on sidewalk, alley and park paths; intersecting guides share explicit curve points. `NPCSpawnPoints` contains ten Marker3D nodes.

## Living NPC Simulation

The neighborhood features a living population of 12 distinct data-driven Vietnamese NPCs managed by `NPCManager` (`scripts/neighborhood/npc_manager.gd`) and an in-game day/night clock `NeighborhoodTimeManager` (`scripts/neighborhood/time_manager.gd`):
- **Data & Routine Schedules** (`scripts/neighborhood/npc_data.gd`): Each resident has a unique Vietnamese name, role, low-poly stylized appearance (with accessories like conical hats *nón lá*, chef aprons, mechanic caps, glasses, and student backpacks), and a multi-entry daily schedule covering morning commute/work, noon market/food visits, and evening leisure/return home.
- **Pathfinding & Avoidance**: Each NPC uses `NavigationAgent3D` on a pre-baked 1,793-polygon navigation mesh (`assets/neighborhood/neighborhood_navmesh.tres`) located in `NavigationRegion3D`. Avoidance and soft repulsion separation prevent clustering or entrance blocking.
- **State Machine**: NPCs smoothly transition between `IDLE`, `WALKING`, `WAITING`, and `INTERACTING`.
- **Player Dialogue & Interaction**: Approaching an NPC displays an interaction prompt (`E — Trò chuyện với [Tên]`). Pressing `E` pauses the NPC, turns them to face the player, and opens an overhead speech bubble with time-sensitive Vietnamese dialogue. Pressing `E` advances lines, and walking away (> 2.8m) safely closes the interaction.
- **Stuck & Schedule Recovery**: NPCs track progress while walking. Blocked routes trigger repathing within 2 seconds and failsafe position/schedule recovery within 5 seconds. Off-schedule time jumps catch up smoothly to the current scheduled location.

## Realistic Customer Arrival, Shop Preparation & Navigation

1. **Motorcycle Customer Arrival & Departure Flow** (`scripts/neighborhood/business/motorcycle_customer.gd`):
   - **Realistic Road Approach**: NPC customers mount a 3D scooter with rolling wheels and exhaust smoke, riding from the roadway along waypoints into the garage.
   - **Smooth Deceleration & Bay Parking**: As the customer approaches their assigned service bay, they decelerate smoothly (from 6.0 m/s down to 1.2 m/s), park neatly in the bay, step off the scooter, and stand beside it with dialogue waiting for service.
   - **Service & Safe Departure**: Once the player repairs the scooter, the customer thanks the player, remounts the scooter, starts the engine, and drives along an exit path back to the outer roadway before despawning.
   - **Anti-Overlap Bay Reservation**: If all repair bays are reserved or occupied, incoming spawns are safely throttled or turned away to prevent clutter and clipping.

2. **Hu Tieu Shop Preparation Phase & Dining Flow** (`scripts/neighborhood/business/hutieu_business.gd`, `scripts/neighborhood/business/hutieu_customer.gd`):
   - **Business Preparation State Machine**: The shop implements an explicit lifecycle: `CLOSED` → `PREPARING` → `READY` → `OPEN`.
   - **Preparation Station**: Players approach the counter station and see `E — Chuẩn bị mở quán`. Pressing `E` initiates gradual ingredient prep and broth heating (0% to 100% progress bar) with floating 3D status banners.
   - **Opening Confirmation**: At 100%, the prompt transitions to `E — Sẵn sàng bán`. Players press `E` to officially open the shop; customers only arrive after the shop is open.
   - **Dining Experience Flow**: Customers walk in from the sidewalk, find an available dining table, take a seat on the wooden chair facing the table, and only place their order once comfortably seated. When the player serves the hot noodle bowl, the customer slurps their noodles (with eating animations), pays their bill, stands up, and walks out back to the street.

3. **Camera-Relative Screen-Space Directional Arrow & Guidance** (`scripts/workplace_guidance.gd`):
   - **True Camera-Relative Angle**: Projects horizontal ground delta vectors onto the camera's ground right (`camera.global_basis.x`) and forward (`-camera.global_basis.z`) axes to compute true screen-space directions (`Vector2(right_dot, -fwd_dot)`), smoothly updated during camera rotation.
   - **Screen-Edge Clamping**: When the objective is outside the player's viewport, a prominent directional pointer clamps to the screen border with a rotating compass badge and remaining distance in meters.
   - **Dynamic Context-Sensitive Objectives**:
     - *Boy*: Starter Home Exit → Motorcycle Repair Shop → Active Service Bay needing repair.
     - *Girl*: Starter Home Exit → Hu Tieu Shop → Prep Station (`Chuẩn bị mở quán`) → Kitchen Counter (`Trụng bánh` / `Chan nước` / `Topping`) → Seated Customer Table.
   - **3D Ground Beacon**: A gentle pulsing ground ring highlights the exact active station or table in the 3D world; hides automatically upon arrival (< 2.5m).

4. **Foliage Camera Occlusion Cutaway** (`scripts/neighborhood/module.gd`):
   - Trees and banana plants register their canopy meshes in `cutaway_meshes` with dedicated visual bounding boxes, automatically cutting away transparency when occluding the player character.

## Playable Businesses

Two interactive businesses are fully playable using the shared `BusinessShop` / `BusinessOrder` architecture:
1. **Boy's Motorcycle Repair Shop** (`scripts/neighborhood/business/garage_business.gd`):
   - **Customer Service Bays**: Arriving customers park their scooters at bays with floating status and patience meters.
   - **3 Service Types**:
     - *Bơm lốp xe (Inflate)*: Connect air pump nozzle at wheel and inflate to pressure (+20,000đ).
     - *Vá săm xe (Patch)*: Get patch kit from workbench, apply rubber patch, and inflate (+35,000đ).
     - *Thay lốp mới (Replace)*: Remove worn tire, fetch fresh tire from tire rack, mount onto scooter, and inflate (+50,000đ).
   - **Feedback**: Interactive mini-games, sequence validation, customer patience countdown, and duplicate reward protection.
2. **Girl's Hu Tieu Shop** (`scripts/neighborhood/business/hutieu_business.gd`):
   - **Customer Dining Tables**: Customers sit at dining tables and order dishes (*Hủ tiếu Nam Vang*, *Hủ tiếu sườn non*, *Hủ tiếu tôm thịt*).
   - **Cooking Stations**:
     - *Nồi trụng*: Blanch fresh noodles in boiling water (cooking timer with steam).
     - *Nồi nước lèo*: Ladle piping-hot bone broth into bowl.
     - *Quầy topping*: Garnish with shrimp, pork, cracklings (*tóp mỡ giòn*), and scallions.
   - **Serving & Satisfaction**: Carry prepared bowl to the table, press `E` to serve (+40,000đ - 45,000đ). Customers eat and depart. Incomplete or mismatched dishes trigger clear advisory feedback.
3. **Shared Operating Hours**: Both shops open from 06:00 to 21:00, coordinated with `NeighborhoodTimeManager`.

## Persistent Economy System

The couple shares a joint household wallet and inventory system (`scripts/economy/`):
- **Shared Household Wallet** (`HouseholdWallet`): Starts with 100,000đ savings. Automatically receives revenue from completed motorcycle repairs (+20,000đ – +50,000đ) and served hu tieu orders (+40,000đ – +45,000đ). Displays real-time formatted Vietnamese currency (`100,000 đ`) on the player HUD.
- **Deduplication & Transaction Logging**: Every earn and spend event records an immutable transaction ledger with timestamp, amount, category, and running balance. Unique transaction IDs prevent duplicate payouts or double withdrawals.
- **5 Spending Categories**:
  1. *Nguyên liệu món ăn (Food Ingredients)*: Fresh shrimp, pork bone, crispy pork rinds, fresh herbs (purchasable at the Wet Market).
  2. *Dụng cụ sửa xe (Repair Tools)*: Patch strips, vulcanizing solution, replacement tires, valve cores (purchasable at the Garage Parts station).
  3. *Nội thất & Gia dụng (Furniture & Appliances)*: Stylized living room sofa, wooden bed, dining table, smart TV, 2-door refrigerator (purchasable at the Furniture Store).
  4. *Nâng cấp tiệm (Business Upgrades)*: 2nd motorcycle service bay, automatic noodle cooker, outdoor terrace seating.
  5. *Nâng cấp nhà (House Upgrades)*: Courtyard flower garden, extended patio, upgraded tile roof.
- **Interactive Shop Kiosks** (`ShopKiosk`): Placed at the Furniture Store, Wet Market, Garage, and Starter House. Players approach and press `E` to browse category catalogs, check wallet balances, and purchase items. Insufficient funds or already-owned unique items are cleanly blocked with feedback.
- **Persistence & Safe Save/Load** (`EconomySaveSystem`): Atomic writes via temporary files protect against corruption. Saves wallet balance, complete transaction history, consumable item counts, owned furniture, and unlocked upgrades to `user://economy_save.json`. Automatically creates backups and recovers safely if a save file is corrupted or missing.

## Home Progression & Furniture Placement

The couple's house (`scripts/room.gd`, `scripts/house/`) features a 3-level progression system and interactive furniture placement:
- **Level 1 — Nhà Cấp 1 (Nhà gỗ mộc mạc)**: Compact modest starter home featuring a traditional sleeping mat (*chiếu ngủ* with bolster pillow), basic kitchen counter with gas stove and pot, minimal cozy sofa, and wooden table with stools.
- **Level 2 — Nhà Cấp 2 (Căn hộ ấm cúng - 75,000 đ)**: Upgraded spacious room with modern tiled kitchen, sink with running faucet, 2-door refrigerator (*kitchenFridge*), double wooden bed (*bedDouble*) with nightstand, wardrobe cabinet, round dining table with cushioned chairs, and living room lounge sofa (*loungeSofa*).
- **Level 3 — Nhà Cấp 3 (Biệt thự sân vườn - 150,000 đ)**: Fully renovated villa with crown molding trims, paintings, an **Additional Sunroom Wing** (panoramic glass windows, reading lounge, open bookshelf, study desk), and a **Courtyard Garden Patio** (terracotta paving, flower beds, potted bonsai/banana trees, decorative wooden garden rail).
- **Furniture Placement & Rearrangement System** (`FurniturePlacementManager`):
  - **In-house Delivery Box** (`HouseDeliveryBox`): Retrieve purchased furniture from the furniture store directly inside the home.
  - **Placement Ghost Preview**: Real-time grid-snapped (0.25m) ghost preview following the player.
  - **Dynamic Collision Validation**: Physics shape sweep tests check for overlaps against walls, boundaries, and other furniture. Highlight turns translucent green when valid and vivid red when blocked.
  - **Controls**: `WASD` moves preview, `R` rotates 90 degrees, `E` confirms placement (spawns solid collider and interactable), `F` or `Esc` cancels back to storage.
  - **Rearranging**: Approach any placed piece of furniture and press `F` to pick it up, move, rotate, and reposition it freely.
- **Interactions**: Full support for sleeping on beds (*Nằm nghỉ*), sitting on sofas and chairs (*Ngồi sofa / Ngồi ghế*), toggling lamps (*Bật/Tắt đèn*), and swinging doors.
- **Persistence**: Saves `house_level`, `unlocked_areas`, and all placed furniture (`id`, `position`, `rotation_y`) to persistent storage and restores seamlessly on restart.

## 2-Player Local Cooperative Mode

*Couple Chaos* features a complete, authoritative 2-Player Local Co-op mode (`scripts/coop/`):
- **Horizontal Split-Screen** (`SplitScreenManager`): Creates dual `SubViewport`s sharing the single authoritative 3D `World3D`. The left viewport tracks Player 1 (Boy) and the right viewport tracks Player 2 (Girl) with smooth independent orthographic camera tracking, a vertical divider border, and corner badges.
- **Independent Controls** (`CoopInputManager`):
  - **Player 1 (Boy)**: Keyboard controls (`WASD` movement, `E` interact/confirm, `F` throw/cancel, `Space` dash, `Shift` run).
  - **Player 2 (Girl)**: Gamepad (Device 0: Left Stick/D-pad, `A` interact/confirm, `X` throw/cancel, `B` dash, `RB` run) with transparent secondary keyboard fallback (`Arrow Keys` movement, `K` / `Enter` interact, `L` throw, `;` dash, `Right Shift` run).
- **Business Cooperation**:
  - Boy operates the Motorcycle Repair Shop; Girl operates the Hu Tieu Noodle Shop.
  - Both players can assist each other: the garage supports independent multi-player tool holding (`player_holding_tools`), and the noodle shop allows one player to blanch noodles while the partner garnishes broth and serves tables.
  - Completed orders deposit directly into the shared household wallet.
- **Cooperative Actions & Synergies**:
  - **Heavy Furniture Carrying** (`CoopFurnitureCarrier`): Heavy furniture items require both players to grip each end to lift and carry together; movement smoothly coordinates between both players.
  - **Heavy Obstacle Moving** (`CoopHeavyObstacle`): Large obstacles (e.g., stalled scooters or alley shipping crates) require dual pushing to clear at synergized 1.6 m/s speed (8× faster than solo).
  - **Flatpack Assembly Bench** (`CoopAssemblyBench`): Assembling flatpack furniture takes 8 seconds solo, but duo assembly delivers a 3.2× teamwork speedup (2.5 seconds).
  - **Cooperative Missions** (`CoopMissionManager`): Shared co-op milestones (e.g. *Chung Tay Khiêng Vác*, *Thợ Lắp Ráp Điêu Luyện*, *Giờ Cao Điểm Đồng Lòng*) reward bonus funds directly to the shared wallet.
- **Dual Mutual Confirmation** (`DualConfirmationManager`): Major purchases and upgrades (≥ 50,000đ) enter a pending approval state requiring partner confirmation (`E` / `A` to accept, `F` / `B` to decline). Minor purchases and single-player mode proceed immediately.
- **Gamepad Hot-Plug & Disconnect Safety**: Disconnecting Player 2's controller displays a warning banner and seamlessly routes Player 2 input to the secondary keyboard layout without stutter, pausing, or crashes; reconnecting controller 0 restores joypad input with confirmation.
- **Activation**: Press `F2` in the neighborhood or click **"👥 CHẾ ĐỘ CO-OP 2 NGƯỜI"** on the main menu to activate co-op mode.

Run the automated checks with Godot 4.7.2:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_navigation.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_routes.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_crossings.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_walkthrough.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_entry.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_entrances.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_glb.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_editable.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_layout.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/neighborhood_batch.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/npc_simulation_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/playable_business_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/economy_system_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/home_progression_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/local_coop_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/customer_arrival_and_prep_test.gd
```

The room smoke test checks that its wall-collision setup starts free of obstacles before moving into the wall. After the pickup/throw checks, it isolates those movable test fixtures and verifies the intended sofa, bed and lamp are the nearest interaction targets before exercising their input paths. The navigation test flood-fills a two-metre grid using a conservative player-sized physics shape and sweeps each traversed edge; it checks representative district targets and connects all 31 building doorways to the sampled reachable area, not every possible position. It also checks a wall, all four map boundaries, spawn clearance, collision-free NPC guide segments, interior/exterior cutaway and collision, rotated side walls, map visibility, input movement and the camera toggle. The routes test verifies that all guides form one network through shared curve points. The walkthrough test plans on the same conservative grid and sends InputMap actions to the actual player controller across all ten districts and five interiors without teleporting; it uses 4× simulation time and a 240 Hz physics tick. It is an automated test, not human keyboard or visual QA. The entrances test sweeps a player-sized shape through each doorway and checks each building’s cutaway cycle. The layout test compares group and module counts, visual transforms and colors, collision counts, paths and markers with the live world. The editable-scene test checks mesh bounds, colors, collision shape types, dimensions and transforms against the procedural sources. The batching test compares visual bounds, collision counts and cutaway presence for every module. The entry test exercises scene transitions programmatically. The GLB test reimports each exported module and compares mesh count and combined bounds with the source; it does not verify appearance or collision in other applications. Rendered screenshots are staged captures, not hands-on gameplay. A short running-window check exercised movement and the map camera through UI-sent keys; a full keyboard walk-through, camera occlusion around every building, and performance on target hardware remain manual checks. The pond uses a simple cylindrical exclusion shape inside its decorative shoreline; it has no swimming or water simulation. Shops, NPCs and business mechanics are placeholders for future work.

## Local rendering sample

`/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/neighborhood_profile.gd` runs a staged, windowed sample (30 warm-up frames and 150 measured frames per view). On this Apple M5 Pro with Godot 4.7.2 Compatibility/OpenGL and the default 1280 × 720 viewport, overview draw calls fell from 4,603 to 2,445 after per-module batching; sampled p95 frame time changed from 24.7 ms to 14.9 ms. These short single runs are diagnostic only, not a performance guarantee or a test of other hardware.
