extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC01: Character Selection ---")
	recorder.start_recording("TC01_character_selection")
	
	# 1. Start with Boy
	player.global_position = Vector3(-45.0, 0, 89.0)
	player.select_character("boy")
	await wait_and_record(10)
	
	check(player.selected_character == "boy", "Character is Boy")
	check(is_instance_valid(player.animation_controller.model), "Boy 3D visual model is active")
	check(player.global_position.z > 83.0, "Boy starts inside shared house interior (Z > 83)")
	
	# Walk Boy in a small loop inside bedroom
	await simulate_walk(Vector3(-43.5, 0, 89.5), 1.0)
	await simulate_walk(Vector3(-45.0, 0, 89.0), 1.0)
	
	# 2. Switch to Girl
	player.select_character("girl")
	await wait_and_record(10)
	
	check(player.selected_character == "girl", "Character switched to Girl")
	check(is_instance_valid(player.animation_controller.model), "Girl 3D visual model is active")
	check(player.global_position.z > 83.0, "Girl remains inside shared house interior")
	
	# Walk Girl in a small loop inside bedroom
	await simulate_walk(Vector3(-46.5, 0, 88.5), 1.0)
	await simulate_walk(Vector3(-45.0, 0, 89.0), 1.0)
	await wait_and_record(8)
	
	# Switch back to Boy for subsequent scenarios
	player.select_character("boy")
	await wait_and_record(5)
	
	var gif_path = recorder.stop_recording_and_export_gif(12)
	return {
		"id": "TC01",
		"title": "Character Selection",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified Boy and Girl selection, visual meshes, and initial spawn inside house."
	}
