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
	print("\n=== Running Comprehensive End-to-End Gameplay & Business Stabilization Test Suite ===")
	
	var test_save_path := "user://test_end_to_end_save.json"
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	# Setup InputMap bindings if missing
	for action in ["p1_left", "p1_right", "p1_up", "p1_down", "p1_interact", "p1_throw", "p1_dash", "p1_run"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	
	# Instantiate World with integrated Room, Economy, Guidance
	var root_node := Node3D.new()
	root.add_child(root_node)
	
	var world := Node3D.new()
	world.set_script(WorldScript)
	world.integrated = true
	world.economy_save_path = test_save_path
	root_node.add_child(world)
	
	# Setup shared house
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
	
	# Camera
	var camera := Camera3D.new()
	camera.position = Vector3(-45, 12, 100)
	root_node.add_child(camera)
	
	# Economy and guidance
	var econ: EconomyManager = world.economy_manager
	econ.save_file_path = test_save_path
	econ.house_manager = room
	econ._connect_businesses()
	
	var guidance := WorkplaceGuidance.new()
	guidance.player = player
	guidance.camera = camera
	root_node.add_child(guidance)
	
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness")
	var hutieu: HuTieuBusiness = world.get_node_or_null("HuTieuBusiness")
	var boy_scooter: PlayerScooter = world.boy_scooter
	var girl_scooter: PlayerScooter = world.girl_scooter
	
	# -------------------------------------------------------------
	# Test Suite 1: End-to-End Boy Gameplay Flow
	# -------------------------------------------------------------
	print("\n--- Test Suite 1: Complete Boy Flow (House -> Ride -> Garage -> Earn -> Return -> Save) ---")
	
	# Step 1: Start inside shared house
	check(player.selected_character == "boy", "Boy character selected")
	check(player.global_position.z > 65.0, "Boy starts inside shared house")
	guidance._resolve_current_destination()
	check("Cổng" in guidance.current_title or "Sân" in guidance.current_title, "Navigation guides player toward house exit")
	
	# Step 2: Open house door and exit
	var door = room.current_door
	check(is_instance_valid(door), "House front door exists")
	check(not door.toggle, "House door starts closed")
	door.interact(player)
	check(door.toggle, "House door opened with E")
	var door_body = door.get_meta("door_body") if door.has_meta("door_body") else null
	check(is_instance_valid(door_body) and door_body.collision_layer == 0, "Doorway collision disabled allowing player exit")
	
	# Step 3: Walk to front yard and mount Boy's motorcycle
	player.global_position = Vector3(-48.0, 0, 72.0)
	guidance._resolve_current_destination()
	check("Xe Máy Của Boy" in guidance.current_title, "Guidance identifies Boy's motorcycle in yard")
	
	check(boy_scooter.available(player), "Boy's scooter available for mounting")
	boy_scooter.mount(player)
	check(boy_scooter.is_mounted, "Boy mounted scooter successfully")
	check(player.has_meta("riding_scooter"), "Player marked with riding_scooter meta")
	
	# Step 4: Auto-cruise along valid road network to garage
	boy_scooter.start_auto_cruise()
	check(boy_scooter.auto_cruising, "Auto-cruise started")
	check(boy_scooter.cruise_waypoints.size() >= 6, "Auto-cruise path has road waypoints")
	
	# Verify waypoints follow road coordinates (Boulevard Z=0, West Ave X=-80, Local Rd Z=50)
	var waypoints_on_road := true
	for wp in boy_scooter.cruise_waypoints:
		var on_boul := absf(wp.z) <= 12.0
		var on_west_ave := absf(wp.x - (-80.0)) <= 6.0
		var on_local_rd := absf(wp.z - 50.0) <= 6.0
		var on_home_lane := absf(wp.x - (-45.0)) <= 6.0 and wp.z >= 50.0
		var on_bay := wp.distance_to(boy_scooter.work_parking_pos) < 2.0 or wp.distance_to(boy_scooter.home_parking_pos) < 2.0
		if not (on_boul or on_west_ave or on_local_rd or on_home_lane or on_bay):
			waypoints_on_road = false
	check(waypoints_on_road, "All auto-cruise waypoints strictly follow valid road grid (no building clipping)")
	
	# Fast-forward auto-cruise to destination
	boy_scooter.cruise_waypoint_idx = boy_scooter.cruise_waypoints.size()
	boy_scooter._process_auto_cruise(0.1)
	check(not boy_scooter.is_mounted, "Boy auto-dismounted upon arriving at garage")
	check(boy_scooter.global_position.distance_to(boy_scooter.work_parking_pos) < 0.1, "Boy's scooter neatly parked in garage bay")
	
	# Step 5: Garage Repair Service
	var bay0 = garage.get_node_or_null("BikeBay_0")
	var bench = garage.get_node_or_null("WorkbenchStation")
	check(is_instance_valid(bay0) and is_instance_valid(bench), "Garage repair stations valid")
	
	var repair_order := BusinessOrder.new(
		"boy_e2e_order_1",
		"patch",
		"Vá săm xe",
		35000,
		["patch_kit", "pump_air"],
		60.0
	)
	repair_order.table_index = 0
	garage.bay_orders[0] = repair_order
	garage.active_orders.append(repair_order)
	
	var wallet_initial := econ.wallet.balance
	# Boy picks up patch kit from workbench and repairs tire
	bench.interact(player)
	check(garage.get_holding_tool(player) == "patch_kit", "Boy picked up patch kit")
	bay0.interact(player)
	check(repair_order.get_current_required_step() == "pump_air", "Patch kit applied to customer tire")
	bay0.interact(player)
	check(repair_order.status == BusinessOrder.Status.PAID, "Repair order completed and paid")
	check(econ.wallet.balance == wallet_initial + 35000, "Shared household wallet credited +35,000đ")
	
	# Step 6: Return Home flow
	player.global_position = boy_scooter.global_position
	boy_scooter.mount(player)
	check(boy_scooter.is_mounted, "Boy remounted scooter to return home")
	
	boy_scooter.start_auto_cruise()
	check(not boy_scooter.cruise_target_is_work, "Auto-cruise recognized target is HOME")
	guidance._resolve_current_destination()
	check("Nhà" in guidance.current_title, "Navigation accurately points back to home parking spot")
	
	# Fast-forward return trip
	boy_scooter.cruise_waypoint_idx = boy_scooter.cruise_waypoints.size()
	boy_scooter._process_auto_cruise(0.1)
	check(not boy_scooter.is_mounted, "Boy dismounted at home")
	check(boy_scooter.global_position.distance_to(boy_scooter.home_parking_pos) < 0.1, "Scooter preserved in home parking spot")
	
	# Step 7: Enter house and rest in bed to save
	player.global_position = Vector3(-45, 0, 89)
	var bed = room.current_bed
	check(is_instance_valid(bed), "Bed interactable exists in house")
	bed.interact(player)
	check(player.resting != null, "Boy rests in bed")
	check(FileAccess.file_exists(test_save_path), "Progression automatically saved to disk upon resting")
	
	bed.interact(player) # Wake up
	check(player.resting == null, "Boy woke up refreshed")
	
	# -------------------------------------------------------------
	# Test Suite 2: End-to-End Girl Gameplay Flow & Strict Dish Validation
	# -------------------------------------------------------------
	print("\n--- Test Suite 2: Complete Girl Flow & Hu Tieu Dish Matching Validation ---")
	
	player.select_character("girl")
	check(player.selected_character == "girl", "Girl character selected")
	
	# Exit house and mount Girl's motorcycle
	player.global_position = Vector3(-42.0, 0, 72.0)
	girl_scooter.mount(player)
	check(girl_scooter.is_mounted, "Girl mounted her coral scooter")
	
	# Auto-cruise to Hu Tieu shop
	girl_scooter.start_auto_cruise()
	girl_scooter.cruise_waypoint_idx = girl_scooter.cruise_waypoints.size()
	girl_scooter._process_auto_cruise(0.1)
	check(girl_scooter.global_position.distance_to(girl_scooter.work_parking_pos) < 0.1, "Girl's scooter parked beside Hu Tieu stall")
	
	# Business Preparation phase: CLOSED -> PREPARING -> READY -> OPEN
	hutieu.prep_state = HuTieuBusiness.PrepState.CLOSED
	hutieu.is_open = false
	var prep_st = hutieu.prep_station
	check(is_instance_valid(prep_st), "PrepStation available")
	check("Chuẩn bị" in prep_st.prompt(player), "Prompt offers shop preparation")
	
	prep_st.interact(player)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.PREPARING, "Shop entered PREPARING phase")
	
	# Fast-forward preparation progress
	hutieu.prep_progress = 100.0
	hutieu.prep_state = HuTieuBusiness.PrepState.READY
	check("Sẵn sàng bán" in prep_st.prompt(player), "Prompt offers to open shop")
	
	prep_st.interact(player)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.OPEN and hutieu.is_open, "Shop officially OPEN")
	
	# Customer arrives at Table 0 and orders 'Hủ tiếu Nam Vang'
	var table0 = hutieu.get_node_or_null("DiningTable_0")
	var blanch = hutieu.get_node_or_null("BlanchingStation")
	var broth = hutieu.get_node_or_null("BrothStation")
	var topping = hutieu.get_node_or_null("ToppingsStation")
	
	var noodle_order_nam_vang := BusinessOrder.new(
		"ht_order_nv",
		"noodle_nam_vang",
		"Hủ tiếu Nam Vang",
		45000,
		["boil_noodles", "add_broth", "add_toppings", "serve_table"],
		60.0
	)
	noodle_order_nam_vang.table_index = 0
	hutieu.table_orders[0] = noodle_order_nam_vang
	hutieu.active_orders.append(noodle_order_nam_vang)
	
	# TEST INCORRECT DISH REJECTION:
	# Girl prepares 'Hủ tiếu sườn heo' instead of customer's 'Hủ tiếu Nam Vang'
	hutieu.current_bowl_state = HuTieuBusiness.BowlState.EMPTY
	blanch.interact(player)
	hutieu.blanch_timer = 0.0
	hutieu._process(0.1) # Noodles done
	broth.interact(player) # Broth added
	
	# Select Sườn Heo recipe (index 1)
	hutieu.set_recipe_by_title("Hủ tiếu sườn heo")
	topping.interact(player)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Bowl prepared")
	check(hutieu.current_bowl_dish == "Hủ tiếu sườn heo", "Prepared dish is 'Hủ tiếu sườn heo'")
	
	# Attempt to serve incorrect dish to Table 0
	var wallet_before_mistake := econ.wallet.balance
	table0.interact(player)
	check(noodle_order_nam_vang.status == BusinessOrder.Status.PENDING, "Incorrect dish was REJECTED: order remains PENDING")
	check(econ.wallet.balance == wallet_before_mistake, "No reward granted for incorrect dish")
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Bowl not consumed on rejection")
	
	# Discard wrong bowl at blanch pot to remake
	blanch.interact(player)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.EMPTY, "Wrong dish safely discarded at blanch station")
	
	# TEST CORRECT DISH SERVING:
	blanch.interact(player)
	hutieu.blanch_timer = 0.0
	hutieu._process(0.1)
	broth.interact(player)
	hutieu.set_recipe_by_title("Hủ tiếu Nam Vang")
	topping.interact(player)
	check(hutieu.current_bowl_dish == "Hủ tiếu Nam Vang", "Correct dish 'Hủ tiếu Nam Vang' prepared")
	
	table0.interact(player)
	check(noodle_order_nam_vang.status == BusinessOrder.Status.PAID, "Correct dish ACCEPTED: order marked PAID")
	check(econ.wallet.balance == wallet_before_mistake + 45000, "Shared household wallet credited +45,000đ")
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.EMPTY, "Kitchen bowl reset after successful serving")
	
	# -------------------------------------------------------------
	# Test Suite 3: Order Timeout, Cancellation & Duplicate Prevention
	# -------------------------------------------------------------
	print("\n--- Test Suite 3: Order Expiration, Bay Release & Duplicate Protection ---")
	
	# Expired motorcycle order
	var timeout_order := BusinessOrder.new("timeout_test", "inflate", "Bơm lốp", 20000, ["pump_air"], 1.0)
	timeout_order.table_index = 1
	garage.bay_orders[1] = timeout_order
	garage.active_orders.append(timeout_order)
	
	# Process timeout
	garage._update_orders_patience(2.0)
	check(timeout_order.status == BusinessOrder.Status.FAILED, "Expired order marked FAILED")
	check(not garage.active_orders.has(timeout_order), "Failed order removed from active queue")
	check(not garage.complete_order(timeout_order), "Cannot complete failed/expired order")
	
	# Duplicate payment prevention
	check(not econ.wallet.deposit(35000, "test", "dup", "garage_order_boy_e2e_order_1"), "Duplicate transaction blocked by wallet deduplication")
	
	# -------------------------------------------------------------
	# Test Suite 4: Persistence Consistency Across Sessions
	# -------------------------------------------------------------
	print("\n--- Test Suite 4: Save & Load Verification ---")
	
	var saved_balance := econ.wallet.balance
	var saved_earned := econ.wallet.total_earned
	econ.save_economy_state(test_save_path)
	
	# Reset wallet and reload from save file
	econ.wallet.balance = 0
	econ.wallet.total_earned = 0
	econ.load_economy_state(test_save_path)
	
	check(econ.wallet.balance == saved_balance, "Wallet balance restored correctly: %d đ" % econ.wallet.balance)
	check(econ.wallet.total_earned == saved_earned, "Total earnings restored correctly: %d đ" % econ.wallet.total_earned)
	check(econ.wallet.processed_transaction_ids.has("garage_order_boy_e2e_order_1"), "Deduplication cache preserved across session load")
	
	# Clean up test save file and world
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	root_node.queue_free()
	
	print("\nEND_TO_END_STABILIZATION_RESULT failures=", failures)
	quit(1 if failures else 0)
