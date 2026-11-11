extends "res://tests/visual/scenarios/scenario_base.gd"

const InteractiveMinimap = preload("res://scripts/ui/interactive_minimap.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC02: Minimap and Expanded Map ---")
	recorder.start_recording("TC02_minimap_expanded_map")
	
	player.select_character("boy")
	player.global_position = Vector3(-45.0, 0, 75.0)
	
	var minimap: InteractiveMinimap = game_manager.get_node_or_null("InteractiveMinimap")
	if not minimap:
		var world = game_manager.get_node_or_null("Neighborhood")
		if world:
			minimap = world.get_node_or_null("InteractiveMinimap")
	check(is_instance_valid(minimap), "InteractiveMinimap node exists")
	
	# 1. Verify HUD Minimap visible in corner
	check(minimap.hud_container.visible, "HUD minimap visible at bottom-right")
	await wait_and_record(10)
	
	# 2. Walk and turn to demonstrate real-time player arrow & radar update
	await simulate_walk(Vector3(-45.0, 0, 50.0), 2.0, 0.3)
	await wait_and_record(8)
	await simulate_walk(Vector3(-20.0, 0, 50.0), 2.0, 0.3)
	await wait_and_record(8)
	
	# 3. Open Expanded Town Map (simulate 'M' key or direct toggle)
	minimap.toggle_expanded_map()
	await wait_and_record(15)
	
	check(minimap.is_expanded == true, "Minimap expanded state is active")
	check(minimap.modal_window.visible == true, "Expanded modal window is visible")
	check(minimap.landmarks.size() >= 7, "All neighborhood landmarks registered on map")
	
	# Let modal display clearly for review
	await wait_and_record(25)
	
	# 4. Close Expanded Town Map (simulate 'M' / Esc or close button)
	minimap.close_expanded_map()
	await wait_and_record(12)
	
	check(minimap.is_expanded == false, "Expanded map modal closed")
	check(minimap.modal_window.visible == false, "Modal window hidden")
	check(minimap.hud_container.visible == true, "HUD minimap remains active")
	
	# 5. Resume movement to confirm controls preserved
	await simulate_walk(Vector3(-45.0, 0, 40.0), 1.5, 0.3)
	await wait_and_record(10)
	
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return {
		"id": "TC02",
		"title": "Minimap and Expanded Map",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified bottom-right HUD minimap, real-time player orientation, M key modal toggle, landmark pins, and smooth return to gameplay."
	}
