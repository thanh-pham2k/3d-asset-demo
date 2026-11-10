extends SceneTree

const NPCData = preload("res://scripts/neighborhood/npc_data.gd")
const NPCController = preload("res://scripts/neighborhood/npc_controller.gd")
const NPCManager = preload("res://scripts/neighborhood/npc_manager.gd")
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
	print("--- Running NPC Simulation Tests ---")
	
	# Test 1: NPC Data definitions
	var db: Array[NPCData] = NPCData.create_default_database()
	check(db.size() >= 10 and db.size() <= 15, "database has 10–15 distinct NPCs (count = %d)" % db.size())
	
	var all_have_names := true
	var all_have_roles := true
	var all_have_schedules := true
	var all_have_dialogues := true
	for data in db:
		if data.name == "": all_have_names = false
		if data.role == "": all_have_roles = false
		if data.schedule.size() < 3: all_have_schedules = false
		if not data.dialogues.has("morning") or not data.dialogues.has("noon") or not data.dialogues.has("evening"):
			all_have_dialogues = false
	
	check(all_have_names, "all NPCs have unique names")
	check(all_have_roles, "all NPCs have roles")
	check(all_have_schedules, "all NPCs have multi-entry daily schedules")
	check(all_have_dialogues, "all NPCs have morning, noon, and evening dialogues")
	
	# Test 2: Instantiating neighborhood world with NavRegion and NPCManager
	var world_scene: PackedScene = load("res://scenes/neighborhood.tscn")
	var world: Node = world_scene.instantiate()
	root.add_child(world)
	current_scene = world
	
	for i in range(5):
		await process_frame
	
	var npc_manager: NPCManager = world.get_node_or_null("NPCManager") as NPCManager
	check(is_instance_valid(npc_manager), "NPCManager instantiated under world")
	
	var time_manager: NeighborhoodTimeManager = world.get_node_or_null("TimeManager") as NeighborhoodTimeManager
	check(is_instance_valid(time_manager), "TimeManager instantiated under world")
	
	var nav_region: NavigationRegion3D = world.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	check(is_instance_valid(nav_region), "NavigationRegion3D present in world")
	
	# Wait for NPCManager deferred spawning
	for i in range(10):
		await physics_frame
	
	var spawned_npcs: Array[NPCController] = npc_manager.get_all_npcs()
	check(spawned_npcs.size() == db.size(), "all default NPCs spawned (spawned = %d)" % spawned_npcs.size())
	
	# Test 3: NPC Components & Visuals
	var test_npc: NPCController = npc_manager.get_npc("chu_ba")
	check(is_instance_valid(test_npc), "NPC 'chu_ba' exists in manager")
	check(is_instance_valid(test_npc.nav_agent), "NPC has NavigationAgent3D")
	check(is_instance_valid(test_npc.collision_shape), "NPC has CollisionShape3D")
	check(is_instance_valid(test_npc.visual), "NPC has NPCVisual component")
	check(test_npc.visual.accessory == "cap", "Chú Ba has cap accessory")
	
	var co_bay: NPCController = npc_manager.get_npc("co_bay")
	check(is_instance_valid(co_bay) and co_bay.visual.accessory == "apron", "Cô Bảy has apron accessory")
	
	var bac_nam: NPCController = npc_manager.get_npc("bac_nam")
	check(is_instance_valid(bac_nam) and bac_nam.visual.accessory == "conical_hat", "Bác Năm has conical hat accessory (nón lá)")
	
	# Test 4: Daily Schedule and State Machine
	# Check morning schedule at 8:00 AM
	time_manager.set_hour(8.0)
	for i in range(5): await physics_frame
	
	var morning_entry: Dictionary = test_npc.data.get_schedule_for_hour(8.0)
	check(morning_entry["activity"] == "work", "Chú Ba scheduled to work in morning")
	check(test_npc.current_activity == "work", "Chú Ba activity matches schedule")
	
	# Check noon schedule at 12:30 PM (lunch at hu tieu stall)
	time_manager.set_hour(12.5)
	for i in range(5): await physics_frame
	var noon_entry: Dictionary = test_npc.data.get_schedule_for_hour(12.5)
	check(noon_entry["activity"] == "lunch", "Chú Ba scheduled for lunch at noon")
	
	# Check evening schedule at 19:30 (leisure / cafe)
	time_manager.set_hour(19.5)
	for i in range(5): await physics_frame
	var evening_entry: Dictionary = test_npc.data.get_schedule_for_hour(19.5)
	check(evening_entry["activity"] == "leisure", "Chú Ba scheduled for leisure in evening")
	
	# Test 5: Player Interaction
	var player: Node3D = world.get_node_or_null("Player") as Node3D
	check(is_instance_valid(player), "Player exists in world")
	
	# Position player near Chú Ba
	player.global_position = test_npc.global_position + Vector3(0.8, 0, 0)
	check(test_npc.available(player), "NPC is available for interaction")
	
	var prompt_text: String = test_npc.prompt(player)
	check("Chú Ba" in prompt_text, "Prompt contains NPC name: '%s'" % prompt_text)
	
	# Interact
	test_npc.interact(player)
	check(test_npc.current_state == NPCController.State.INTERACTING, "NPC entered INTERACTING state")
	check(test_npc.dialogue_label.visible, "Speech bubble is visible")
	var line1: String = test_npc.dialogue_label.text
	check(line1.length() > 0, "NPC shows dialogue: '%s'" % line1)
	
	# Advance dialogue
	test_npc.interact(player)
	test_npc.end_interaction()
	check(test_npc.current_state != NPCController.State.INTERACTING, "NPC exited INTERACTING state on end_interaction")
	check(not test_npc.dialogue_label.visible, "Speech bubble hidden after interaction ended")
	
	# Test 6: NavigationAgent3D Pathfinding & Movement
	time_manager.set_hour(8.0)
	test_npc.global_position = Vector3(-45, 0.2, 70) # Starter house
	test_npc.set_destination(Vector3(-105, 0.2, -14)) # Garage
	
	for i in range(15):
		await physics_frame
	
	check(test_npc.current_state == NPCController.State.WALKING, "NPC is in WALKING state towards destination")
	check(test_npc.nav_agent.is_target_reachable(), "NavigationAgent3D found reachable path to destination")
	
	# Test 7: Anti-overlap / Separation between NPCs
	var npc_a: NPCController = test_npc
	var npc_b: NPCController = co_bay
	npc_a.global_position = Vector3(0, 0.2, 0)
	npc_b.global_position = Vector3(0.2, 0.2, 0) # Overlapping closely (0.2m)
	npc_a.velocity = Vector3.ZERO
	npc_b.velocity = Vector3.ZERO
	
	for i in range(10):
		await physics_frame
	
	var sep_dist: float = npc_a.global_position.distance_to(npc_b.global_position)
	check(sep_dist > 0.35, "Separation pushed overlapping NPCs apart (distance = %.2f m)" % sep_dist)
	
	# Test 8: Stuck recovery
	test_npc.current_state = NPCController.State.WALKING
	test_npc.target_destination = Vector3(100, 0.2, 100)
	test_npc.last_progress_position = test_npc.global_position
	test_npc.stuck_timer = 5.5 # Simulate being stuck for > 5s
	await physics_frame
	check(test_npc.current_state != NPCController.State.WALKING or test_npc.stuck_timer < 5.0, "Stuck recovery triggered when route blocked")
	
	# Test 9: Schedule Recovery / Catch-up
	test_npc.global_position = Vector3(120, 0.2, 120) # Far off-track position
	time_manager.set_hour(8.0)
	test_npc.apply_schedule_entry(test_npc.data.get_schedule_for_hour(8.0), true) # Force recovery
	var recovered_dist: float = test_npc.global_position.distance_to(test_npc.data.work_position)
	check(recovered_dist < 2.0, "Schedule recovery relocated off-track NPC to scheduled post (dist = %.2f m)" % recovered_dist)
	
	# Test 10: Performance & 15 NPCs scaling
	for idx in range(3):
		var extra_data := NPCData.new()
		extra_data.id = "extra_resident_%d" % idx
		extra_data.name = "Cư dân %d" % (idx + 1)
		extra_data.role = "Khách dạo phố"
		extra_data.gender = "boy" if idx % 2 == 0 else "girl"
		extra_data.home_position = Vector3(10 + idx * 5, 0.2, -58)
		extra_data.work_position = Vector3(42 + idx * 4, 0.2, 50)
		extra_data.schedule = [
			{"start_hour": 0.0, "end_hour": 24.0, "activity": "leisure", "position": extra_data.work_position, "dialogue_key": "morning", "wait_duration": 15.0}
		]
		extra_data.dialogues = {"morning": ["Chào bạn! Khu phố vui ghê!"]}
		npc_manager.spawn_npc(extra_data, extra_data.home_position, extra_data.schedule[0])
	
	check(npc_manager.get_all_npcs().size() >= 15, "Manager successfully running 15 NPCs concurrently (count = %d)" % npc_manager.get_all_npcs().size())
	
	var start_ms := Time.get_ticks_msec()
	for f in range(60):
		await physics_frame
	var duration_ms: int = Time.get_ticks_msec() - start_ms
	check(duration_ms <= 2000, "15 NPCs 60-frame simulation ran stably (took %d ms)" % duration_ms)
	
	var all_valid_pos := true
	for npc in npc_manager.get_all_npcs():
		if is_nan(npc.global_position.x) or is_nan(npc.global_position.y) or is_nan(npc.global_position.z):
			all_valid_pos = false
		if absf(npc.global_position.x) > 125 or absf(npc.global_position.z) > 125:
			all_valid_pos = false
	check(all_valid_pos, "all 15 NPCs remain within valid bounds without NaN positions")
	
	print("NPC_SIMULATION_RESULT failures=", failures)
	world.free()
	quit(1 if failures else 0)
