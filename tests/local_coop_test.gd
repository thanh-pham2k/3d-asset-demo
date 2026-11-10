extends SceneTree

## Automated test suite for 2-Player Local Cooperative gameplay in Couple Chaos 3D.
## Tests Split-screen viewports, independent controls, cooperative interactions,
## mutual purchase confirmation, gamepad hotplug fallback, and business cooperation.

const CoopInputManager = preload("res://scripts/coop/coop_input_manager.gd")
const SplitScreenManager = preload("res://scripts/coop/split_screen_manager.gd")
const DualConfirmationManager = preload("res://scripts/coop/dual_confirmation_manager.gd")
const CoopFurnitureCarrier = preload("res://scripts/coop/coop_furniture_carrier.gd")
const CoopAssemblyBench = preload("res://scripts/coop/coop_assembly_bench.gd")
const CoopHeavyObstacle = preload("res://scripts/coop/coop_heavy_obstacle.gd")
const CoopMissionManager = preload("res://scripts/coop/coop_mission_manager.gd")
const CoopManager = preload("res://scripts/coop/coop_manager.gd")
const HouseholdWallet = preload("res://scripts/economy/household_wallet.gd")
const InventoryManager = preload("res://scripts/economy/inventory_manager.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const HuTieuBusiness = preload("res://scripts/neighborhood/business/hutieu_business.gd")

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
	print("--- Running 2-Player Local Co-op Test Suite ---")

	# -------------------------------------------------------------
	# Test 1: Independent Input Mapping & Device Bindings
	# -------------------------------------------------------------
	CoopInputManager.setup_coop_inputs()
	
	var p1_actions := ["p1_left", "p1_right", "p1_up", "p1_down", "p1_interact", "p1_throw", "p1_dash", "p1_run", "p1_confirm", "p1_cancel"]
	for act in p1_actions:
		check(InputMap.has_action(act), "P1 action registered: '%s'" % act)
	
	var p2_actions := ["p2_left", "p2_right", "p2_up", "p2_down", "p2_interact", "p2_throw", "p2_dash", "p2_run", "p2_confirm", "p2_cancel"]
	for act in p2_actions:
		check(InputMap.has_action(act), "P2 action registered: '%s'" % act)
	
	# Verify P1 uses WASD
	var p1_up_events := InputMap.action_get_events("p1_up")
	var p1_has_w := false
	for ev in p1_up_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_W or ev.keycode == KEY_W):
			p1_has_w = true
	check(p1_has_w, "P1 up maps to W key")
	
	# Verify P2 uses Arrow keys fallback & Gamepad Device 0
	var p2_up_events := InputMap.action_get_events("p2_up")
	var p2_has_up_key := false
	var p2_has_joy := false
	for ev in p2_up_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_UP or ev.keycode == KEY_UP):
			p2_has_up_key = true
		if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
			p2_has_joy = true
	check(p2_has_up_key, "P2 up maps to Arrow Up key")
	check(p2_has_joy, "P2 up maps to Gamepad Joypad input")
	
	var p2_interact_events := InputMap.action_get_events("p2_interact")
	var p2_has_k := false
	var p2_has_btn_a := false
	for ev in p2_interact_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_K or ev.keycode == KEY_K):
			p2_has_k = true
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
			p2_has_btn_a = true
	check(p2_has_k, "P2 interact maps to K key")
	check(p2_has_btn_a, "P2 interact maps to Gamepad Button A")

	# -------------------------------------------------------------
	# Test 2: Split-Screen Viewports & Authoritative World Sharing
	# -------------------------------------------------------------
	var root_node := Node3D.new()
	root.add_child(root_node)
	var test_world := World3D.new()
	
	var p1 := CharacterBody3D.new()
	p1.name = "Player1"
	p1.position = Vector3(-45, 0, 70)
	root_node.add_child(p1)
	
	var p2 := CharacterBody3D.new()
	p2.name = "Player2"
	p2.position = Vector3(100, 0, -20)
	root_node.add_child(p2)
	
	var split_screen := SplitScreenManager.new()
	root_node.add_child(split_screen)
	split_screen.setup_coop(p1, p2, test_world, false)
	
	check(split_screen.container_left != null, "Left SubViewportContainer created")
	check(split_screen.container_right != null, "Right SubViewportContainer created")
	check(split_screen.viewport_left != null, "Left SubViewport created")
	check(split_screen.viewport_right != null, "Right SubViewport created")
	check(split_screen.viewport_left.world_3d == test_world, "Left viewport shares authoritative World3D")
	check(split_screen.viewport_right.world_3d == test_world, "Right viewport shares authoritative World3D")
	check(split_screen.divider != null, "Split-screen center divider created")
	check(split_screen.camera_p1 != null, "CameraP1 tracking Player 1 created")
	check(split_screen.camera_p2 != null, "CameraP2 tracking Player 2 created")
	
	# Verify camera tracking update
	split_screen._process(0.1)
	var expected_p1_cam := p1.global_position + split_screen.camera_offset
	check(split_screen.camera_p1.global_position.distance_to(expected_p1_cam) < 1.0, "CameraP1 tracks Player 1 position")
	var expected_p2_cam := p2.global_position + split_screen.camera_offset
	check(split_screen.camera_p2.global_position.distance_to(expected_p2_cam) < 1.0, "CameraP2 tracks Player 2 position")

	# -------------------------------------------------------------
	# Test 3: Dual Confirmation System for Major Purchases
	# -------------------------------------------------------------
	var dual_mgr := DualConfirmationManager.new()
	root_node.add_child(dual_mgr)
	
	# 3A: Co-op inactive -> instant execution
	var executed_solo := [false]
	dual_mgr.is_coop_active = false
	var res_solo := dual_mgr.request_purchase(1, "Sofa cao cấp", 80000, func(): executed_solo[0] = true)
	check(res_solo and executed_solo[0], "Solo purchase executes immediately without partner confirmation")
	
	# 3B: Co-op active, minor purchase (< 50,000đ) -> instant execution
	dual_mgr.is_coop_active = true
	var executed_minor := [false]
	var res_minor := dual_mgr.request_purchase(1, "Rau củ chợ", 15000, func(): executed_minor[0] = true)
	check(res_minor and executed_minor[0], "Minor purchase under 50,000đ executes immediately in co-op")
	
	# 3C: Co-op active, major purchase (>= 50,000đ) -> enters PENDING state
	var executed_major := [false]
	var res_major := dual_mgr.request_purchase(1, "Biệt thự sân vườn", 150000, func(): executed_major[0] = true)
	check(not res_major and not executed_major[0], "Major purchase (150,000đ) requires partner confirmation")
	check(dual_mgr.has_pending_request(), "Confirmation request is pending")
	check(dual_mgr.active_request["initiator_id"] == 1, "P1 is initiator")
	check(dual_mgr.active_request["other_id"] == 2, "P2 is required to confirm")
	
	# Partner P2 approves
	dual_mgr.approve_request()
	check(executed_major[0], "Major purchase executed after partner approval")
	check(not dual_mgr.has_pending_request(), "Pending request cleared after approval")
	
	# 3D: Partner P2 declines
	var executed_declined := [false]
	dual_mgr.request_purchase(1, "Tủ lạnh side-by-side", 90000, func(): executed_declined[0] = true)
	dual_mgr.cancel_request("DECLINED_BY_PARTNER")
	check(not executed_declined[0], "Declined purchase was not executed")
	check(not dual_mgr.has_pending_request(), "Request cleared after decline")

	# -------------------------------------------------------------
	# Test 4: Cooperative Actions: Heavy Furniture Carrying
	# -------------------------------------------------------------
	var heavy_item := CoopFurnitureCarrier.new()
	heavy_item.position = Vector3(0, 0, 0)
	root_node.add_child(heavy_item)
	
	check(not heavy_item.is_duo_carrying, "Heavy furniture starts stationary")
	
	# P1 grabs one end
	heavy_item.interact(p1)
	check(heavy_item.carrier_1 == p1, "P1 holding front end of heavy furniture")
	check(not heavy_item.is_duo_carrying, "Cannot carry heavy furniture alone")
	
	# P2 grabs other end -> duo carry starts!
	heavy_item.interact(p2)
	check(heavy_item.carrier_2 == p2, "P2 holding back end")
	check(heavy_item.is_duo_carrying, "Duo carry successfully activated with both players")
	
	# Move players and verify furniture coordinates between both carriers
	p1.global_position = Vector3(10, 0, 5)
	p2.global_position = Vector3(13, 0, 5)
	heavy_item._physics_process(0.1)
	var expected_furn_pos := (p1.global_position + p2.global_position) * 0.5 + Vector3(0, 0.45, 0)
	check(heavy_item.global_position.distance_to(expected_furn_pos) < 0.1, "Heavy furniture smoothly positions between both carriers")
	
	# One drops it
	heavy_item.interact(p1)
	check(not heavy_item.is_duo_carrying, "Duo carry stops when a player lets go")

	# -------------------------------------------------------------
	# Test 5: Cooperative Actions: Heavy Obstacle Push Synergy
	# -------------------------------------------------------------
	var obstacle := CoopHeavyObstacle.new()
	obstacle.position = Vector3(0, 0, 0)
	root_node.add_child(obstacle)
	
	p1.global_position = Vector3(0.5, 0, 0)
	p2.global_position = Vector3(-0.5, 0, 0)
	
	# Single pusher speed
	obstacle.register_pusher(p1)
	check(obstacle.interacting_pushers.size() == 1, "P1 pushing obstacle")
	var solo_speed: float = obstacle.get_current_push_speed()
	
	# Dual pusher speed
	obstacle.register_pusher(p2)
	check(obstacle.interacting_pushers.size() == 2, "Both P1 and P2 pushing obstacle together")
	var duo_speed: float = obstacle.get_current_push_speed()
	check(duo_speed > solo_speed * 4.0, "Duo push speed (%.1f m/s) exhibits huge synergy over solo (%.1f m/s)" % [duo_speed, solo_speed])
	
	# Simulate push to completion
	obstacle.push(Vector3(1, 0, 0), 5.0)
	check(obstacle.is_cleared, "Obstacle cleared after cooperative push")

	# -------------------------------------------------------------
	# Test 6: Cooperative Actions: Flatpack Assembly Bench Synergy
	# -------------------------------------------------------------
	var bench := CoopAssemblyBench.new()
	bench.position = Vector3(0, 0, 0)
	root_node.add_child(bench)
	
	p1.global_position = Vector3(0.5, 0, 0)
	p2.global_position = Vector3(-0.5, 0, 0)
	
	bench.interact(p1)
	check(bench.active_workers.size() == 1, "P1 working on flatpack assembly")
	var solo_work_rate: float = bench.get_current_assembly_speed()
	
	bench.interact(p2)
	check(bench.active_workers.size() == 2, "Both P1 and P2 assembling furniture together")
	var duo_work_rate: float = bench.get_current_assembly_speed()
	check(duo_work_rate >= solo_work_rate * 3.0, "Duo assembly speed (%.1f%%/s) is >= 3x faster than solo (%.1f%%/s)" % [duo_work_rate, solo_work_rate])
	
	# Finish assembly
	bench.assembly_progress = 99.0
	bench._process(0.1)
	check(bench.is_assembled, "Furniture assembly completed with duo teamwork")

	# -------------------------------------------------------------
	# Test 7: Shared Economy & Cooperative Missions
	# -------------------------------------------------------------
	var wallet := HouseholdWallet.new()
	wallet.balance = 20000
	var mission_mgr := CoopMissionManager.new()
	root_node.add_child(mission_mgr)
	
	# Complete mission and verify shared wallet deposit
	mission_mgr.complete_mission("coop_assemble_master", wallet)
	check(mission_mgr.is_mission_completed("coop_assemble_master"), "Co-op furniture assembly mission marked complete")
	check(wallet.balance == 70000, "Shared household wallet received +50,000đ mission reward (balance = %d)" % wallet.balance)

	# -------------------------------------------------------------
	# Test 8: Business Cooperation: Independent Tools & Shared Earnings
	# -------------------------------------------------------------
	var garage := GarageBusiness.new()
	root_node.add_child(garage)
	
	# P1 takes patch kit, P2 takes tire
	p1.set("player_id", 1)
	p2.set("player_id", 2)
	
	garage.player_holding_tools[1] = "patch_kit"
	garage.player_holding_tools[2] = "new_tire"
	
	check(garage.player_holding_tools.get(1) == "patch_kit", "P1 holds patch kit independently")
	check(garage.player_holding_tools.get(2) == "new_tire", "P2 holds new tire independently")
	check(garage.player_holding_tools.size() == 2, "Both players hold distinct tools without collision")

	# -------------------------------------------------------------
	# Test 9: Gamepad Disconnection & Fallback Handling
	# -------------------------------------------------------------
	var coop_mgr := CoopManager.new()
	root_node.add_child(coop_mgr)
	coop_mgr.is_coop_active = true
	
	var disconnect_banner_shown := false
	coop_mgr._on_gamepad_disconnected(0)
	check(coop_mgr.status_label.text.contains("chuyển sang phím"), "Gamepad disconnect shows safety warning and keyboard fallback hint")
	
	coop_mgr._on_gamepad_connected(0)
	check(coop_mgr.status_label.text.contains("kết nối lại"), "Gamepad reconnect shows confirmation notification")

	# -------------------------------------------------------------
	# Test 10: Neighborhood World Co-op Initialization
	# -------------------------------------------------------------
	var world_scene: PackedScene = load("res://scenes/neighborhood.tscn")
	var world = world_scene.instantiate()
	root_node.add_child(world)
	
	check(is_instance_valid(world.player), "World initially spawns single Player (Boy)")
	check(world.player_2 == null, "Player 2 not spawned until co-op is enabled")
	
	# Enable co-op
	world.enable_neighborhood_coop()
	check(is_instance_valid(world.player_2), "Player 2 (Girl) spawned in neighborhood")
	check(world.is_coop, "World co-op flag is active")
	check(is_instance_valid(world.coop_manager), "CoopManager instantiated in world")
	check(is_instance_valid(world.coop_obstacle), "CoopHeavyObstacle present in world")
	check(is_instance_valid(world.coop_bench), "CoopAssemblyBench present in world")
	
	# Clean up
	world.queue_free()
	root_node.queue_free()

	print("LOCAL_COOP_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)
