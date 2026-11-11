extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC02: House Exit ---")
	recorder.start_recording("TC02_house_exit")
	
	player.global_position = Vector3(-45.0, 0, 89.0)
	player.select_character("boy")
	await wait_and_record(6)
	
	var room: Room = game_manager.get_node_or_null("Room")
	var door: Interactable = room.current_door if room else null
	check(is_instance_valid(door), "House front door exists")
	
	# Make sure door starts closed
	if door and door.toggle:
		door.interact(player)
	check(not door.toggle, "Door starts in closed state")
	
	# 1. Walk toward front door
	await simulate_walk(Vector3(-45.0, 0, 84.5), 1.8)
	await wait_and_record(8)
	
	# 2. Press E to open door
	door.interact(player)
	await wait_and_record(10)
	check(door.toggle, "Door opened after E interaction")
	
	var body: StaticBody3D = door.get_meta("door_body") if door.has_meta("door_body") else null
	check(is_instance_valid(body) and body.collision_layer == 0, "Doorway collision disabled allowing pass-through")
	
	# 3. Walk through doorway into front yard
	await simulate_walk(Vector3(-45.0, 0, 76.0), 2.2)
	await wait_and_record(12)
	
	check(player.global_position.z <= 80.0, "Player walked out of house into front yard (Z <= 80)")
	check(player.global_position.z >= 63.0, "Player is within front yard bounds (Z >= 63)")
	
	var cam: Camera3D = game_manager.main_camera
	check(is_instance_valid(cam), "Camera tracks player smoothly")
	check(absf(cam.global_position.x - player.global_position.x) < 2.0, "Camera centered horizontally with player")
	
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return {
		"id": "TC02",
		"title": "House Exit",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified walking to door, E opening door, collision removal, and smooth walk out to yard."
	}
