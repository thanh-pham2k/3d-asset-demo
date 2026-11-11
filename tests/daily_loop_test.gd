extends SceneTree

const Player = preload("res://scripts/player_controller.gd")
const RoomScript = preload("res://scripts/room.gd")
const WorldScript = preload("res://scripts/neighborhood/world.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const HuTieuBusiness = preload("res://scripts/neighborhood/business/hutieu_business.gd")
const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")
const EconomyManager = preload("res://scripts/economy/economy_manager.gd")
const EconomySaveSystem = preload("res://scripts/economy/economy_save_system.gd")
const PlayerScooter = preload("res://scripts/neighborhood/player_scooter.gd")
const WorkplaceGuidance = preload("res://scripts/workplace_guidance.gd")
const DailyLoopManager = preload("res://scripts/neighborhood/daily_loop_manager.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		print("FAIL: ", message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("\n=== Running Comprehensive Daily Gameplay Loop Test Suite ===")
	
	var test_save_path := "user://test_daily_loop_save.json"
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	# Setup InputMap bindings if missing
	for action in ["p1_left", "p1_right", "p1_up", "p1_down", "p1_interact", "p1_throw", "p1_dash", "p1_run"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	
	var root_node := Node3D.new()
	root.add_child(root_node)
	
	var world := Node3D.new()
	world.set_script(WorldScript)
	world.integrated = true
	world.economy_save_path = test_save_path
	root_node.add_child(world)
	
	# House room
	var house_node := Node3D.new()
	house_node.position = Vector3(-45, 0, 88)
	root_node.add_child(house_node)
	
	var room := RoomScript.new()
	house_node.add_child(room)
	
	# Player instance
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.player_id = 1
	player.position = Vector3(-45, 0, 89)
	root_node.add_child(player)
	player.select_character("boy")
	
	var camera := Camera3D.new()
	camera.position = Vector3(-45, 12, 100)
	root_node.add_child(camera)
	
	var econ: EconomyManager = world.economy_manager
	econ.save_file_path = test_save_path
	econ.house_manager = room
	econ._connect_businesses()
	
	var guidance := WorkplaceGuidance.new()
	guidance.player = player
	guidance.camera = camera
	root_node.add_child(guidance)
	
	var daily_loop: DailyLoopManager = world.daily_loop_manager
	daily_loop.guidance = guidance
	daily_loop._connect_business_signals()
	
	var time_mgr = world.time_manager
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness")
	var hutieu: HuTieuBusiness = world.get_node_or_null("HuTieuBusiness")
	var boy_scooter: PlayerScooter = world.boy_scooter
	var girl_scooter: PlayerScooter = world.girl_scooter
	
	# =============================================================
	# WORKDAY 1: Boy Flow (Motorcycle Repair Shop)
	# =============================================================
	print("\n--- Testing Workday 1: Boy Gameplay Loop ---")
	
	# 1. Wake Up & Morning State
	check(daily_loop.current_day == 1, "Day 1 initialized")
	check(time_mgr.current_day == 1, "TimeManager tracks Day 1")
	check(player.global_position.z > 65.0, "Boy starts inside starter house")
	check(econ.wallet.balance == 100000, "Starting household wallet has 100,000đ")
	
	guidance._resolve_current_destination()
	check("Cổng" in guidance.current_title or "Sân" in guidance.current_title, "Guidance points to house exit in the morning")
	
	# 2. Leave House
	var door = room.current_door
	check(is_instance_valid(door), "House front door exists")
	door.interact(player)
	check(door.toggle, "House front door opened")
	
	# Step out to yard
	player.global_position = Vector3(-48.0, 0, 72.0)
	guidance._resolve_current_destination()
	check("Xe Máy Của Boy" in guidance.current_title, "Guidance identifies Boy's scooter in front yard")
	
	# 3. Ride to Workplace
	check(boy_scooter.available(player), "Boy scooter available")
	boy_scooter.mount(player)
	check(boy_scooter.is_mounted, "Boy mounted scooter")
	
	boy_scooter.start_auto_cruise()
	check(boy_scooter.auto_cruising, "Auto-cruise started toward workplace")
	
	# Fast-forward auto-cruise to garage
	boy_scooter.cruise_waypoint_idx = boy_scooter.cruise_waypoints.size()
	boy_scooter._process_auto_cruise(0.1)
	check(not boy_scooter.is_mounted, "Dismounted at workplace")
	check(boy_scooter.global_position.distance_to(boy_scooter.work_parking_pos) < 0.1, "Scooter parked at garage bay")
	
	# 4. Open and Close Workplace Control
	var sign_station = garage.get_node_or_null("ShopSignStation")
	check(is_instance_valid(sign_station), "Garage ShopSignStation exists")
	check(sign_station.available(player), "ShopSignStation is available for interaction")
	
	# Test closing the garage
	sign_station.interact(player)
	check(not garage.is_open, "Garage successfully closed via sign station")
	
	# Test opening the garage
	var prompt_open: String = sign_station.prompt(player)
	check("Mở cửa" in prompt_open, "Prompt offers to open garage: '%s'" % prompt_open)
	sign_station.interact(player)
	check(garage.is_open, "Garage successfully opened for business")
	daily_loop.set_phase(DailyLoopManager.Phase.SERVING)
	check(daily_loop.current_phase == DailyLoopManager.Phase.SERVING, "DailyLoopManager in SERVING phase")
	
	# 5. Serve Customers & Earn Money
	var bay0 = garage.get_node_or_null("BikeBay_0")
	var bench = garage.get_node_or_null("WorkbenchStation")
	
	var order1 := BusinessOrder.new(
		"d1_order_patch_1",
		"patch",
		"Vá săm xe",
		35000,
		["patch_kit", "pump_air"],
		60.0
	)
	order1.table_index = 0
	garage.bay_orders[0] = order1
	garage.active_orders.append(order1)
	
	# Fulfill order
	bench.interact(player)
	bay0.interact(player) # apply patch
	bay0.interact(player) # pump air
	
	check(order1.status == BusinessOrder.Status.PAID, "Day 1 repair order completed and paid")
	check(daily_loop.daily_customers_served == 1, "DailyLoopManager recorded 1 customer served")
	check(daily_loop.daily_revenue == 35000, "DailyLoopManager recorded 35,000đ revenue")
	check(econ.wallet.balance == 135000, "Wallet balance increased to 135,000đ")
	
	# Test daily expense: Buy consumable repair tool (patch strip) for 10,000đ
	var buy_res := econ.purchase_product("tool_patch_strip", 1)
	check(buy_res["success"], "Purchased patch strip supply")
	check(daily_loop.daily_expenses == 10000, "DailyLoopManager recorded 10,000đ expense")
	check(econ.wallet.balance == 125000, "Wallet balance after expense: 125,000đ")
	
	# 6. Close Shop & Safe Customer Handling
	# Add a remaining customer in bay 1 to verify safe handling upon closing
	var lingering_order := BusinessOrder.new(
		"d1_lingering_order",
		"inflate",
		"Bơm lốp xe",
		20000,
		["pump_air"],
		60.0
	)
	lingering_order.table_index = 1
	garage.bay_orders[1] = lingering_order
	garage.active_orders.append(lingering_order)
	
	# Close garage via station
	var prompt_close_garage: String = sign_station.prompt(player)
	check("Đóng cửa" in prompt_close_garage, "Prompt offers to close garage: '%s'" % prompt_close_garage)
	sign_station.interact(player)
	
	check(not garage.is_open, "Garage successfully closed")
	check(garage.active_orders.size() == 0, "Active orders cleared safely on close")
	check(garage.bay_orders.size() == 0, "Bays freed safely on close")
	check(daily_loop.current_phase == DailyLoopManager.Phase.RETURN_HOME, "Phase transitioned to RETURN_HOME")
	
	# 7. End-of-Day Summary Verification
	var summary_d1 := daily_loop.get_daily_summary()
	check(summary_d1["day"] == 1, "Summary reports Day 1")
	check(summary_d1["customers_served"] == 1, "Summary reports 1 customer served")
	check(summary_d1["revenue"] == 35000, "Summary reports 35,000đ revenue")
	check(summary_d1["expenses"] == 10000, "Summary reports 10,000đ expenses")
	check(summary_d1["profit"] == 25000, "Summary reports 25,000đ daily profit (35,000 - 10,000)")
	check(summary_d1["wallet_balance"] == 125000, "Summary reports correct wallet balance: 125,000đ")
	
	daily_loop.summary_dialog.hide_summary()
	
	# 8. Return Home
	player.global_position = boy_scooter.global_position
	boy_scooter.mount(player)
	boy_scooter.start_auto_cruise()
	
	# Fast forward to home
	boy_scooter.cruise_waypoint_idx = boy_scooter.cruise_waypoints.size()
	boy_scooter._process_auto_cruise(0.1)
	check(boy_scooter.global_position.distance_to(boy_scooter.home_parking_pos) < 0.1, "Scooter safely parked in home yard")
	
	# 9. Enter House and Sleep
	player.global_position = Vector3(-45, 0, 89)
	var bed = room.current_bed
	check(is_instance_valid(bed), "Bed interactable exists in house")
	
	# Sleep in bed
	bed.interact(player)
	check(player.resting != null, "Boy rests in bed to sleep")
	
	# 10. Advance to Next Day (Day 2)
	check(daily_loop.current_day == 2, "DailyLoopManager advanced to Day 2")
	check(time_mgr.current_day == 2, "TimeManager advanced to Day 2")
	check(time_mgr.current_hour == 7.0, "Time reset to 07:00 AM morning")
	
	# Verify daily state was reset cleanly
	check(daily_loop.daily_customers_served == 0, "Day 2 daily customers reset to 0")
	check(daily_loop.daily_revenue == 0, "Day 2 daily revenue reset to 0")
	check(daily_loop.daily_expenses == 0, "Day 2 daily expenses reset to 0")
	check(not garage.is_open, "Garage is closed in morning ready for new day")
	
	# Verify wallet, inventory & upgrades preserved
	check(econ.wallet.balance == 125000, "Wallet balance preserved across days (125,000đ)")
	check(econ.inventory.has_item("tool_patch_strip", 1), "Inventory items preserved across days")
	
	# Verify deduplication prevents duplicate rewards for Day 1 order
	check(not garage.complete_order(order1), "Duplicate reward attempt for Day 1 order blocked")
	check(econ.wallet.balance == 125000, "Wallet balance unchanged on blocked duplicate reward")
	
	# Wake up
	bed.interact(player)
	check(player.resting == null, "Boy woke up refreshed on Day 2")
	
	# Guidance in Day 2 morning should guide to house exit
	guidance._resolve_current_destination()
	check("Cổng" in guidance.current_title or "Sân" in guidance.current_title, "Day 2 morning guidance correctly points to house exit, not bed")
	
	# =============================================================
	# WORKDAY 2: Girl Flow (Hu Tieu Shop)
	# =============================================================
	print("\n--- Testing Workday 2: Girl Gameplay Loop ---")
	
	player.select_character("girl")
	check(player.selected_character == "girl", "Girl character selected for Day 2")
	
	# Leave house
	player.global_position = Vector3(-42.0, 0, 72.0)
	guidance._resolve_current_destination()
	check("Xe Máy Của Girl" in guidance.current_title, "Guidance identifies Girl's coral scooter")
	
	# Mount Girl's scooter and commute to Hu Tieu stall
	girl_scooter.mount(player)
	check(girl_scooter.is_mounted, "Girl mounted her scooter")
	
	girl_scooter.start_auto_cruise()
	girl_scooter.cruise_waypoint_idx = girl_scooter.cruise_waypoints.size()
	girl_scooter._process_auto_cruise(0.1)
	check(girl_scooter.global_position.distance_to(girl_scooter.work_parking_pos) < 0.1, "Girl's scooter neatly parked beside Hu Tieu stall")
	
	# Open Hu Tieu Shop
	var prep_station = hutieu.get_node_or_null("PrepStation")
	check(is_instance_valid(prep_station), "Hu Tieu PrepStation exists")
	
	prep_station.interact(player) # Start prep
	check(hutieu.prep_state == HuTieuBusiness.PrepState.PREPARING, "Hu Tieu entered PREPARING phase")
	
	# Fast-forward prep
	hutieu.prep_progress = 100.0
	hutieu._process(0.1)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.READY, "Hu Tieu entered READY state")
	
	prep_station.interact(player) # Open shop
	check(hutieu.prep_state == HuTieuBusiness.PrepState.OPEN, "Hu Tieu officially OPEN")
	check(hutieu.is_open, "Hu Tieu is_open is true")
	
	# Serve Customer at Table 0
	var blanch = hutieu.get_node_or_null("BlanchingStation")
	var broth = hutieu.get_node_or_null("BrothStation")
	var topping = hutieu.get_node_or_null("ToppingsStation")
	var table0 = hutieu.get_node_or_null("DiningTable_0")
	
	var order2 := BusinessOrder.new(
		"d2_order_hutieu_1",
		"noodle_nam_vang",
		"Hủ tiếu Nam Vang",
		45000,
		["boil_noodles", "add_broth", "add_toppings", "serve_table"],
		60.0
	)
	order2.table_index = 0
	hutieu.table_orders[0] = order2
	hutieu.active_orders.append(order2)
	
	# Cook dish
	blanch.interact(player)
	hutieu.blanch_timer = 0.0
	hutieu._process(0.1)
	broth.interact(player)
	hutieu.set_recipe_by_title("Hủ tiếu Nam Vang")
	topping.interact(player)
	table0.interact(player)
	
	check(order2.status == BusinessOrder.Status.PAID, "Day 2 food order served and paid")
	check(daily_loop.daily_customers_served == 1, "Day 2 recorded 1 customer served")
	check(daily_loop.daily_revenue == 45000, "Day 2 recorded 45,000đ revenue")
	check(econ.wallet.balance == 170000, "Household wallet balance: 170,000đ (125,000 + 45,000)")
	
	# Close Hu Tieu Shop via prep station
	var prompt_close: String = prep_station.prompt(player)
	check("Đóng cửa" in prompt_close, "Prep station prompt offers to close shop: '%s'" % prompt_close)
	prep_station.interact(player)
	
	check(not hutieu.is_open, "Hu Tieu shop closed successfully")
	check(hutieu.prep_state == HuTieuBusiness.PrepState.CLOSED, "Hu Tieu returned to CLOSED state")
	
	# Day 2 Summary Verification
	var summary_d2 := daily_loop.get_daily_summary()
	check(summary_d2["day"] == 2, "Summary reports Day 2")
	check(summary_d2["customers_served"] == 1, "Summary reports 1 customer served")
	check(summary_d2["revenue"] == 45000, "Summary reports 45,000đ revenue")
	check(summary_d2["profit"] == 45000, "Summary reports 45,000đ profit")
	check(summary_d2["wallet_balance"] == 170000, "Summary reports 170,000đ wallet balance")
	
	daily_loop.summary_dialog.hide_summary()
	
	# Return Home on Girl's scooter
	player.global_position = girl_scooter.global_position
	girl_scooter.mount(player)
	girl_scooter.start_auto_cruise()
	girl_scooter.cruise_waypoint_idx = girl_scooter.cruise_waypoints.size()
	girl_scooter._process_auto_cruise(0.1)
	check(girl_scooter.global_position.distance_to(girl_scooter.home_parking_pos) < 0.1, "Girl's scooter parked at home yard")
	
	# Sleep in bed to advance to Day 3
	player.global_position = Vector3(-45, 0, 89)
	bed.interact(player) # Sleep
	check(daily_loop.current_day == 3, "Advanced to Day 3 after second night of sleep")
	check(time_mgr.current_day == 3, "TimeManager tracks Day 3")
	check(econ.wallet.balance == 170000, "Wallet balance preserved across two workdays (170,000đ)")
	
	bed.interact(player) # Wake up
	
	# =============================================================
	# TEST SUITE 3: Save & Load Persistence Across Days
	# =============================================================
	print("\n--- Testing Save & Load Persistence Across Days ---")
	
	# Explicit save to disk
	var save_ok := econ.save_economy_state(test_save_path)
	check(save_ok, "Saved Day 3 state to disk successfully")
	check(FileAccess.file_exists(test_save_path), "Save file exists on disk")
	
	# Create fresh isolated wallet & inventory to load into
	var fresh_wallet := HouseholdWallet.new()
	var fresh_inv := InventoryManager.new()
	var loaded_b_data := EconomySaveSystem.load_economy(fresh_wallet, fresh_inv, test_save_path)
	
	check(loaded_b_data.get("day", 1) == 3, "Restored save file correctly identifies Day 3")
	check(fresh_wallet.balance == 170000, "Restored wallet balance matches 170,000đ")
	check(fresh_inv.has_item("tool_patch_strip", 1), "Restored inventory preserved patch strips item")
	check(fresh_wallet.processed_transaction_ids.has("garage_order_d1_order_patch_1"), "Day 1 transaction ID preserved in deduplication store")
	check(fresh_wallet.processed_transaction_ids.has("hutieu_order_d2_order_hutieu_1"), "Day 2 transaction ID preserved in deduplication store")
	
	print("\nDAILY_LOOP_TEST_RESULT failures=%d" % failures)
	if failures == 0:
		print("ALL DAILY GAMEPLAY LOOP TESTS PASSED SUCCESSFULLY!")
	quit(0 if failures == 0 else 1)
