extends SceneTree

## Automated test suite for Boy & Girl Commuter Scooters and Dedicated Parking Spots.

const PlayerScooter = preload("res://scripts/neighborhood/player_scooter.gd")
const PlayerController = preload("res://scripts/player_controller.gd")

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
	print("--- Running Player Scooter & Parking Spot Test Suite ---")
	
	var root_node := Node3D.new()
	root.add_child(root_node)

	# -------------------------------------------------------------
	# Test 1: Boy's Scooter Properties & Visual Setup
	# -------------------------------------------------------------
	print("\n--- Test 1: Boy's Scooter Setup ---")
	var boy_scooter := PlayerScooter.new()
	boy_scooter.name = "TestBoyScooter"
	boy_scooter.owner_character = "boy"
	boy_scooter.scooter_color = Color("00897b")
	boy_scooter.destination_name = "Tiệm Sửa Xe Máy"
	boy_scooter.home_parking_pos = Vector3(-48, 0, 72)
	boy_scooter.work_parking_pos = Vector3(-58, 0, -13)
	boy_scooter.position = Vector3(-48, 0, 72)
	root_node.add_child(boy_scooter)
	
	check(boy_scooter.owner_character == "boy", "Boy's scooter has correct owner tag")
	check(boy_scooter.wheels.size() == 2, "Scooter has front and rear wheels")
	check(is_instance_valid(boy_scooter.kickstand), "Scooter has kickstand for parking")
	check(boy_scooter.kickstand.visible, "Kickstand is down when parked")
	check(not boy_scooter.is_mounted, "Scooter starts in parked/unmounted state")
	check(boy_scooter.prompt(boy_scooter).contains("Boy"), "Prompt indicates Boy's motorcycle")

	# -------------------------------------------------------------
	# Test 2: Girl's Scooter Setup & Dedicated Hu Tieu Parking
	# -------------------------------------------------------------
	print("\n--- Test 2: Girl's Scooter Setup ---")
	var girl_scooter := PlayerScooter.new()
	girl_scooter.name = "TestGirlScooter"
	girl_scooter.owner_character = "girl"
	girl_scooter.scooter_color = Color("ff7043")
	girl_scooter.destination_name = "Quán Hủ Tiếu Cô Bảy"
	girl_scooter.home_parking_pos = Vector3(-42, 0, 72)
	girl_scooter.work_parking_pos = Vector3(-44, 0, -15)
	girl_scooter.position = Vector3(-42, 0, 72)
	root_node.add_child(girl_scooter)
	
	check(girl_scooter.owner_character == "girl", "Girl's scooter has correct owner tag")
	check(girl_scooter.destination_name == "Quán Hủ Tiếu Cô Bảy", "Target destination is Hu Tieu Shop")
	check(girl_scooter.work_parking_pos == Vector3(-44, 0, -15), "Dedicated parking spot located beside Hu Tieu stall")

	# -------------------------------------------------------------
	# Test 3: Player Mounting, Seated Pose & Speed Boost
	# -------------------------------------------------------------
	print("\n--- Test 3: Player Mounting & Driving ---")
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	root_node.add_child(player)
	player.position = Vector3(-48, 0, 72)
	
	# Mount Boy's scooter
	boy_scooter.mount(player)
	check(boy_scooter.is_mounted, "Scooter state is marked is_mounted")
	check(player.has_meta("riding_scooter"), "Player has meta 'riding_scooter' set")
	check(not boy_scooter.kickstand.visible, "Kickstand folded up automatically when mounted")
	check(boy_scooter.exhaust_particles.emitting, "Exhaust particles emitting while active")
	
	# Simulate riding movement
	var initial_wheel_rot: float = boy_scooter.wheels[0].rotation.x
	boy_scooter.update_riding(0.1, Vector3.FORWARD, 9.0, false)
	check(boy_scooter.wheels[0].rotation.x != initial_wheel_rot, "Wheels rotate when scooter moves")
	
	# Verify riding HUD prompt
	var p_text := boy_scooter.get_riding_prompt()
	check(p_text.contains("Đỗ xe") or p_text.contains("Xuống xe"), "Riding prompt shows dismount and drive hints")

	# -------------------------------------------------------------
	# Test 4: Dismounting at Workplace Dedicated Parking Bay
	# -------------------------------------------------------------
	print("\n--- Test 4: Dismount & Parking at Workplace ---")
	# Move player near garage parking bay (-58, 0, -13)
	player.global_position = Vector3(-58.5, 0, -12.8)
	
	var parked_signal := [false]
	boy_scooter.parked_at_destination.connect(func(spot: String):
		if spot == "work":
			parked_signal[0] = true
	)
	
	# Dismount near parking spot -> snaps cleanly to work_parking_pos
	boy_scooter.dismount()
	check(not boy_scooter.is_mounted, "Scooter unmounted successfully")
	check(not player.has_meta("riding_scooter"), "Player cleared 'riding_scooter' meta")
	check(boy_scooter.kickstand.visible, "Kickstand put down upon parking")
	check(boy_scooter.global_position.distance_to(Vector3(-58, 0, -13)) < 0.1, "Scooter neatly parked in designated garage bay")
	check(parked_signal[0], "Parked at destination signal emitted for 'work'")

	# -------------------------------------------------------------
	# Test 5: Neighborhood World Integration Check
	# -------------------------------------------------------------
	print("\n--- Test 5: Live World Integration ---")
	var world_scene = load("res://scenes/neighborhood.tscn").instantiate()
	root_node.add_child(world_scene)
	
	check(is_instance_valid(world_scene.boy_scooter), "Boy's scooter present in neighborhood world")
	check(is_instance_valid(world_scene.girl_scooter), "Girl's scooter present in neighborhood world")
	check(world_scene.boy_scooter.position == Vector3(-48, 0, 72), "Boy's scooter spawned outside house gate")
	check(world_scene.girl_scooter.position == Vector3(-42, 0, 72), "Girl's scooter spawned outside house gate")
	
	# Clean up
	root_node.queue_free()
	
	print("\nSCOOTER_TEST_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)
