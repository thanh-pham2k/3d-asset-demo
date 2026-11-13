# Couple Chaos 3D — Bộ prompt triển khai Gameplay & Low-Poly Assets

## TL;DR

Dựa trên kết quả audit repository, tôi đề xuất 12 prompt theo 5 giai đoạn, tập trung biến Couple Chaos từ prototype thành game mô phỏng đời sống có thể chơi lâu dài.

Mục tiêu cuối cùng:

Đi làm → Kiếm tiền → Mua sắm → Trang trí nhà → Nuôi thú cưng → Trồng rau → Nấu ăn → Ngủ → Ngày mới.

Các prompt đều yêu cầu agent đọc source thật, tận dụng hệ thống hiện có, sửa code trực tiếp và không chạy test, Godot hay tạo GIF để tiết kiệm thời gian theo yêu cầu trước đó.

## Kế hoạch triển khai

| Thứ tự | Prompt                     | Hạng mục                                | Ưu tiên |
| ------ | -------------------------- | --------------------------------------- | ------- |
| 01     | Fix Shopping & Economy     | Sửa mua hàng và nâng cấp chưa hoạt động | P0      |
| 02     | Shopping UI                | Giao diện cửa hàng chuyên nghiệp        | P0      |
| 03     | Furniture Interaction      | Nội thất có thể sử dụng                 | P0      |
| 04     | Pet Assets                 | Tạo asset mèo cam và phụ kiện           | P0      |
| 05     | Pet Gameplay               | Nhận nuôi, cho ăn, chơi, ngủ            | P0      |
| 06     | Farming Assets             | Tạo luống đất, rau, dụng cụ             | P0      |
| 07     | Farming Gameplay           | Gieo hạt, tưới, thu hoạch               | P0      |
| 08     | Gameplay Integration       | Liên kết kinh tế, thú cưng, vườn        | P0      |
| 09     | Home Asset Polish          | Nâng cấp nội thất và ngôi nhà           | P1      |
| 10     | Business Asset Polish      | Nâng cấp tiệm sửa xe và hủ tiếu         | P1      |
| 11     | Neighborhood Life          | Làm khu phố sống động hơn               | P1      |
| 12     | Final Integration & Review | Tích hợp và rà soát source              | P0      |

Quy tắc: Mỗi prompt chạy trên branch/worktree riêng nếu làm song song. Agent không tự merge hoặc push `main`. Prompt 08 và 12 phải chạy sau các phần phụ thuộc.

## Phase 1 — Hoàn thiện mua sắm và nội thất

### Prompt 01 — Fix Shopping, Inventory & Upgrade Logic

Mục tiêu: Bảo đảm người chơi kiếm được tiền thì có thể mua đồ và nâng cấp thực sự.

```

You are a Senior Godot 4.7.2 Gameplay Engineer.

Repository:
https://github.com/thanh-pham2k/3d-asset-demo

TASK
Fix and complete the existing shopping, inventory, and upgrade systems.

Read AGENTS.md and inspect the latest source on the current branch.

Relevant files:
- scripts/neighborhood/shop_kiosk.gd
- scripts/economy/economy_product.gd
- scripts/economy/economy_manager.gd
- scripts/economy/inventory_manager.gd
- scripts/house/house_progression_manager.gd
- scripts/coop/dual_confirmation_manager.gd

REQUIREMENTS

1. Fix invalid product field references:
   - Use EconomyProduct.name instead of title.
   - Use EconomyProduct.price instead of base_price.

2. Fix co-op purchase confirmation:
   - Exactly one purchase per approval.
   - Never execute a purchase twice.
   - Handle approval, rejection, timeout, and insufficient funds.

3. Ensure purchased items appear in inventory.
4. Ensure furniture purchases can be delivered and placed at home.
5. Preserve existing business upgrades.

6. Implement missing functional effects for:
   - upg_house_tile_yard
   - upg_house_flower_garden
   - upg_house_modern_kitchen

7. Ensure purchased upgrades visibly affect the house.
8. Restore purchased items and upgrades correctly after loading.
9. Prevent duplicate purchases of unique items.
10. Keep existing save files compatible.

CONSTRAINTS
- Minimal changes.
- Reuse existing economy and house architecture.
- Do not add unrelated gameplay.
- Do not modify visual assets unnecessarily.
- Do not run tests, Godot, builds, or GIF generation.

DELIVERABLE
Implement directly and report:
- Root causes.
- Modified files.
- Fixes completed.
- Remaining limitations.
- Tests: NOT RUN.

Do not commit, merge, or push automatically.

```

### Prompt 02 — Professional Shopping UI

Mục tiêu: Có menu mua sắm thực sự thay vì chỉ đọc prompt trên màn hình.

```

You are a Senior Godot 4.7.2 UI/UX Engineer.

TASK
Implement a polished in-game Shopping UI for Couple Chaos 3D.

Read AGENTS.md and reuse the existing ShopKiosk,
EconomyManager, EconomyProduct, and InventoryManager.

EXPECTED FLOW
Approach Store → Press E → Open Shop UI
→ Browse Products → Preview Item → Purchase
→ Inventory Updated → Close Shop.

REQUIREMENTS

1. Create a reusable Shopping UI with:
   - Store name
   - Product categories
   - Product grid/list
   - Product name
   - Price
   - Description
   - Product preview
   - Owned quantity/status
   - Wallet balance
   - Purchase confirmation

2. Support these stores:
   - Furniture Store
   - Wet Market
   - Garage Parts Store
   - House Upgrade Board
   - Business Upgrade Stations

3. Display clear feedback for:
   - Purchase successful
   - Insufficient funds
   - Already owned
   - Inventory updated
   - Co-op approval required

4. Allow switching products before purchase.
5. Allow closing with Esc.
6. Disable gameplay movement while the shop modal is open.
7. Ensure product information comes from existing catalog data.
8. Support keyboard and mouse.
9. Preserve the cozy pastel low-poly game style.
10. Keep the UI readable at 1280x720 and 1920x1080.

CONSTRAINTS
- Do not duplicate purchase or wallet logic.
- Do not create a second inventory system.
- Do not redesign unrelated HUD elements.
- Reuse current UI conventions.
- Do not run tests, launch Godot, or generate GIFs.

DELIVERABLE
Implement the reusable Shopping UI and integrate it
with all existing shop kiosks.

Report changed files and any unresolved limitations.
Do not commit or push automatically.

```

### Prompt 03 — Interactive Home Furniture

Mục tiêu: Đồ nội thất mua về phải có tác dụng, không chỉ để trưng bày.

```

You are a Senior Godot 4.7.2 Gameplay Developer.

TASK
Make purchased home furniture meaningfully interactive.

Read AGENTS.md and inspect:
- scripts/room.gd
- scripts/house/
- scripts/house/furniture_data.gd
- scripts/interactable.gd
- scripts/economy/

REQUIREMENTS

1. Preserve existing furniture placement and rearrangement.

2. Implement interactions:
   - Sofa: Sit / Stand
   - Bed: Sleep / Wake
   - TV: Turn On / Off
   - Fridge: Open / Close and access stored ingredients
   - Wardrobe: Open / Close; future clothing support
   - Lamp: Turn On / Off
   - Dining Chair: Sit / Stand
   - Bookshelf: Simple reading interaction
   - Kitchen Counter: Prepare simple food
   - Potted Plant: Water and display its condition

3. Each interaction must include:
   - Clear E interaction prompt
   - Proper character positioning
   - Appropriate visual state
   - Simple animation or procedural fallback
   - Collision-safe behavior

4. Do not let the player interact through walls.
5. Prevent incorrect sitting and floating poses.
6. Support furniture placed in different positions and rotations.
7. Persist relevant furniture states when appropriate.
8. Keep interactions lightweight and enjoyable.

CONSTRAINTS
- Reuse existing furniture and interaction systems.
- Avoid inventing a new inventory or save architecture.
- Do not modify pet or farming systems.
- Keep changes focused.
- Do not execute tests, Godot, or GIF capture.

DELIVERABLE
Complete the furniture interactions.
Report what is functional versus decorative.
Do not commit or push automatically.

```

## Phase 2 — Pet System: Nuôi thú cưng

[3D Model: Cute Cartoon 3D Cat Character, Full Body, Standing On Four Legs, Listening Pose, | Tripo AI](https://images.openai.com/static-rsc-4/zonlBz3Nz4RJoLzryPSJVnclWwaHb3ZKhAdwnRgtp9Ha8f_A3qlhqJ2Cp67Hl4orqvRBLUanIDopQkGonHE4gTSyEY-zmd6T2QR9OvjsgX5L914Py9xRIKO84Oym_OSWSInjxLd7zDu7HBjAPai5uqVZhlKbE_fBTu3maZSWAzQ?purpose=inline)

MVP: Một chú mèo cam

Mèo có thể đi theo, ăn, ngủ, chơi và phản ứng với người chơi. Tập trung vào trải nghiệm sống động trước khi mở rộng sang chó hoặc nhiều giống thú.

### Prompt 04 — Create Pet Low-Poly Assets

Mục tiêu: Có model mèo, animation và các vật dụng cần thiết.

```

You are a Senior Stylized 3D Game Artist and Godot Asset Engineer.

Repository:
https://github.com/thanh-pham2k/3d-asset-demo

TASK
Create and integrate production-quality low-poly pet assets
for the future Pet System MVP.

Read AGENTS.md and inspect existing visual conventions.

ART DIRECTION
- Cozy Vietnamese neighborhood life simulation
- Stylized low-poly 3D
- Warm pastel palette
- Cute proportions
- Rounded silhouette
- Soft matte materials
- Consistent scale with Boy, Girl, and existing furniture

PRIMARY CHARACTER
Create one cute orange tabby cat with:
- Large expressive head
- Short legs
- Rounded body
- Small triangular ears
- Dark orange stripes
- Cream belly
- Expressive eyes
- Small curved tail

REQUIRED ANIMATIONS
- Idle
- Walk
- Run
- Sit
- Sleep
- Eat
- Drink
- Play
- Happy reaction
- Follow / turn

REQUIRED PROPS
- Food bowl
- Water bowl
- Pet bed
- Toy ball
- Cat scratching post
- Cat toy wand
- Pet food package
- Small collar with bell

TECHNICAL REQUIREMENTS
- Reusable .glb assets where supported.
- Clean Godot scenes wrapping each asset.
- Consistent pivots, scale, and orientation.
- AnimationPlayer/AnimationLibrary or equivalent reusable animations.
- Separate collision shapes.
- No unnecessary high-poly geometry.
- Avoid broken materials or external texture references.
- Create reasonable procedural low-poly meshes if external
  modeling tools are unavailable.
- Do not claim to deliver a rigged GLB if only procedural
  Godot meshes are implemented.

SUGGESTED STRUCTURE
assets/pets/cat/
scenes/pets/
scripts/pets/

SCOPE
Only create assets, animation adapters, and scene wrappers.
Do not implement pet AI or pet economy.

Do not run tests, launch Godot, or generate GIFs.

DELIVERABLE
- Asset inventory
- Asset files
- Godot scene wrappers
- Animation list
- Integration instructions
- Known limitations

Do not commit or push automatically.

```

### Prompt 05 — Implement Pet Gameplay

Mục tiêu: Mèo thực sự sống cùng người chơi.

```

You are a Senior Godot 4.7.2 AI and Gameplay Developer.

TASK
Implement the Pet System MVP for Couple Chaos 3D.

Read AGENTS.md and inspect the latest repository.

Reuse the pet asset scenes produced by the Pet Asset workstream.
If assets are not integrated yet, use a clearly marked temporary
visual adapter without blocking the gameplay architecture.

CORE GAMEPLAY

Adopt Cat → Bring Home → Feed → Pet → Play
→ Sleep → Increase Affection → Repeat Next Day.

REQUIREMENTS

1. PET ENTITY
- Unique pet ID
- Custom pet name
- Hunger
- Happiness
- Affection
- Current activity
- Home position

2. PET STATE MACHINE
- IDLE
- FOLLOWING
- EATING
- DRINKING
- PLAYING
- SLEEPING
- RESTING

3. PET AI
- Walk naturally around the house.
- Follow the player when appropriate.
- Avoid walls and furniture.
- Move to the food bowl when hungry.
- Sleep on its own pet bed.
- React when the player approaches.
- Recover safely if navigation fails.

4. PLAYER INTERACTION
- Press E to pet the cat.
- Feed using purchased pet food.
- Refill water.
- Play using pet toys.
- Display simple mood feedback.

5. PET SHOP
Extend the existing economy catalog with:
- Cat adoption
- Pet food
- Food bowl
- Water bowl
- Pet bed
- Cat toys

Reuse existing Shopping UI and household wallet.

6. PROGRESSION
- Affection increases through care.
- Pet reacts differently as affection increases.
- No harsh punishment for missing a day.
- Do not permanently lose the pet due to neglect.

7. PERSISTENCE
Save and restore:
- Pet ownership
- Name
- Hunger
- Happiness
- Affection
- Equipped accessories
- Relevant pet state

8. GAMEPLAY QUALITY
- Keep the cat cute and playful.
- Avoid excessive maintenance.
- Do not let the cat block doorways.
- Ensure the pet can coexist with furniture placement.
- Prevent duplicate pet adoption and purchases.

CONSTRAINTS
- Reuse existing economy and save architecture.
- Do not modify farming or business systems.
- Keep logic separate from visual assets.
- Do not run tests or launch Godot.
- Do not generate GIFs.

DELIVERABLE
Implement a playable Pet System MVP.

Report new files, modified integration points, and limitations.
Do not commit or push automatically.

```

## Phase 3 — Farming System: Trồng rau trong sân

[Low-poly Modern House - Finished Projects - Blender Artists Community](https://images.openai.com/static-rsc-4/VlKet6CecRbcANr4vR1wvu70bsS0FIe07PYOsPPO7pUNk4WEp51xQheXcpccjIz01g7eobA1xogqO0TY4PkBEVog1Vw3sdxEyEzuV-hAAoZ6FOLH2Q-kTlPj5nTipbCaAbKvW750wmGjZOMUH0vlvNRaQCOA54xn57ij1gHB4A8?purpose=inline)

MVP: 3 loại cây

Cải xanh, cà chua và cà rốt. Người chơi mua hạt giống, trồng, tưới nước, chờ cây lớn và thu hoạch.

### Prompt 06 — Create Farming Low-Poly Assets

```

You are a Senior Stylized Low-Poly 3D Asset Artist.

Repository:
https://github.com/thanh-pham2k/3d-asset-demo

TASK
Create a complete low-poly farming asset pack for the
home garden MVP.

Read AGENTS.md and follow existing asset conventions.

REQUIRED ENVIRONMENT ASSETS
- Small garden plot
- Raised garden bed
- Empty soil
- Dry soil
- Watered soil
- Wooden garden fence
- Garden pathway
- Compost bag
- Seed storage box

REQUIRED TOOLS
- Watering can
- Shovel
- Hoe
- Harvest basket
- Seed packets

REQUIRED CROPS
1. Lettuce / Vietnamese leafy greens
2. Tomato
3. Carrot

Each crop must have distinct visual stages:
- Seeded soil
- Sprout
- Growing plant
- Mature plant / harvest ready

REQUIRED COLLECTIBLES
- Harvested lettuce
- Harvested tomatoes
- Harvested carrots
- Seed packet for each crop

VISUAL REQUIREMENTS
- Warm cozy low-poly style
- Consistent proportions with current neighborhood
- Rounded shapes and clean silhouettes
- Low material count
- Reusable color palette
- Clear differences between growth stages

TECHNICAL REQUIREMENTS
- Export reusable GLB models where available.
- Create Godot scene wrappers.
- Keep local origins and pivots consistent.
- Separate collision from visuals.
- Support swapping crop stages dynamically.
- Avoid unnecessary geometry and textures.
- Use procedural Godot meshes only when appropriate,
  and report them accurately.

SUGGESTED OUTPUT
assets/farming/
scenes/farming/

Do not implement farming gameplay logic.
Do not modify economy or save systems.
Do not run Godot, automated tests, or GIF capture.

DELIVERABLE
Create all required farming MVP assets.
Report files created and missing capabilities.
Do not commit or push automatically.

```

### Prompt 07 — Implement Farming Gameplay

```

You are a Senior Godot 4.7.2 Gameplay Developer.

TASK
Implement a complete lightweight home Farming System.

Read AGENTS.md and inspect:
- scripts/neighborhood/world.gd
- scripts/neighborhood/time_manager.gd
- scripts/neighborhood/daily_loop_manager.gd
- scripts/economy/
- scripts/house/
- Existing garden and planter assets

CORE FLOW
Buy Seeds → Prepare Soil → Plant
→ Water → Grow → Harvest
→ Store / Sell / Use Produce.

REQUIREMENTS

1. FARMING DATA
Create reusable crop definitions containing:
- Crop ID
- Display name
- Seed item ID
- Growth duration
- Growth stage
- Water requirement
- Harvest quantity
- Sell price

2. FARM PLOTS
- Designate a small home garden area.
- Support multiple independent plots.
- Allow planting only on available plots.
- Display crop growth visually.
- Prevent duplicate planting.

3. CROPS
Implement:
- Leafy greens
- Tomatoes
- Carrots

4. FARMING INTERACTIONS
- Prepare soil
- Select seed
- Plant seed
- Water crop
- Inspect crop status
- Harvest mature crop

Use the existing interaction key and system.

5. TIME INTEGRATION
- Grow crops using the existing in-game clock.
- Support sleeping and advancing to the next day.
- Prevent double growth on repeated day transitions.
- Do not require continuous watering every few seconds.

6. INVENTORY & ECONOMY
- Buy seeds using the shared wallet.
- Consume seeds when planting.
- Add harvested produce to inventory.
- Allow selling produce at an appropriate existing kiosk.
- Keep transaction IDs unique.

7. PERSISTENCE
Save and restore:
- Plot ID
- Crop ID
- Growth stage
- Growth progress
- Water state
- Harvest state

Ensure compatibility with existing save files.

8. UX
- Show crop name.
- Show growth progress.
- Show water status.
- Clearly indicate harvest-ready crops.
- Keep interactions simple and satisfying.

CONSTRAINTS
- Reuse the existing economy, inventory, and time systems.
- Do not create a second time manager.
- Avoid changing pet or business implementation.
- Use existing farming asset scenes.
- Keep the number of crops limited to three for MVP.
- Do not run tests, launch Godot, or capture GIFs.

DELIVERABLE
Implement the complete Farming MVP.
Report modified files, gameplay flow, and limitations.
Do not commit or push automatically.

```

## Phase 4 — Kết nối gameplay và nâng cấp hình ảnh

### Prompt 08 — Connect Economy, Farming, Pets & Daily Loop

Mục tiêu: Biến các hệ thống độc lập thành một vòng chơi có ý nghĩa.

Phụ thuộc: Hoàn thành Prompt 01–07 trước.

```

You are a Senior Godot 4.7.2 Gameplay Systems Architect.

TASK
Integrate the existing Business, Shopping, Home,
Pet, Farming, and Daily Loop systems into one coherent
life-simulation gameplay loop.

Read AGENTS.md and inspect all current implementations.

EXPECTED GAMEPLAY

Wake Up
→ Feed Cat / Water Plants
→ Commute to Workplace
→ Serve Customers
→ Earn Money
→ Buy Groceries, Seeds, Pet Food, or Furniture
→ Return Home
→ Harvest Vegetables / Decorate House / Play with Cat
→ Sleep
→ Start Next Day.

REQUIREMENTS

1. SINGLE SHARED ECONOMY
- Use the existing HouseholdWallet.
- All earning and spending must be recorded.
- Prevent duplicate transactions.
- Preserve correct wallet balance.

2. INVENTORY INTEGRATION
- Seeds are consumed when planted.
- Pet food is consumed when feeding.
- Crops are added to inventory when harvested.
- Cooking ingredients are consumed when required.
- Purchased furniture remains available for placement.

3. BUSINESS CONNECTIONS
- Allow harvested vegetables to be used as Hu Tieu ingredients
  where a recipe actually requires them.
- Allow using purchased repair supplies in garage workflows.
- Make inventory requirements understandable and fair.
- Do not introduce a softlock when supplies run out.
- Provide a starter supply or a clear restocking flow.

4. DAILY LOOP
- Update crops once per valid time progression.
- Update pet needs gradually.
- Preserve house and shop progression.
- Keep the existing sleep and day transition system.
- Prevent repeated daily rewards and duplicated growth.

5. HOME PROGRESSION
- Furniture purchases affect the visible home.
- House upgrades unlock usable space.
- Garden upgrades unlock more planting capacity when available.
- Pet accessories appear after equipping.

6. PLAYER OBJECTIVES
Create a simple daily objective system:
- Serve customers
- Earn a target amount
- Feed the pet
- Water crops
- Harvest produce
- Purchase or place furniture

Avoid forcing every objective every day.
Support optional cozy activities.

7. SAVE/LOAD
- Use one coordinated persistence architecture.
- Preserve older save files.
- Avoid conflicting state ownership.
- Ensure all systems restore consistently.

8. GAMEPLAY BALANCE
- Early progression must be achievable without excessive grinding.
- Farming and pet care should complement work, not punish the player.
- Avoid creating multiple disconnected currencies.
- Keep the experience relaxing.

CONSTRAINTS
- Reuse existing managers and entities.
- No unrelated refactoring.
- No new framework unless necessary.
- Do not change character art or world layout unnecessarily.
- Do not run Godot, tests, builds, or GIF generation.

DELIVERABLE
Implement integration directly.

Report:
- Systems connected
- Data flow
- Modified files
- Remaining gaps
- Tests: NOT RUN

Do not commit or push automatically.

```

### Prompt 09 — Home Interior & Furniture Asset Polish

Mục tiêu: Biến căn nhà thành nơi người chơi muốn dành thời gian trang trí.

```

You are a Senior Stylized 3D Environment Artist
and Godot Scene Developer.

TASK
Improve the visual quality and variety of the Couple Chaos home.

Read AGENTS.md and inspect:
- scripts/room.gd
- scripts/house/
- scripts/house/furniture_data.gd
- assets/furniture/
- assets/neighborhood/
- Existing house levels

REQUIREMENTS

1. VISUAL STYLE
- Cozy low-poly Vietnamese home
- Warm pastel colors
- Rounded shapes
- Soft matte materials
- Consistent scale
- Good readability from the current camera

2. IMPROVE EXISTING FURNITURE
- Bed
- Sofa
- Dining table and chairs
- Television
- Refrigerator
- Wardrobe
- Bookshelf
- Floor lamp
- Coffee table
- Potted plants

Replace obvious placeholder boxes where appropriate.

3. ADD NEW FURNITURE ASSETS
Living Room:
- Rug
- Wall paintings
- Curtains
- Wall clock
- Small cabinet
- Decorative plants

Bedroom:
- Nightstand
- Blanket
- Pillows
- Table lamp
- Mirror
- Small dresser

Kitchen:
- Stove
- Rice cooker
- Sink
- Pots and pans
- Bowls and plates
- Kitchen shelves
- Cutting board

Bathroom:
- Sink
- Mirror
- Shower
- Toilet
- Towel rack

Utility:
- Washing machine
- Laundry basket
- Clothes hanger
- Broom
- Mop

4. HOME LEVELS
Level 1:
- Simple, modest and cozy

Level 2:
- More furniture, upgraded kitchen, better lighting

Level 3:
- Spacious, polished and visibly improved

5. TECHNICAL QUALITY
- Reusable assets and Godot scenes.
- Correct pivots and collisions.
- Furniture placement compatible.
- Avoid blocked pathways and doorways.
- Keep existing placement and save data working.
- Avoid unnecessary scene complexity.

6. ASSET REGISTRY
Update the furniture definitions only for items
that have actual usable scenes and clear ownership.

Do not add fake catalog entries without assets.

CONSTRAINTS
- Do not redesign the entire house architecture.
- Do not modify core wallet or pet/farming logic.
- Do not run Godot or tests.
- Do not create GIFs.

DELIVERABLE
Improve the home assets and integrate them.
Report new assets, updated scenes, and remaining placeholders.

Do not commit or push automatically.

```

### Prompt 10 — Motorcycle Repair & Hu Tieu Asset Polish

Mục tiêu: Hai địa điểm kiếm tiền trở nên sống động và có bản sắc Việt Nam.

```

You are a Senior Low-Poly 3D Game Artist
and Gameplay Animation Developer.

TASK
Upgrade the visual quality of the existing
Motorcycle Repair Shop and Hu Tieu Stall.

Read AGENTS.md and inspect the real gameplay
systems before creating or changing assets.

PART A — MOTORCYCLE REPAIR SHOP

Improve or create:
- Repair workbench
- Tool shelves
- Patch kit
- Wrenches
- Screwdrivers
- Air compressor
- Spare tires
- Motorbike parts
- Oil containers
- Mechanic stool
- Shop sign
- Customer waiting area

Add clear visuals for:
- Tire inflation
- Tire patching
- Tire replacement
- Tool pickup
- Customer arrival
- Customer departure

Create or improve simple action animations where supported.

PART B — HU TIEU STALL

Improve or create:
- Noodle cooking station
- Broth pot
- Noodle blanching basket
- Bowls
- Chopsticks and spoons
- Ingredient trays
- Shrimp, pork, ribs, herbs, lime, bean sprouts
- Condiment bottles
- Plastic stools
- Dining tables
- Food display case
- Vietnamese menu board
- Iced tea dispenser

Make different noodle dishes visually recognizable.

Add visual feedback for:
- Blanching noodles
- Adding broth
- Adding toppings
- Carrying bowls
- Serving customers
- Eating
- Paying
- Cleaning tables

PART C — ANIMATION QUALITY

- Improve hand placement.
- Improve seated poses.
- Avoid clipping through furniture.
- Align props with hands.
- Keep animations compatible with Boy, Girl, and customers.
- Preserve proper movement and interaction states.

PART D — TECHNICAL QUALITY

- Reuse existing asset wrappers.
- Respect existing station positions and gameplay triggers.
- Keep colliders separate from decoration.
- Preserve camera visibility and navigation routes.
- Keep models optimized and stylistically consistent.

CONSTRAINTS
- Do not change business pricing or order rules.
- Do not rebuild business systems.
- Do not modify unrelated economy or farming logic.
- Do not run Godot, tests, or GIF generation.

DELIVERABLE
Integrate improved low-poly assets into existing scenes.

Report:
- Created assets
- Replaced placeholders
- Updated animations
- Remaining visual limitations

Do not commit or push automatically.

```

### Prompt 11 — Living Neighborhood & NPC Improvements

Mục tiêu: Khu phố có cảm giác thật sự có người sinh sống.

```

You are a Senior Godot 4.7.2 World Simulation
and Environment Developer.

TASK
Make the existing Couple Chaos neighborhood
feel more alive without expanding the map.

Read AGENTS.md and inspect:
- scripts/neighborhood/world.gd
- scripts/neighborhood/npc_manager.gd
- scripts/neighborhood/npc_controller.gd
- scripts/neighborhood/npc_data.gd
- scripts/neighborhood/time_manager.gd
- scripts/neighborhood/module.gd
- Existing NavigationAgent3D and navigation routes

1. IMPROVE EXISTING LOCATIONS

Residential Area:
- Better house details
- Front-yard decorations
- Parked scooters and bicycles
- Plants and fences
- Neighbors sitting outside

Wet Market:
- Visible produce
- Vendors
- Shopping customers
- Simple shopping interactions

Public Park:
- Sitting NPCs
- Walking NPCs
- Ambient birds
- Pet-friendly area
- Benches and flowers

Food Street:
- Outdoor tables
- Eating and drinking NPCs
- Vietnamese shop signs
- Ambient street-food activity

School:
- Students walking to and from school
- School entrance details
- Basic daily routines

2. NPC BEHAVIOR
Reuse the existing 12 NPC definitions.

Add or improve:
- Walking
- Sitting
- Shopping
- Eating
- Talking
- Resting
- Returning home

Keep schedules consistent with the existing time system.

3. AMBIENT LIFE
- Birds
- Butterflies
- Tree movement
- Street lights at night
- Gentle environmental particles
- Small idle animations
- Ambient neighborhood sounds when assets exist

4. GAMEPLAY INTERACTIONS
- NPC greetings
- Simple context-sensitive conversations
- Sitting on park benches
- Visiting market stalls
- Observing neighborhood activities

5. PERFORMANCE
- Avoid unnecessary active NPC processing.
- Reuse meshes and materials.
- Preserve navigation performance.
- Prevent NPC crowding at narrow entrances.
- Avoid adding decorative objects that block roads.

CONSTRAINTS
- Do not enlarge the current map.
- Do not replace established business systems.
- Do not alter the player economy unnecessarily.
- Preserve all existing neighborhood routes.
- Avoid unrelated refactoring.
- Do not run tests, Godot, or GIF generation.

DELIVERABLE
Improve existing neighborhood zones directly.
Report changes and remaining visual placeholders.

Do not commit or push automatically.

```

## Phase 5 — Integration & Final Code Review

### Prompt 12 — Integrate All Systems & Static Review

Mục tiêu: Tổng hợp các thay đổi, xử lý xung đột, bảo đảm gameplay nhất quán trước khi thực hiện test ở một giai đoạn riêng.

```

You are a Senior Godot 4.7.2 Technical Lead
and Gameplay Systems Architect.

Repository:
https://github.com/thanh-pham2k/3d-asset-demo

TASK
Integrate all completed Couple Chaos gameplay
and low-poly asset workstreams into one consistent game.

Read AGENTS.md and inspect the latest source.

WORKSTREAMS
1. Shopping & Economy Fixes
2. Shopping UI
3. Furniture Interactions
4. Pet Assets
5. Pet Gameplay
6. Farming Assets
7. Farming Gameplay
8. Gameplay Integration
9. Home Asset Polish
10. Business Asset Polish
11. Neighborhood Life Improvements

IMPORTANT
First determine which workstreams have actually been completed
and which branches contain their changes.

Do not assume every feature has been implemented.

INTEGRATION REQUIREMENTS

1. Resolve overlapping changes carefully.
2. Preserve existing functionality.
3. Avoid duplicate managers and conflicting signals.
4. Use the existing shared economy and inventory.
5. Ensure there is only one source of truth for:
   - Money
   - Inventory
   - Current day
   - House upgrades
   - Pet ownership
   - Crop growth state

6. Review save/load compatibility.
7. Review asset references and missing scenes.
8. Review interaction prompts and input conflicts.
9. Review player and NPC animation transitions.
10. Review integration of new systems into the world.
11. Review performance-sensitive NPC and pet processing.
12. Remove obsolete placeholder references only when safe.

STATIC CODE REVIEW
Inspect for:
- Invalid method or property references
- Missing resource paths
- Duplicate transaction execution
- Duplicate signal connections
- Invalid state transitions
- Unreachable gameplay actions
- Missing persistence fields
- Conflicting keyboard controls
- Incorrect ownership of scene nodes
- Invalid assumptions about asset availability

DOCUMENTATION
Update:
- README.md
- docs/neighborhood.md
- docs/asset-inventory.md

Document:
- Implemented gameplay features
- Available asset packs
- Remaining placeholders
- Known limitations
- How systems interact
- Future development backlog

EXECUTION CONSTRAINTS
- Do not execute automated tests.
- Do not launch Godot.
- Do not run headless validation.
- Do not generate GIFs.
- Do not perform runtime profiling.

Only perform static inspection and necessary integration fixes.
Do not claim runtime validation succeeded.

DELIVERABLE
1. Integrated implementation.
2. Resolved code conflicts.
3. Updated documentation.
4. Remaining risks.
5. Missing assets.
6. Static review findings.
7. Tests: NOT RUN.

Do not commit, merge, or push automatically.

```

## Thứ tự chạy các prompt tối ưu

Sơ đồ phụ thuộc giữa các workstream

Prompt 09, 10 và 11 có thể chạy song song với Pet/Farming trên branch riêng, sau đó đưa vào Prompt 12.

Cách triển khai tôi khuyến nghị:

- Bước 1: Chạy Prompt 01 để ổn định mua sắm và kinh tế.
- Bước 2: Chạy song song Prompt 02–03, 04 và 06.
- Bước 3: Sau khi có asset, chạy Prompt 05 và 07 trên các branch đã tích hợp phần phụ thuộc tương ứng.
- Bước 4: Chạy Prompt 08 để kết nối gameplay. Prompt 09–11 có thể được phát triển song song.
- Bước 5: Chạy Prompt 12 để tích hợp, kiểm tra source và cập nhật tài liệu.

## Mục tiêu sau khi hoàn thành

Một ngôi nhà có thể trang trí và sinh hoạt

Một chú mèo có thể chăm sóc và chơi cùng

Một khu vườn có thể trồng và thu hoạch rau

Hệ thống kiếm tiền, mua sắm và nâng cấp có ý nghĩa

Khu phố sống động với các hoạt động và NPC

Ưu tiên cao nhất của tôi là Prompt 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08. Đây là phần tạo ra gameplay thực sự. Các prompt cải thiện môi trường và hình ảnh nên triển khai sau hoặc giao agent khác thực hiện song song.

Lưu ý: Việc bỏ qua test giúp tiết kiệm thời gian trong giai đoạn này, nhưng khi tích hợp tất cả hệ thống, vẫn cần một lượt kiểm thử gameplay thực tế trước khi phát hành.