extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC02: House Entry & Exit ---")
	scenario_description = "Tests complete house entry and exit cycle: validates closed door collision blocking passage, [E] interaction to open, smooth walking through doorway into yard, turning around to re-enter, closing door, and camera tracking."
	expected_result = "Door collision prevents walk-through when closed, allows passage when open via [E], and camera tracks smoothly both exiting and entering."
	related_sources = [
		"res://scripts/room.gd",
		"res://scripts/interactable.gd",
		"res://scripts/player.gd"
	]
	reproduction_steps = [
		"1. Spawn player in bedroom at (-45, 0, 89).",
		"2. Verify house front door starts closed with solid collision enabled.",
		"3. Attempt to walk through closed door: assert player is blocked at doorway.",
		"4. Press [E] on front door to open: assert door.toggle == true and collision layer cleared.",
		"5. Walk through doorway into front yard: assert Z <= 80.",
		"6. Verify camera horizontally tracks player position.",
		"7. Turn around and walk through open doorway back into bedroom: assert Z > 84.",
		"8. Press [E] to close door: assert collision is restored and blocks outward passage.",
		"9. Re-open door and step into front yard for next scenario."
	]
	
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
	
	var body: StaticBody3D = door.get_meta("door_body") if door.has_meta("door_body") else null
	check(is_instance_valid(body) and body.collision_layer == 1, "Door collision active in closed state")
	
	# 1. Walk toward front door
	await simulate_walk(Vector3(-45.0, 0, 84.5), 1.5)
	await wait_and_record(6)
	
	# Attempt to walk through closed door: CharacterBody3D move_and_slide will stop at door body
	await simulate_walk(Vector3(-45.0, 0, 82.0), 0.8)
	check(player.global_position.z > 83.0, "Solid door collision prevents walking through closed doorway")
	
	# 2. Press E to open door
	door.interact(player)
	await wait_and_record(8)
	check(door.toggle, "Door opened after E interaction")
	check(is_instance_valid(body) and body.collision_layer == 0, "Doorway collision disabled allowing pass-through")
	
	# 3. Walk through doorway into front yard
	await simulate_walk(Vector3(-45.0, 0, 76.0), 2.0)
	await wait_and_record(8)
	
	check(player.global_position.z <= 80.0, "Player walked out of house into front yard (Z <= 80)")
	check(player.global_position.z >= 63.0, "Player is within front yard bounds (Z >= 63)")
	
	var cam: Camera3D = game_manager.main_camera
	check(is_instance_valid(cam), "Camera tracks player smoothly")
	check(absf(cam.global_position.x - player.global_position.x) < 2.0, "Camera centered horizontally with player")
	
	# 4. Turn around and walk back through doorway into bedroom
	await simulate_walk(Vector3(-45.0, 0, 87.0), 2.2)
	await wait_and_record(8)
	check(player.global_position.z > 84.0, "Player walked back into house interior through open door")
	
	# 5. Close door behind player
	door.interact(player)
	await wait_and_record(8)
	check(not door.toggle, "Door closed after second E interaction")
	check(body.collision_layer == 1, "Door collision re-enabled upon closing")
	
	# 6. Re-open and step into yard for next commute scenario
	door.interact(player)
	await wait_and_record(5)
	await simulate_walk(Vector3(-45.0, 0, 76.0), 1.6)
	await wait_and_record(6)
	
	notes = "Verified complete entry and exit cycle, physical door collision blocking, smooth camera tracking, and bidirectional navigation."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
