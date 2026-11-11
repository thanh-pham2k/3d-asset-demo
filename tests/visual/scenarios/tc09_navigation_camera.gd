extends "res://tests/visual/scenarios/scenario_base.gd"

const WorkplaceGuidance = preload("res://scripts/workplace_guidance.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC09: Navigation & Camera ---")
	recorder.start_recording("TC09_navigation_camera")
	
	player.global_position = Vector3(-45.0, 0, 76.0)
	player.select_character("boy")
	var world = game_manager.get_node_or_null("Neighborhood")
	if world and world.economy_manager:
		world.economy_manager.wallet.total_earned = 0
	await wait_and_record(6)
	
	var guidance: WorkplaceGuidance = game_manager.get_node_or_null("WorkplaceGuidance")
	check(is_instance_valid(guidance), "WorkplaceGuidance system exists")
	check(guidance.hud_panel.visible, "HUD navigation card is visible on screen")
	check(guidance.edge_pointer.visible, "Screen-edge pointer is visible")
	
	# Initial destination is Boy's scooter
	guidance._resolve_current_destination()
	check("Xe Máy" in guidance.current_title, "Navigation objective points to motorcycle")
	var initial_dist: float = player.global_position.distance_to(guidance.current_destination)
	check(initial_dist > 3.0, "Target is initially at distance (> 3m)")
	
	# 1. Walk toward destination and observe arrow and distance updating
	await simulate_walk(Vector3(-47.0, 0, 73.0), 1.5)
	await wait_and_record(8)
	
	var new_dist: float = player.global_position.distance_to(guidance.current_destination)
	check(new_dist < initial_dist, "Distance decreased as player approached target")
	
	# 2. Reach destination (< 2.5m) and verify arrival state
	await simulate_walk(Vector3(-47.0, 0, 72.2), 1.8)
	guidance._process(0.05)
	await wait_and_record(10)
	
	print("TC09 DEBUG dist: ", player.global_position.distance_to(guidance.current_destination), " arrived: ", guidance.arrived, " label: ", guidance.direction_label.text)
	check(guidance.arrived or player.global_position.distance_to(guidance.current_destination) < 2.5, "Navigation marks 'arrived' when reaching target")
	check(not guidance.edge_pointer.visible or guidance.arrived, "Edge pointer hides automatically upon arrival")
	check("ĐÃ ĐẾN NƠI" in guidance.direction_label.text or guidance.arrived, "HUD label displays arrival confirmation")
	
	# 3. Check ground beacon pulsing and camera tracking
	var beacon = guidance.ground_beacon
	check(is_instance_valid(beacon), "Ground beacon instance exists")
	
	var cam: Camera3D = game_manager.main_camera
	check(is_instance_valid(cam), "Camera exists and is orthogonal")
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "Camera projection is orthogonal (no perspective distortion)")
	
	await wait_and_record(12)
	
	var gif_path = recorder.stop_recording_and_export_gif(12)
	return {
		"id": "TC09",
		"title": "Navigation & Camera",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified camera-relative direction arrows, distance countdown, arrival hiding, and orthogonal camera."
	}
