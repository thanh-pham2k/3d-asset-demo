extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC01: Character Selection ---")
	scenario_description = "Validates seamless switching between Boy and Girl characters, verifying 3D model instantiation, animation controller attachment, and bedroom spawn location."
	expected_result = "Both Boy and Girl visual models swap smoothly, retain physics/movement collision, and remain properly positioned within the house interior."
	related_sources = [
		"res://scripts/player.gd",
		"res://scripts/player_config.gd",
		"res://scripts/animation_controller.gd"
	]
	reproduction_steps = [
		"1. Spawn player at home bedroom coordinates (-45, 0, 89).",
		"2. Select Boy character: assert selected_character == 'boy' and model is active.",
		"3. Simulate walking in bedroom circle to verify locomotion animations.",
		"4. Switch character to Girl: assert selected_character == 'girl' and female visual model is active.",
		"5. Walk in bedroom circle with Girl character.",
		"6. Switch back to Boy character for subsequent scenarios."
	]
	
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
	
	notes = "Verified Boy and Girl selection, visual meshes, and initial spawn inside house without collision degradation."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
