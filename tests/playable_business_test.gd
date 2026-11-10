extends SceneTree

const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")
const BusinessShop = preload("res://scripts/neighborhood/business/business_shop.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const HuTieuBusiness = preload("res://scripts/neighborhood/business/hutieu_business.gd")
const NeighborhoodTimeManager = preload("res://scripts/neighborhood/time_manager.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Playable Businesses Test Suite ---")
	
	var test_save_path := "user://test_playable_business_world.json"
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	# Instantiate neighborhood world
	var world_scene: PackedScene = load("res://scenes/neighborhood.tscn")
	var world: Node = world_scene.instantiate()
	world.economy_save_path = test_save_path
	root.add_child(world)
	current_scene = world
	
	for i in range(5):
		await process_frame
	
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness") as GarageBusiness
	check(is_instance_valid(garage), "GarageBusiness present in neighborhood")
	
	var hutieu: HuTieuBusiness = world.get_node_or_null("HuTieuBusiness") as HuTieuBusiness
	check(is_instance_valid(hutieu), "HuTieuBusiness present in neighborhood")
	
	var time_mgr: NeighborhoodTimeManager = world.get_node_or_null("TimeManager") as NeighborhoodTimeManager
	check(is_instance_valid(time_mgr), "NeighborhoodTimeManager connected to businesses")
	
	var player: Node3D = world.get_node_or_null("Player") as Node3D
	check(is_instance_valid(player), "Player present in scene")
	
	# -------------------------------------------------------------
	# Test 1: Operating Hours (Open/Close System)
	# -------------------------------------------------------------
	time_mgr.set_hour(8.0) # 8:00 AM
	check(garage.is_open, "Garage is open during morning business hours (8:00)")
	check(hutieu.is_open, "Hu Tieu shop is open during morning business hours (8:00)")
	
	time_mgr.set_hour(23.0) # 11:00 PM
	check(not garage.is_open, "Garage is closed at night (23:00)")
	check(not hutieu.is_open, "Hu Tieu shop is closed at night (23:00)")
	
	time_mgr.set_hour(9.0) # Re-open
	check(garage.is_open and hutieu.is_open, "Shops reopen in daytime")
	
	# -------------------------------------------------------------
	# Test 2: Motorcycle Repair - Inflate Service
	# -------------------------------------------------------------
	print("\n--- Testing Motorcycle Repair: Inflate Service ---")
	garage.auto_spawn_customers = false # Control spawning deterministically
	garage.active_orders.clear()
	garage.bay_orders.clear()
	
	var inflate_order := BusinessOrder.new(
		"test_inflate_1",
		"inflate",
		"Bơm lốp xe",
		20000,
		["pump_air"],
		60.0
	)
	inflate_order.table_index = 0
	inflate_order.customer_name = "Bác Năm"
	inflate_order.target_spot = garage.bay_positions[0]
	garage.bay_orders[0] = inflate_order
	garage.active_orders.append(inflate_order)
	
	var bay0_station = garage.get_node_or_null("BikeBay_0")
	check(is_instance_valid(bay0_station), "BikeBay_0 station exists")
	check(bay0_station.available(player), "BikeBay_0 is available for player interaction")
	
	var prompt_inflate: String = bay0_station.prompt(player)
	check("Bơm lốp xe" in prompt_inflate, "Prompt reflects inflate service: '%s'" % prompt_inflate)
	
	var initial_garage_earnings := garage.total_earnings
	# Perform pump action
	bay0_station.interact(player)
	
	check(inflate_order.status == BusinessOrder.Status.PAID, "Inflate order status is PAID")
	check(garage.total_earnings == initial_garage_earnings + 20000, "Earnings increased by 20,000đ (total = %d)" % garage.total_earnings)
	check(garage.customers_served == 1, "Customers served counter incremented to 1")
	
	# Test duplicate reward prevention
	var duplicate_reward_attempt := garage.complete_order(inflate_order)
	check(not duplicate_reward_attempt, "Duplicate reward attempt rejected")
	check(garage.total_earnings == initial_garage_earnings + 20000, "Earnings remained unchanged on duplicate attempt")
	
	# -------------------------------------------------------------
	# Test 3: Motorcycle Repair - Patch Service Sequence
	# -------------------------------------------------------------
	print("\n--- Testing Motorcycle Repair: Patch Service Sequence ---")
	var patch_order := BusinessOrder.new(
		"test_patch_1",
		"patch",
		"Vá săm xe",
		35000,
		["patch_kit", "pump_air"],
		60.0
	)
	patch_order.table_index = 0
	patch_order.customer_name = "Chú Ba"
	patch_order.target_spot = garage.bay_positions[0]
	garage.bay_orders[0] = patch_order
	garage.active_orders.append(patch_order)
	
	# Step 1: Trying to pump air without patch kit first should be rejected
	bay0_station.interact(player)
	check(patch_order.current_step_index == 0, "Pump air rejected before applying patch")
	
	# Step 2: Pick up patch kit at workbench
	var workbench_station = garage.get_node_or_null("WorkbenchStation")
	check(is_instance_valid(workbench_station), "WorkbenchStation exists")
	workbench_station.interact(player)
	check(garage.player_holding_tool == "patch_kit", "Player picked up patch kit from workbench")
	
	# Step 3: Apply patch kit at bike bay
	bay0_station.interact(player)
	check(patch_order.current_step_index == 1, "Patch kit successfully applied to tire")
	check(garage.player_holding_tool == "", "Tool consumed after application")
	
	# Step 4: Now pump air to complete
	var earnings_before_patch := garage.total_earnings
	bay0_station.interact(player)
	check(patch_order.status == BusinessOrder.Status.PAID, "Patch order successfully completed and paid")
	check(garage.total_earnings == earnings_before_patch + 35000, "Awarded 35,000đ for patch service")
	
	# -------------------------------------------------------------
	# Test 4: Motorcycle Repair - Tire Replacement Sequence
	# -------------------------------------------------------------
	print("\n--- Testing Motorcycle Repair: Replace Tire Sequence ---")
	var replace_order := BusinessOrder.new(
		"test_replace_1",
		"replace",
		"Thay lốp mới",
		50000,
		["remove_tire", "mount_tire", "pump_air"],
		60.0
	)
	replace_order.table_index = 0
	replace_order.customer_name = "Anh Dũng"
	replace_order.target_spot = garage.bay_positions[0]
	garage.bay_orders[0] = replace_order
	garage.active_orders.append(replace_order)
	
	# Step 1: Remove old tire
	bay0_station.interact(player)
	check(replace_order.current_step_index == 1, "Step 1: Removed old tire")
	check(garage.player_holding_tool == "worn_tire", "Player is holding worn tire")
	
	# Step 2: Try to mount without new tire should fail
	bay0_station.interact(player)
	check(replace_order.current_step_index == 1, "Cannot mount without new tire")
	
	# Step 3: Get new tire from tire rack
	var tire_rack = garage.get_node_or_null("TireRackStation")
	check(is_instance_valid(tire_rack), "TireRackStation exists")
	tire_rack.interact(player)
	check(garage.player_holding_tool == "new_tire", "Step 2: Picked up new tire from rack")
	
	# Step 4: Mount new tire
	bay0_station.interact(player)
	check(replace_order.current_step_index == 2, "Step 3: New tire mounted and secured")
	
	# Step 5: Pump air
	var earnings_before_replace := garage.total_earnings
	bay0_station.interact(player)
	check(replace_order.status == BusinessOrder.Status.PAID, "Step 4: Tire pumped, order completed and paid")
	check(garage.total_earnings == earnings_before_replace + 50000, "Awarded 50,000đ for tire replacement")
	
	# -------------------------------------------------------------
	# Test 5: Customer Patience & Timeout
	# -------------------------------------------------------------
	print("\n--- Testing Customer Patience & Timeout ---")
	var timeout_order := BusinessOrder.new(
		"test_timeout_1",
		"inflate",
		"Bơm lốp xe",
		20000,
		["pump_air"],
		1.0 # 1 second patience
	)
	timeout_order.table_index = 0
	garage.bay_orders[0] = timeout_order
	garage.active_orders.append(timeout_order)
	
	# Wait 1.5s for patience to expire
	await create_timer(1.2).timeout
	garage._process(0.5)
	
	check(timeout_order.status == BusinessOrder.Status.FAILED, "Order marked FAILED after patience timeout")
	check(not garage.active_orders.has(timeout_order), "Failed order removed from active queue")
	check(garage.customers_lost >= 1, "Customers lost counter incremented")
	
	# -------------------------------------------------------------
	# Test 6: Hu Tieu Shop - Cooking Sequence & Serving
	# -------------------------------------------------------------
	print("\n--- Testing Hu Tieu Shop: Cooking Sequence & Serving ---")
	hutieu.auto_spawn_customers = false
	hutieu.active_orders.clear()
	hutieu.table_orders.clear()
	hutieu.current_bowl_state = HuTieuBusiness.BowlState.EMPTY
	
	var noodle_order := BusinessOrder.new(
		"test_hutieu_1",
		"noodle_nam_vang",
		"Hủ tiếu Nam Vang",
		45000,
		["boil_noodles", "add_broth", "add_toppings", "serve_table"],
		60.0
	)
	noodle_order.table_index = 0
	noodle_order.customer_name = "Cô Mai"
	noodle_order.target_spot = hutieu.table_positions[0]
	hutieu.table_orders[0] = noodle_order
	hutieu.active_orders.append(noodle_order)
	
	var table0 = hutieu.get_node_or_null("DiningTable_0")
	var blanch_pot = hutieu.get_node_or_null("BlanchingStation")
	var broth_pot = hutieu.get_node_or_null("BrothStation")
	var topping_counter = hutieu.get_node_or_null("ToppingsStation")
	
	check(is_instance_valid(table0), "DiningTable_0 station exists")
	check(is_instance_valid(blanch_pot), "BlanchingStation exists")
	check(is_instance_valid(broth_pot), "BrothStation exists")
	check(is_instance_valid(topping_counter), "ToppingsStation exists")
	
	# Step 1: Trying to serve empty bowl should fail
	table0.interact(player)
	check(noodle_order.status == BusinessOrder.Status.PENDING, "Cannot serve before cooking")
	
	# Step 2: Trying to add broth before noodles should fail
	broth_pot.interact(player)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.EMPTY, "Broth rejected on empty bowl")
	
	# Step 3: Blanch noodles in boiling pot
	blanch_pot.interact(player)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.BLANCHING, "Noodles placed into boiling strainer (BLANCHING)")
	
	# Fast-forward blanch duration
	hutieu.blanch_timer = 0.0
	hutieu._process(0.1)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.NOODLES_DONE, "Noodles cooked to perfection (NOODLES_DONE)")
	
	# Step 4: Ladle hot bone broth
	broth_pot.interact(player)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.BROTH_ADDED, "Piping-hot bone broth ladled into bowl (BROTH_ADDED)")
	
	# Step 5: Add fresh toppings (shrimp, pork, cracklings)
	topping_counter.interact(player)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Toppings garnished, dish ready (FULLY_PREPARED)")
	check("Hủ tiếu" in hutieu.current_bowl_dish, "Dish assigned name: '%s'" % hutieu.current_bowl_dish)
	
	# Step 6: Serve to customer at Table 0
	var earnings_before_noodle := hutieu.total_earnings
	var serve_prompt: String = table0.prompt(player)
	check("Phục vụ" in serve_prompt, "Table prompt shows serving action: '%s'" % serve_prompt)
	
	table0.interact(player)
	check(noodle_order.status == BusinessOrder.Status.PAID, "Order served and paid successfully")
	check(hutieu.total_earnings == earnings_before_noodle + 45000, "Awarded 45,000đ for Hủ tiếu Nam Vang")
	check(hutieu.customers_served == 1, "Hu Tieu customers served counter incremented")
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.EMPTY, "Kitchen bowl reset for next dish")
	
	# Duplicate reward check
	var dup_hutieu_reward := hutieu.complete_order(noodle_order)
	check(not dup_hutieu_reward, "Duplicate food order reward prevented")
	
	print("\nBUSINESS_PLAYABLE_RESULT failures=", failures)
	world.free()
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	quit(1 if failures else 0)
