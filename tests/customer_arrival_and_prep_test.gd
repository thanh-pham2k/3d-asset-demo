extends SceneTree

## Automated test suite for Customer Arrival, Hu Tieu Preparation, and Directional Navigation.

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")
const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const HuTieuBusiness = preload("res://scripts/neighborhood/business/hutieu_business.gd")
const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")
const WorkplaceGuidance = preload("res://scripts/workplace_guidance.gd")

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
	print("--- Running Customer Arrival, Hu Tieu Prep & Navigation Test Suite ---")
	
	var root_node := Node3D.new()
	root.add_child(root_node)

	# -------------------------------------------------------------
	# Test 1: Motorcycle Customer Arrival & Departure Flow
	# -------------------------------------------------------------
	print("\n--- Test 1: Motorcycle Customer Flow ---")
	var bay_pos := Vector3(-104, 0, -11)
	var approach_path: Array[Vector3] = [
		Vector3(-106, 0, 8),
		Vector3(-106, 0, -5),
		bay_pos
	]
	var departure_path: Array[Vector3] = [
		bay_pos,
		Vector3(-106, 0, -5),
		Vector3(-125, 0, 0)
	]
	
	var moto := MotorcycleCustomer.new()
	moto.name = "TestMotorcycleCustomer"
	root_node.add_child(moto)
	moto.setup(0, "Anh Tuấn", bay_pos, approach_path, departure_path)
	
	check(moto.current_state == MotorcycleCustomer.State.APPROACHING, "Motorcycle customer starts in APPROACHING state")
	check(is_instance_valid(moto.scooter), "Motorcycle vehicle model created")
	check(is_instance_valid(moto.driver), "Customer rider model created on motorcycle")
	check(moto.position.distance_to(approach_path[0]) < 0.1, "Motorcycle spawned on road at approach start")
	
	# Simulate riding along approach path to the repair bay
	for step in range(70):
		moto._process(0.1)
		if moto.current_state == MotorcycleCustomer.State.WAITING_FOR_REPAIR:
			break
	
	check(moto.current_state == MotorcycleCustomer.State.WAITING_FOR_REPAIR, "Motorcycle arrived and entered WAITING_FOR_REPAIR state")
	check(moto.position.distance_to(bay_pos) < 0.2, "Motorcycle safely parked inside designated service bay")
	check(moto.driver.position.x < -0.5, "Driver stepped off motorcycle and stands beside vehicle")
	
	# Simulate service completion -> customer mounts scooter and departs
	moto.notify_service_done()
	check(moto.current_state == MotorcycleCustomer.State.SERVICE_COMPLETED, "Entered SERVICE_COMPLETED state after repair finished")
	
	# Wait brief celebration delay then transition to DEPARTING
	moto._process(1.0)
	check(moto.current_state == MotorcycleCustomer.State.DEPARTING, "Driver mounted scooter and transitioned to DEPARTING state")
	
	# Simulate driving away to the exit road
	for step in range(70):
		moto._process(0.1)
		if moto.current_state == MotorcycleCustomer.State.DESPAWNED:
			break
	
	check(moto.current_state == MotorcycleCustomer.State.DESPAWNED, "Motorcycle customer rode away safely to exit road and despawned")
	
	# -------------------------------------------------------------
	# Test 2: Garage Business - Bay Occupancy & Overlap Prevention
	# -------------------------------------------------------------
	print("\n--- Test 2: Garage Bay Occupancy ---")
	var garage := GarageBusiness.new()
	garage.name = "TestGarage"
	garage.is_second_bay_unlocked = true
	root_node.add_child(garage)
	garage.is_open = true
	
	# Spawn customer into bay 0
	garage._try_spawn_customer()
	check(garage.bay_reserved.get(0, false), "Bay 0 marked reserved for approaching customer")
	check(garage.bay_customers.has(0), "Motorcycle customer spawned for Bay 0")
	
	# Spawn customer into bay 1
	garage._try_spawn_customer()
	check(garage.bay_reserved.get(1, false), "Bay 1 marked reserved for approaching customer")
	check(garage.bay_customers.has(1), "Motorcycle customer spawned for Bay 1")
	
	# Attempt third customer when both bays are occupied
	var third_spawn_count := garage.bay_customers.size()
	garage._try_spawn_customer()
	check(garage.bay_customers.size() == third_spawn_count, "No overlapping motorcycle spawned when all bays are occupied")

	# -------------------------------------------------------------
	# Test 3: Hu Tieu Shop - Preparation Phase: CLOSED -> PREPARING -> READY -> OPEN
	# -------------------------------------------------------------
	print("\n--- Test 3: Hu Tieu Preparation Phase ---")
	var hutieu := HuTieuBusiness.new()
	hutieu.name = "TestHuTieu"
	root_node.add_child(hutieu)
	
	check(hutieu.prep_state == HuTieuBusiness.PrepState.CLOSED, "Hu Tieu shop starts in CLOSED state")
	
	# Attempt spawning before shop is opened -> must be rejected
	hutieu._try_spawn_customer()
	check(hutieu.table_customers.is_empty(), "Customers CANNOT arrive before shop preparation and opening")
	
	var prep_st := hutieu.prep_station
	check(is_instance_valid(prep_st), "Preparation station exists at cooking counter")
	check(hutieu.get_station_prompt(prep_st, null).contains("Chuẩn bị mở quán"), "Prep prompt displays 'Chuẩn bị mở quán'")
	
	# Player interacts with prep station to begin preparation
	hutieu.on_station_interacted(prep_st, null)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.PREPARING, "Shop entered PREPARING phase")
	check(hutieu.prep_progress >= 0.0, "Preparation progress starts at 0%")
	
	# Simulate gradual preparation
	hutieu._process(1.5)
	check(hutieu.prep_progress > 20.0 and hutieu.prep_progress < 100.0, "Preparation progress increases gradually (%d%%)" % int(hutieu.prep_progress))
	
	# Complete preparation to 100%
	hutieu._process(3.0)
	check(hutieu.prep_progress >= 100.0, "Preparation reached 100%")
	check(hutieu.prep_state == HuTieuBusiness.PrepState.READY, "Shop entered READY state")
	check(hutieu.get_station_prompt(prep_st, null).contains("Sẵn sàng bán"), "Prompt updated to 'Sẵn sàng bán'")
	
	# Player presses E to officially open shop
	hutieu.on_station_interacted(prep_st, null)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.OPEN, "Shop officially opened (OPEN state)")

	# -------------------------------------------------------------
	# Test 4: Hu Tieu Dining Flow - Walk, Sit, Order, Eat, Leave
	# -------------------------------------------------------------
	print("\n--- Test 4: Hu Tieu Dining Flow ---")
	hutieu._try_spawn_customer()
	check(hutieu.table_customers.has(0), "Customer spawned after shop opened")
	var diner_cust: HuTieuCustomer = hutieu.table_customers[0]
	check(diner_cust.current_state == HuTieuCustomer.State.WALKING_TO_TABLE, "Customer starts WALKING_TO_TABLE from sidewalk")
	check(not hutieu.table_orders.has(0), "Order is NOT placed before customer sits down")
	
	# Simulate customer walking to table and sitting down
	for step in range(75):
		diner_cust._process(0.1)
		if diner_cust.current_state == HuTieuCustomer.State.SEATED_ORDERING:
			break
	
	check(diner_cust.current_state == HuTieuCustomer.State.SEATED_ORDERING, "Customer arrived at table and sat down (SEATED_ORDERING)")
	check(hutieu.table_orders.has(0), "Food order placed ONLY AFTER customer is seated")
	check(hutieu.table_occupied.get(0, false), "Table 0 occupancy registered")
	
	# Verify table prompts reflect the order
	var tbl_station: HuTieuBusiness.NoodleStation = hutieu.get_node("DiningTable_0") as HuTieuBusiness.NoodleStation
	check(hutieu.get_station_prompt(tbl_station, null).contains("đang chờ"), "Table prompt displays customer waiting for food")
	
	# Player prepares food
	hutieu.current_bowl_state = HuTieuBusiness.BowlState.FULLY_PREPARED
	hutieu.current_bowl_dish = hutieu.table_orders[0].service_title
	
	# Player serves food to table
	tbl_station.interact(null)
	check(diner_cust.current_state == HuTieuCustomer.State.EATING, "Customer entered EATING state upon being served")
	check(diner_cust.eating_bowl.visible, "Hot noodle bowl visible on table")
	
	# Simulate customer eating, paying, and standing up
	diner_cust._process(2.6)
	check(diner_cust.current_state == HuTieuCustomer.State.LEAVING, "Customer finished eating, paid, stood up, and started LEAVING")
	
	# Customer walks back out to sidewalk and despawns
	for step in range(120):
		diner_cust._process(0.1)
		if diner_cust.current_state == HuTieuCustomer.State.DESPAWNED:
			break
	
	check(diner_cust.current_state == HuTieuCustomer.State.DESPAWNED, "Customer departed sidewalk and despawned cleanly")

	# -------------------------------------------------------------
	# Test 5: Camera-Relative Directional Arrow & Dynamic Navigation
	# -------------------------------------------------------------
	print("\n--- Test 5: Directional Arrow & Navigation ---")
	var cam := Camera3D.new()
	root_node.add_child(cam)
	cam.position = Vector3(0, 25, 22)
	cam.look_at(Vector3.ZERO)
	
	var test_player := CharacterBody3D.new()
	test_player.position = Vector3(0, 0, 0)
	test_player.set_meta("selected_character", "boy")
	root_node.add_child(test_player)
	
	var nav := WorkplaceGuidance.new()
	root_node.add_child(nav)
	nav.player = test_player
	nav.camera = cam
	
	# Verify destination for Boy outside
	test_player.global_position = Vector3(0, 0, 0)
	nav._process(0.1)
	check(nav.current_destination == WorkplaceGuidance.GARAGE_DEFAULT, "Boy navigation targets Motorcycle Repair Shop")
	check(nav.direction_label.text.length() > 0, "Direction label displays glyph, title and distance")
	check(not nav.arrived, "Player is not yet at destination")
	check(nav.edge_pointer.visible, "Screen-edge pointer is visible when navigating")
	
	# Move player to within 2m of destination
	test_player.global_position = WorkplaceGuidance.GARAGE_DEFAULT + Vector3(1.0, 0, 0)
	nav._process(0.1)
	check(nav.arrived, "Navigation marks 'arrived' when within 2.5m")
	check(not nav.edge_pointer.visible, "Edge pointer hides when player reaches destination")
	
	# Switch to Girl: verify Hu Tieu guidance
	test_player.set_meta("selected_character", "girl")
	test_player.global_position = Vector3(0, 0, 0)
	nav._process(0.1)
	check(nav.current_destination == WorkplaceGuidance.NOODLE_DEFAULT, "Girl navigation targets Hu Tieu Shop")

	# -------------------------------------------------------------
	# Test 6: Tree Occlusion Cutaway
	# -------------------------------------------------------------
	print("\n--- Test 6: Tree Camera Occlusion ---")
	var tree_scene: PackedScene = load("res://scenes/neighborhood/tree.tscn")
	var tree_node = tree_scene.instantiate()
	root_node.add_child(tree_node)
	
	check(not tree_node.cutaway_meshes.is_empty(), "Tree canopy meshes registered in cutaway_meshes for camera occlusion")
	check(tree_node.visual_occlusion_bounds.size.length() > 0.0, "Tree has valid visual occlusion bounding box")

	# Clean up
	root_node.queue_free()
	
	print("\nARRIVAL_PREP_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)
